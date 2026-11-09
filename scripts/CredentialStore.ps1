# SPDX-License-Identifier: MIT
function Read-StoredSecret([string]$Value) {
    if ($Value -notmatch '^01000000d08c9ddf0115d1118c7a00c04fc297eb[0-9a-f]+$') { return $Value }
    $secure = ConvertTo-SecureString $Value
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
function Write-StoredSecret([string]$Value, [bool]$Encrypt) {
    if (!$Encrypt -or !$Value) { return $Value }
    ConvertTo-SecureString $Value -AsPlainText -Force | ConvertFrom-SecureString
}
function Quote-LoginArgument([string]$Value) {
    '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}
