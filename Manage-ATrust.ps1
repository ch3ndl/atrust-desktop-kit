# SPDX-License-Identifier: MIT
param([ValidateSet('Stop','Logs')][string]$Action = 'Logs')
$ErrorActionPreference = 'Stop'
$arguments = @('ps','-a','-q','--filter','label=com.docker.compose.project=atrust-desktop-kit')
if ($Action -eq 'Logs') { $arguments += @('--filter','label=com.docker.compose.service=client') }
$containers = @(& docker @arguments)
if ($LASTEXITCODE -ne 0) { throw 'Could not list project containers.' }
if (!$containers.Count) { Write-Host 'No project containers found.'; exit 0 }
if ($Action -eq 'Stop') { & docker stop @containers }
else { & docker logs -f --tail 80 $containers[0] }
if ($LASTEXITCODE -ne 0) { throw 'Docker operation failed.' }
