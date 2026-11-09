# SPDX-License-Identifier: MIT
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
. (Join-Path $project 'scripts\CredentialStore.ps1')
$examples = @('example ONLY 123', 'synthetic-quoted"value\path', '示例-only-not-a-secret')
foreach ($sample in $examples) {
    $encrypted = Write-StoredSecret $sample $true
    if ($encrypted -ceq $sample) { throw 'Encryption did not transform the value.' }
    if ((Read-StoredSecret $encrypted) -cne $sample) { throw 'DPAPI round trip failed.' }
    if ((Write-StoredSecret $sample $false) -cne $sample) { throw 'Plaintext round trip failed.' }
}
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('atrust-kit-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $scratch 'scripts') | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $project 'Start-ATrust.ps1') -Destination $scratch
    Copy-Item -LiteralPath (Join-Path $project 'credentials.example.json') -Destination $scratch
    Copy-Item -LiteralPath (Join-Path $project 'scripts\CredentialStore.ps1') -Destination (Join-Path $scratch 'scripts')
    $path = Join-Path $scratch 'credentials.json'
    $config = Get-Content -Raw (Join-Path $scratch 'credentials.example.json') | ConvertFrom-Json
    $config.EncryptPasswords = $false
    $config.Password = 'example-vpn-only'
    $config.VncPassword = 'example8'
    $config | ConvertTo-Json | Set-Content -Encoding UTF8 $path
    foreach ($encrypt in @($true, $false)) {
        $config = Get-Content -Raw $path | ConvertFrom-Json
        $config.EncryptPasswords = $encrypt
        $config | ConvertTo-Json | Set-Content -Encoding UTF8 $path
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scratch 'Start-ATrust.ps1') -PrepareOnly
        if ($LASTEXITCODE -ne 0) { throw 'Switch conversion failed.' }
        $config = Get-Content -Raw $path | ConvertFrom-Json
        if ((Read-StoredSecret $config.Password) -cne 'example-vpn-only' -or (Read-StoredSecret $config.VncPassword) -cne 'example8') { throw 'Switch changed a credential.' }
    }
    Write-Host 'PASS: DPAPI/plaintext round trips and JSON switch preserve both synthetic secrets.'
} finally {
    foreach ($relative in @('credentials.json','credentials.example.json','Start-ATrust.ps1','scripts\CredentialStore.ps1')) {
        $file = Join-Path $scratch $relative
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
    }
    Remove-Item -LiteralPath (Join-Path $scratch 'scripts')
    Remove-Item -LiteralPath $scratch
}
