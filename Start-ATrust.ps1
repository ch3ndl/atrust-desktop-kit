# SPDX-License-Identifier: MIT
param(
    [switch]$Configure,
    [switch]$Manual,
    [switch]$VncOnly,
    [switch]$PrepareOnly,
    [ValidateSet('Plaintext', 'Encrypted')][string]$StorageMode
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\CredentialStore.ps1')
$path = Join-Path $PSScriptRoot 'credentials.json'
if (!(Test-Path -LiteralPath $path)) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'credentials.example.json') -Destination $path
}
$config = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
if ($config.EncryptPasswords -isnot [bool]) { throw 'EncryptPasswords must be a JSON boolean.' }
$vpn = Read-StoredSecret $config.Password
$vnc = Read-StoredSecret $config.VncPassword
if ($StorageMode) { $config.EncryptPasswords = $StorageMode -eq 'Encrypted' }
if ($Configure) {
    $portal = Read-Host ('Portal URL [' + $config.Portal + ']')
    if ($portal) { $config.Portal = $portal.Trim() }
    $username = Read-Host ('VPN username [' + $config.Username + ']')
    if ($username) { $config.Username = $username.Trim() }
    $secure = Read-Host -AsSecureString 'VPN password (hidden)'
    if (!$secure.Length) { throw 'Password cannot be empty.' }
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { $vpn = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
if (!$vnc) {
    $bytes = New-Object byte[] 6
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($bytes); $vnc = [Convert]::ToBase64String($bytes) }
    finally { $random.Dispose() }
}
$config.Password = Write-StoredSecret $vpn $config.EncryptPasswords
$config.VncPassword = Write-StoredSecret $vnc $config.EncryptPasswords
$config | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls.exe $path /inheritance:r /grant:r "${identity}:(F)" '*S-1-5-18:(F)' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not restrict credentials.json access.' }
if ($PrepareOnly) { Write-Host 'Credential storage updated. Containers unchanged.'; exit 0 }
$portalUri = [Uri]$config.Portal
if ($portalUri.Scheme -notin @('http','https') -or !$portalUri.Host -or $portalUri.UserInfo) { throw 'Provide a valid HTTP(S) portal URL without embedded credentials.' }
if ($portalUri.Host -eq 'vpn.example.com') { throw 'Run Configure.cmd first to set your own portal and account.' }
if (!$Manual -and !$VncOnly -and (!$vpn -or !$config.Username -or $config.Username -eq 'your-username')) { throw 'Run Configure.cmd first to set your account and password.' }
$ports = @($config.SocksPort, $config.HttpPort, $config.VncPort, $config.WebPort, $config.WebsocketPort)
foreach ($port in $ports) { if (($port -isnot [int] -and $port -isnot [long]) -or $port -lt 1024 -or $port -gt 65535) { throw 'Ports must be integers from 1024 to 65535.' } }
if (@($ports | Select-Object -Unique).Count -ne 5) { throw 'Choose five different listening ports.' }
$variables = @('ATRUST_OPTS','ATRUST_VNC_PASSWORD','SOCKS_PORT','HTTP_PORT','VNC_PORT','WEB_PORT','WEBSOCKET_PORT')
$previous = @{}
foreach ($key in $variables) { $previous[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
try {
    $env:ATRUST_OPTS = '--portal_address=' + (Quote-LoginArgument $config.Portal) + ' --keepalive=200 --login_timeout=3600'
    if (!$Manual) { $env:ATRUST_OPTS += ' --username=' + (Quote-LoginArgument $config.Username) + ' --password=' + (Quote-LoginArgument $vpn) }
    $env:ATRUST_VNC_PASSWORD = $vnc
    $env:SOCKS_PORT = [string]$config.SocksPort
    $env:HTTP_PORT = [string]$config.HttpPort
    $env:VNC_PORT = [string]$config.VncPort
    $env:WEB_PORT = [string]$config.WebPort
    $env:WEBSOCKET_PORT = [string]$config.WebsocketPort
    $arguments = @('compose','-f',(Join-Path $PSScriptRoot 'compose.yaml'))
    if ($config.GatewayAddress) {
        $gateway = $null
        if (![Net.IPAddress]::TryParse([string]$config.GatewayAddress,[ref]$gateway)) { throw 'GatewayAddress must be the real gateway IP, or empty.' }
        $override = Join-Path $PSScriptRoot 'compose.gateway.yaml'
        @{services=@{client=@{extra_hosts=@{$portalUri.DnsSafeHost=[string]$gateway}}}} | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -LiteralPath $override
        $arguments += @('-f',$override)
    }
    if ($VncOnly) { & docker @arguments up -d --no-deps desktop }
    else { & docker @arguments up -d client }
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose startup failed.' }
    Write-Host ('SOCKS5 127.0.0.1:' + $config.SocksPort + ' | HTTP 127.0.0.1:' + $config.HttpPort)
    Write-Host 'Containers started. Startup alone does not prove VPN connectivity; check logs and an authorized internal service.'
} finally {
    foreach ($key in $variables) { [Environment]::SetEnvironmentVariable($key,$previous[$key],'Process') }
}
