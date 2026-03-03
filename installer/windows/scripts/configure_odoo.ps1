param(
    [Parameter(Mandatory = $true)][string]$TemplatePath,
    [Parameter(Mandatory = $true)][string]$OutPath,
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$DbUser,
    [Parameter(Mandatory = $true)][string]$DbPassword,
    [Parameter(Mandatory = $true)][string]$DbName,
    [Parameter(Mandatory = $true)][string]$AdminPassword,
    [Parameter(Mandatory = $true)][string]$PgBinPath
)

$ErrorActionPreference = "Stop"

# Validates template input and writes a concrete odoo.conf for this client install.
if (-not (Test-Path $TemplatePath)) {
    throw "Template file not found: $TemplatePath"
}

$programData = Join-Path $env:ProgramData "ClientERP"
$logDir = Join-Path $programData "logs"
$dataDir = Join-Path $programData "odoo\data"
$configDir = Split-Path -Path $OutPath -Parent

New-Item -ItemType Directory -Path $logDir -Force | Out-Null
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
New-Item -ItemType Directory -Path $configDir -Force | Out-Null

$content = Get-Content -Path $TemplatePath -Raw
$replacements = @{
    "{{APP_INSTALL_DIR}}"  = $InstallDir
    "{{PROGRAMDATA_DIR}}"  = $programData
    "{{PG_BIN_PATH}}"      = $PgBinPath
    "{{DB_USER}}"          = $DbUser
    "{{DB_PASSWORD}}"      = $DbPassword
    "{{DB_NAME}}"          = $DbName
    "{{ADMIN_PASSWORD}}"   = $AdminPassword
}

foreach ($key in $replacements.Keys) {
    # Replace token placeholders with installer-provided values.
    $content = $content.Replace($key, $replacements[$key])
}

Set-Content -Path $OutPath -Value $content -Encoding UTF8
Write-Host "Odoo config written: $OutPath"
