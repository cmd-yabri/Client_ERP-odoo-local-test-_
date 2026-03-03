param(
    [Parameter(Mandatory = $true)][string]$InstallDir
)

$ErrorActionPreference = "Continue"

# Stops/removes service if present and clears machine-level runtime env vars.
$serviceExe = Join-Path $InstallDir "clienterp_service.exe"
if (-not (Test-Path $serviceExe)) {
    Write-Host "Service executable not found, skipping remove."
}
else {
    & $serviceExe stop | Out-Null
    & $serviceExe remove | Out-Null
}

[Environment]::SetEnvironmentVariable("CLIENTERP_SERVER_EXE", $null, "Machine")
[Environment]::SetEnvironmentVariable("CLIENTERP_CONFIG", $null, "Machine")
[Environment]::SetEnvironmentVariable("CLIENTERP_PUBLIC_KEY_FILE", $null, "Machine")

Write-Host "ClientERP service removed (if it existed)."
