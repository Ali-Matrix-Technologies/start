# Windows PowerShell 5.1 / pwsh. No actual installs or registry/profile writes.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../scripts/install-tools.ps1')
$script:Have = @{}
$script:Calls = [Collections.Generic.List[string]]::new()
$script:Failure = ''
$script:BadNpm = $false
$script:NodeVersion = 'v24.0.0'

function Assert-That($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Reset-Mocks {
    $script:Have = @{}
    $script:Calls.Clear()
    $script:Failure = ''
    $script:BadNpm = $false
    $script:NodeVersion = 'v24.0.0'
}
function Mock-Version([string]$Name) {
    $global:LASTEXITCODE = 127
    if ($script:Have[$Name]) {
        $global:LASTEXITCODE = 0
        if ($Name -eq 'node') { $script:NodeVersion } else { "$Name 1.0.0" }
    }
}
function git.exe { Mock-Version 'git' }
function node.exe { Mock-Version 'node' }
function gh.exe { Mock-Version 'gh' }
function claude.exe { Mock-Version 'claude' }
function codex.cmd { Mock-Version 'codex' }
function npx.cmd { $global:LASTEXITCODE = if ($script:BadNpm) { 1 } else { 0 } }
function npm.cmd {
    $global:LASTEXITCODE = 0
    if ($args[0] -eq '--version') { if ($script:BadNpm) { $global:LASTEXITCODE = 1 }; return '10.0.0' }
    if ($args[0] -eq 'prefix') { return 'C:\mock-npm' }
    $script:Calls.Add("npm $args")
    if ($script:Failure -eq 'npm') { $global:LASTEXITCODE = 42; return }
    Assert-That (($args -join ' ') -eq 'install --global --registry=https://registry.npmjs.org @openai/codex') 'Unexpected npm command'
    $script:Have['codex'] = $true
}
function winget.exe {
    $script:Calls.Add("winget $args")
    $global:LASTEXITCODE = 0
    if ($script:Failure -eq 'winget') { $global:LASTEXITCODE = 42; return }
    if ($script:Failure -eq 'restart') { $global:LASTEXITCODE = 3010; return }
    $id = $args[2]
    $tool = @{'Git.Git'='git';'GitHub.cli'='gh';'OpenJS.NodeJS.LTS'='node';'Anthropic.ClaudeCode'='claude'}[$id]
    Assert-That ([bool]$tool) "Unexpected package $id"
    Assert-That (($args -join ' ') -match '--exact --source winget') 'Package ID must be exact and from winget'
    if ($script:Failure -ne 'no-binary') {
        $script:Have[$tool] = $true
        if ($tool -eq 'node') { $script:NodeVersion = 'v24.0.0' }
    }
}
function Update-InstallPath { $script:Calls.Add('refresh-process-path') }
function Set-NpmUserPath([string]$Prefix) {
    Assert-That ($Prefix -eq 'C:\mock-npm') 'Unexpected npm prefix'
    $script:Calls.Add('persist-npm-path')
}
function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
    $caught = $null
    try { & $Action } catch { $caught = $_.Exception.Message }
    Assert-That ($caught -and $caught -match $Pattern) "Expected error $Pattern; got $caught"
}

# First install + repeat: all five actually verify, npm's .cmd shim is recognized.
Reset-Mocks
Start-ToolsInstall 'all' $false
foreach ($tool in @('git','node','gh','claude','codex')) { Assert-That (Test-Tool $tool) "$tool not ready" }
$script:Calls.Clear()
Start-ToolsInstall 'all' $false
Assert-That (($script:Calls -join ',') -eq 'refresh-process-path') 'Repeat must not install or persist again'

# Read-only success and missing tools cause no mutation commands.
$script:Calls.Clear()
Start-ToolsInstall 'all' $true
Assert-That ($script:Calls.Count -eq 0) 'Check made changes'
$script:Have.Remove('gh')
Expect-Failure { Start-ToolsInstall 'all' $true } 'Check failed'
Assert-That ($script:Calls.Count -eq 0) 'Failing check made changes'

