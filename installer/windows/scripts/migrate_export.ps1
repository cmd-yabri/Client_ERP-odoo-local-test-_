param(
    [Parameter(Mandatory = $true)][string]$PgBinPath,
    [Parameter(Mandatory = $true)][string]$DbName,
    [Parameter(Mandatory = $true)][string]$SuperPassword,
    [string]$Host = "127.0.0.1",
    [int]$Port = 5432,
    [string]$BackupDir = "$env:ProgramData\ClientERP\migration"
)

$ErrorActionPreference = "Stop"

# Exports database + filestore backup before upgrade/reinstall steps.
$pgDump = Join-Path $PgBinPath "pg_dump.exe"
$psql = Join-Path $PgBinPath "psql.exe"

if (-not (Test-Path $pgDump) -or -not (Test-Path $psql)) {
    Write-Host "PostgreSQL tools not found, skipping migration export."
    exit 0
}

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

$env:PGPASSWORD = $SuperPassword
$dbExists = & $psql -h $Host -p $Port -U postgres -d postgres -tA -c "SELECT 1 FROM pg_database WHERE datname = '$DbName';"
if ($LASTEXITCODE -ne 0 -or ($dbExists | Out-String).Trim() -ne "1") {
    Write-Host "Database '$DbName' not found, skipping migration export."
    exit 0
}

$dumpFile = Join-Path $BackupDir "database.dump"
& $pgDump -h $Host -p $Port -U postgres -F c -d $DbName -f $dumpFile
if ($LASTEXITCODE -ne 0) {
    throw "Failed to export database dump."
}

$filestoreSource = Join-Path "$env:ProgramData\ClientERP\odoo\data\filestore" $DbName
$filestoreBackup = Join-Path $BackupDir "filestore"
if (Test-Path $filestoreSource) {
    if (Test-Path $filestoreBackup) {
        Remove-Item -Path $filestoreBackup -Recurse -Force
    }
    Copy-Item -Path $filestoreSource -Destination $filestoreBackup -Recurse -Force
}

Write-Host "Migration export completed at: $BackupDir"
