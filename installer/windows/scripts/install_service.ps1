param(
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [string]$PublicKeyPath = "$env:ProgramData\ClientERP\license\public_key.pem"
)

$ErrorActionPreference = "Stop"

# Validates service/server artifacts and registers the Windows service
# with environment variables consumed at runtime.
$serviceExe = Join-Path $InstallDir "clienterp_service.exe"
$serverExe = Join-Path $InstallDir "server\clienterp_server.exe"

if (-not (Test-Path $serviceExe)) {
    throw "Service executable not found: $serviceExe"
}
if (-not (Test-Path $serverExe)) {
    throw "Server executable not found: $serverExe"
}
if (-not (Test-Path $PublicKeyPath)) {
    throw "Public key not found: $PublicKeyPath"
}

[Environment]::SetEnvironmentVariable("CLIENTERP_SERVER_EXE", $serverExe, "Machine")
[Environment]::SetEnvironmentVariable("CLIENTERP_CONFIG", $ConfigPath, "Machine")
[Environment]::SetEnvironmentVariable("CLIENTERP_PUBLIC_KEY_FILE", $PublicKeyPath, "Machine")

# Refresh for current process
$env:CLIENTERP_SERVER_EXE = $serverExe
$env:CLIENTERP_CONFIG = $ConfigPath
$env:CLIENTERP_PUBLIC_KEY_FILE = $PublicKeyPath

$serviceName = "ClientERPService"
if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    & $serviceExe stop | Out-Null
    & $serviceExe remove | Out-Null
}

& $serviceExe --startup auto install
if ($LASTEXITCODE -ne 0) {
    throw "Service install failed."
}

& $serviceExe start
if ($LASTEXITCODE -ne 0) {
    throw "Service start failed."
}

Write-Host "ClientERP Windows service installed and started."
