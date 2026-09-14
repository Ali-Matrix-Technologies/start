#requires -Version 5.1
param(
    [ValidateSet('all', 'base', 'claude', 'codex')][string]$Only = 'all',
    [switch]$Check
)
# Run in ordinary PowerShell. UAC is requested by the individual installers.
# This script never changes execution policy, accounts, or Git identity.
$ErrorActionPreference = 'Stop'
$InstallStep = 'prepare'

function Get-ToolVersion([string]$Tool) {
    $command = @("$Tool.exe", "$Tool.cmd") | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
    if (-not $command) { return $null }
    try {
        $result = & $command --version 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $result) { return $null }
        return ($result | Select-Object -First 1).ToString()
    } catch { return $null }
}
function Test-Tool([string]$Tool) {
    $version = Get-ToolVersion $Tool
    if (-not $version) { return $false }
    if ($Tool -eq 'node') {
        if ($version -notmatch '^v?(\d+)\.' -or [int]$Matches[1] -lt 22) { return $false }
        foreach ($cmd in @('npm.cmd', 'npx.cmd')) {
            if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { return $false }
            try { & $cmd --version *> $null; if ($LASTEXITCODE -ne 0) { return $false } }
            catch { return $false }
        }
    }
    return $true
}
function Update-InstallPath {
    # Refresh after MSI/WinGet, preserving paths already added by this shell.
    $parts = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        $env:Path,
        (Join-Path $env:APPDATA 'npm'),
        (Join-Path $env:USERPROFILE '.local\bin')
    )
    $env:Path = (($parts -join ';').Split(';') | Where-Object { $_ } | Select-Object -Unique) -join ';'
}
function Install-WingetPackage([string]$Id, [switch]$Upgrade) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'WinGet is missing. Open Microsoft Store > App Installer, install/update it, reopen PowerShell and rerun. https://apps.microsoft.com/detail/9nblggh4nns1'
    }
    $verb = if ($Upgrade) { 'upgrade' } else { 'install' }
    & winget.exe $verb --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw "WinGet $Id returned $code. If restart is requested, restart first; otherwise follow the error above, then rerun."
    }
    Update-InstallPath
}
function Set-NpmUserPath([string]$Prefix) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $Prefix) {
        [Environment]::SetEnvironmentVariable('Path', (($userPath, $Prefix | Where-Object { $_ }) -join ';'), 'User')
    }
}
function Install-SelectedTool([string]$Tool) {
    switch ($Tool) {
        'git' { Install-WingetPackage 'Git.Git' }
        'gh' { Install-WingetPackage 'GitHub.cli' }
        'node' {
            # Do not replace an unknown existing Node installation automatically.
            if (Get-ToolVersion 'node') {
                Install-WingetPackage 'OpenJS.NodeJS.LTS' -Upgrade
            } else { Install-WingetPackage 'OpenJS.NodeJS.LTS' }
        }
        'claude' { Install-WingetPackage 'Anthropic.ClaudeCode' }
        'codex' {
            & npm.cmd install --global --registry=https://registry.npmjs.org '@openai/codex'
            if ($LASTEXITCODE -ne 0) { throw 'Codex installation failed. Fix the npm error above, then rerun in ordinary PowerShell.' }
            $prefix = & npm.cmd prefix --global
            if ($LASTEXITCODE -ne 0 -or -not $prefix -or -not [IO.Path]::IsPathRooted($prefix)) { throw 'Cannot find npm global directory.' }
            Set-NpmUserPath $prefix
            Update-InstallPath
        }
    }
}
function Start-ToolsInstall([string]$Selection, [bool]$CheckOnly) {
    if ($env:OS -ne 'Windows_NT') { throw 'Use install-tools.sh on macOS/Linux.' }
    if ($env:PROCESSOR_ARCHITECTURE -notin @('AMD64', 'ARM64') -and $env:PROCESSOR_ARCHITEW6432 -notin @('AMD64', 'ARM64')) {
        throw 'Automatic installation supports x64 / ARM64 Windows. Use the manual guide for this computer.'
    }
    $tools = switch ($Selection) {
        'all' { @('git', 'node', 'gh', 'claude', 'codex') }
        'base' { @('git', 'node', 'gh') }
        'claude' { @('git', 'claude') }
        'codex' { @('node', 'codex') }
        default { throw 'Only must be all, base, claude, or codex.' }
    }
    Write-Host "Ali Matrix - tools: $($tools -join ', ')"
    if (-not $CheckOnly) {
        Write-Host 'Missing tools are installed; Node below 22 needs an LTS upgrade. Already working tools are skipped.'
        Write-Host 'WinGet may request UAC/package agreements. Sign-in, desktop apps and company plugins are separate next steps.'
        Update-InstallPath
    }
    $missing = @()
    foreach ($tool in $tools) {
        $script:InstallStep = $tool
        if (Test-Tool $tool) {
            Write-Host "[OK] $tool already ready, skipped: $(Get-ToolVersion $tool)"
        } elseif ($CheckOnly) {
            Write-Host "[MISSING] $tool is missing, too old, or not working."
            $missing += $tool
        } else {
            if (Get-ToolVersion $tool) { Write-Host "[UPDATE/REPAIR] $tool is installed but requirements are not met." }
            else { Write-Host "[FIRST INSTALL] $tool" }
            Install-SelectedTool $tool
            if (-not (Test-Tool $tool)) {
                throw "$tool did not pass verification. Close and reopen PowerShell, then rerun. For old Node not managed by WinGet, use https://nodejs.org/en/download to update to LTS."
            }
            Write-Host "[OK] $tool verified: $(Get-ToolVersion $tool)"
        }
    }
    if ($missing.Count) { throw "Check failed: $($missing -join ', '). No tools were installed." }
    if ($CheckOnly) { Write-Host 'Check passed. No installation or configuration changes.' }
    else {
        Write-Host 'Selected tools installed. Reopen PowerShell, run this script with -Check to verify.'
        Write-Host 'Next: return to the guide for GitHub/Claude/ChatGPT sign-in, desktop app and company SOP.'
    }
}
if ($MyInvocation.InvocationName -ne '.') {
    try { Start-ToolsInstall $Only ([bool]$Check); exit 0 }
    catch {
        Write-Host "[FAILED] $InstallStep - $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'Fix the error, then rerun. Completed tools will be skipped; this was NOT a completed installation.'
        exit 1
    }
}
