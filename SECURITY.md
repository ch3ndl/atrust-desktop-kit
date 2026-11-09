# Reporting issues without leaking secrets

Do not include credentials.json, generated gateway overrides, Docker inspect
output, cookies, session files, private SSH keys, or unredacted logs in issues.
DPAPI ciphertext also belongs to your private configuration; do not publish it.
Use vpn.example.com, sample-user, and synthetic passwords in reproductions.

Plaintext storage is an explicit convenience option, not protection against
local readers. DPAPI protects saved values for the Windows account; Docker
administrators can still inspect runtime credentials. All network listeners
are bound to loopback by default. Browser VNC is for trusted local use only.

The helper stops when credentials are rejected or a session is revoked. It
does not attempt to bypass verification, device checks, or account lockouts.
Confirm account status before restarting after an authentication rejection.

For a non-sensitive implementation bug, open an issue with the image digest,
Windows/Docker versions, selected storage mode, and a synthetic reproduction.
For a vulnerability, use GitHub's private vulnerability reporting when enabled;
do not disclose credentials or real institutional network details publicly.
