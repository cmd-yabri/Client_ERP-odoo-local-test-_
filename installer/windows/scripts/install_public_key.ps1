param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [string]$TargetPath = "$env:ProgramData\ClientERP\license\public_key.pem"
)

$ErrorActionPreference = "Stop"

# Copies the shipped public verification key into ProgramData and
# exposes its location via machine-level environment variable.
if (-not (Test-Path $SourcePath)) {
    throw "Public key source file not found: $SourcePath"
}

$keyText = Get-Content -Path $SourcePath -Raw
if ($keyText -match "REPLACE_WITH_VENDOR_PUBLIC_KEY") {
    throw "Public key file still contains placeholder text. Provide a real vendor public key before install."
}

if ($keyText -notmatch "BEGIN PUBLIC KEY" -or $keyText -notmatch "END PUBLIC KEY") {
    throw "Public key file does not look like a valid PEM public key: $SourcePath"
}

$targetDir = Split-Path -Path $TargetPath -Parent
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Copy-Item -Path $SourcePath -Destination $TargetPath -Force

[Environment]::SetEnvironmentVariable("CLIENTERP_PUBLIC_KEY_FILE", $TargetPath, "Machine")
$env:CLIENTERP_PUBLIC_KEY_FILE = $TargetPath

Write-Host "Public key installed: $TargetPath"
