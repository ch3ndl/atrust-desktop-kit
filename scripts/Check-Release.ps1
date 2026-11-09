# SPDX-License-Identifier: MIT
param([string]$PrivateConfigPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'CredentialStore.ps1')
$deny = @{}
if ($PrivateConfigPath) {
    $private = Get-Content -Raw -LiteralPath $PrivateConfigPath | ConvertFrom-Json
    $deny['private portal'] = ([Uri]$private.Portal).Host
    $deny['private username'] = $private.Username
    $deny['VPN password'] = Read-StoredSecret $private.Password
    $deny['VNC password'] = Read-StoredSecret $private.VncPassword
    if ($private.GatewayAddress) { $deny['private gateway'] = $private.GatewayAddress }
}
$files = @(& git -C $root ls-files)
if ($LASTEXITCODE -ne 0 -or !$files.Count) { throw 'Stage the intended release files before scanning.' }
$issues = @()
foreach ($relative in $files) {
    if ($relative -match '(^|/)(credentials\.json|\.env|compose\.gateway\.yaml)$|\.(pkl|log|pem|key|pyc)$|(^|/)__pycache__/') {
        $issues += ('Forbidden release file: ' + $relative)
        continue
    }
    $text = [IO.File]::ReadAllText((Join-Path $root $relative))
    foreach ($label in $deny.Keys) {
        if ($deny[$label] -and $text.IndexOf([string]$deny[$label],[StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $issues += ($relative + ': contains ' + $label)
        }
    }
    if ($text -match '(?:ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|01000000d08c9ddf[0-9a-f]{200,})') {
        $issues += ($relative + ': possible secret material')
    }
}
$example = Get-Content -Raw (Join-Path $root 'credentials.example.json') | ConvertFrom-Json
if ($example.Password -or $example.VncPassword -or $example.GatewayAddress -or $example.Portal -ne 'https://vpn.example.com' -or $example.Username -ne 'your-username') {
    $issues += 'Example configuration contains non-placeholder values.'
}
if ($issues.Count) { $issues | ForEach-Object { Write-Output $_ }; throw 'Release audit failed. Nothing should be published.' }
Write-Host ('PASS: ' + $files.Count + ' tracked files audited; no local credential files or matched secret values.')