# Narrow installs still include their prerequisites.
Reset-Mocks
Start-ToolsInstall 'codex' $false
Assert-That ($script:Have['node'] -and $script:Have['codex'] -and -not $script:Have['git']) 'Codex scope/dependencies'
Reset-Mocks
Start-ToolsInstall 'claude' $false
Assert-That ($script:Have['git'] -and $script:Have['claude'] -and -not $script:Have['node']) 'Claude scope/dependencies'

# Old Node uses upgrade, and missing npm never passes version validation.
Reset-Mocks
$script:Have['node'] = $true
$script:NodeVersion = 'v18.0.0'
Start-ToolsInstall 'codex' $false
Assert-That (($script:Calls -join ',') -match 'winget upgrade --id OpenJS.NodeJS.LTS') 'Old Node was not upgraded'
$script:BadNpm = $true
Expect-Failure { Start-ToolsInstall 'codex' $true } 'Check failed'

# Native nonzero (including restart), false success, and npm errors stop delivery.
foreach ($failureCase in @('winget','restart','no-binary','npm')) {
    Reset-Mocks
    $script:Failure = $failureCase
    Expect-Failure { Start-ToolsInstall 'all' $false } 'returned|verification|installation failed'
    Assert-That (-not $script:Have['codex']) "Failure $failureCase did not stop installation"
}
Expect-Failure { Start-ToolsInstall 'wrong' $true } 'Only must'

# Missing winget is checked without invoking actual system package manager.
Reset-Mocks
Remove-Item Function:winget.exe
function Get-Command {
    param([string]$Name, $ErrorAction)
    if ($Name -eq 'winget.exe') { return $null }
    Microsoft.PowerShell.Core\Get-Command $Name -ErrorAction SilentlyContinue
}
Expect-Failure { Install-WingetPackage 'Git.Git' } 'WinGet is missing'

# Execute the actual copied page blocks with mocked network/child PowerShell.
$page = Get-Content (Join-Path $PSScriptRoot '../index.html') -Raw -Encoding UTF8
$blocks = [regex]::Matches($page, '(?s)<code>(\$f = Join-Path.*?)</code>')
Assert-That ($blocks.Count -eq 3) 'Expected three Windows installer copy blocks'
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing, $ErrorAction)
    $script:DownloadPath = $OutFile
    [IO.File]::WriteAllText($OutFile, $(if ($script:WrapperCase -eq 'empty') { '' } else { 'mock script' }))
    if ($script:WrapperCase -eq 'download-error') { throw 'mock download failed' }
}
function powershell {
    $script:Executed = $true
    $global:LASTEXITCODE = if ($script:WrapperCase -eq 'installer-error') { 23 } else { 0 }
}
foreach ($block in $blocks) {
    $action = [scriptblock]::Create([Net.WebUtility]::HtmlDecode($block.Groups[1].Value))
    foreach ($wrapperTestCase in @('empty','download-error','success','installer-error')) {
        $script:WrapperCase = $wrapperTestCase
        $script:Executed = $false
        $script:DownloadPath = $null
        $caught = $false
        try { & $action } catch { $caught = $true }
        Assert-That ($caught -eq ($wrapperTestCase -ne 'success')) "Wrong wrapper outcome: $wrapperTestCase"
        Assert-That ($script:Executed -eq ($wrapperTestCase -in @('success','installer-error'))) 'Unsafe script execution'
        Assert-That ($script:DownloadPath -and -not (Test-Path -LiteralPath $script:DownloadPath)) 'Temporary download not cleaned'
    }
}
Write-Host 'PASS: first install, repeat, check, dependencies, old Node, npm, failures, restart, missing winget'
$global:LASTEXITCODE = 0
