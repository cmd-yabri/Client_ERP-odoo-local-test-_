param(
    [Parameter(Mandatory = $true)][string]$PgBinPath,
    [Parameter(Mandatory = $true)][string]$DbName,
    [Parameter(Mandatory = $true)][string]$DbUser,
    [Parameter(Mandatory = $true)][string]$DbPassword,
    [Parameter(Mandatory = $true)][string]$SuperPassword,
    [string]$Host = "127.0.0.1",
    [int]$Port = 5432,
    [string]$BackupDir = "$env:ProgramData\ClientERP\migration"
)

$ErrorActionPreference = "Stop"

# Restores database + filestore backup after install/upgrade steps.
$pgRestore = Join-Path $PgBinPath "pg_restore.exe"
$psql = Join-Path $PgBinPath "psql.exe"
$dumpFile = Join-Path $BackupDir "database.dump"

if (-not (Test-Path $dumpFile)) {
    Write-Host "No migration dump found, skipping migration import."
    exit 0
}

# Escapes single quotes for safe SQL string literals.
function Escape-Literal {
    param([string]$Text)
    return $Text.Replace("'", "''")
}

# Executes SQL command for side effects and fails on non-zero exit.
function Invoke-Psql {
    param([string]$Sql)
    $env:PGPASSWORD = $SuperPassword
    & $psql -h $Host -p $Port -U postgres -d postgres -c $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed: $Sql"
    }
}

$safeDbName = Escape-Literal $DbName
$safeDbUser = Escape-Literal $DbUser
$safeDbPassword = Escape-Literal $DbPassword

$env:PGPASSWORD = $SuperPassword
$roleExists = & $psql -h $Host -p $Port -U postgres -d postgres -tA -c "SELECT 1 FROM pg_roles WHERE rolname = '$safeDbUser';"
if (($roleExists | Out-String).Trim() -ne "1") {
    Invoke-Psql "CREATE ROLE `"$DbUser`" LOGIN PASSWORD '$safeDbPassword' CREATEDB;"
}

Invoke-Psql "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$safeDbName';"
Invoke-Psql "DROP DATABASE IF EXISTS `"$DbName`";"
Invoke-Psql "CREATE DATABASE `"$DbName`" OWNER `"$DbUser`" ENCODING 'UTF8';"

$env:PGPASSWORD = $SuperPassword
& $pgRestore -h $Host -p $Port -U postgres -d $DbName --no-owner --role=$DbUser $dumpFile
if ($LASTEXITCODE -ne 0) {
    throw "pg_restore failed."
}

$backupFilestoreRoot = Join-Path $BackupDir "filestore"
$targetFilestoreRoot = Join-Path "$env:ProgramData\ClientERP\odoo\data\filestore" $DbName
if (Test-Path $backupFilestoreRoot) {
    New-Item -ItemType Directory -Path $targetFilestoreRoot -Force | Out-Null
    Remove-Item -Path (Join-Path $targetFilestoreRoot "*") -Recurse -Force -ErrorAction SilentlyContinue

    $nested = Join-Path $backupFilestoreRoot $DbName
    if (Test-Path $nested) {
        Copy-Item -Path (Join-Path $nested "*") -Destination $targetFilestoreRoot -Recurse -Force
    }
    else {
        Copy-Item -Path (Join-Path $backupFilestoreRoot "*") -Destination $targetFilestoreRoot -Recurse -Force
    }
}

Write-Host "Migration import completed from: $BackupDir"
