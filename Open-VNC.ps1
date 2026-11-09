# SPDX-License-Identifier: MIT
$ErrorActionPreference = 'Stop'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Start-ATrust.ps1') -VncOnly
if ($LASTEXITCODE -ne 0) { throw 'Could not start browser VNC.' }
. (Join-Path $PSScriptRoot 'scripts\CredentialStore.ps1')
$config = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'credentials.json') | ConvertFrom-Json
Write-Host ('VNC password: ' + (Read-StoredSecret $config.VncPassword))
$url = 'http://127.0.0.1:' + $config.WebPort + '/vnc.html?host=127.0.0.1&port=' + $config.WebsocketPort + '&autoconnect=true&resize=scale'
Start-Process $url
