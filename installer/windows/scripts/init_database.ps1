param(
    [Parameter(Mandatory = $true)][string]$PgBinPath,
    [Parameter(Mandatory = $true)][string]$DbName,
    [Parameter(Mandatory = $true)][string]$DbUser,
    [Parameter(Mandatory = $true)][string]$DbPassword,
    [Parameter(Mandatory = $true)][string]$SuperPassword,
    [string]$Host = "127.0.0.1",
    [int]$Port = 5432
)

$ErrorActionPreference = "Stop"

# Escapes single quotes for safe SQL string literals.
function Escape-Literal {
    param([string]$Text)
    return $Text.Replace("'", "''")
}

# Executes SQL and returns scalar output as trimmed text.
function Invoke-PsqlScalar {
    param([string]$Sql)
    $env:PGPASSWORD = $SuperPassword
    $psql = Join-Path $PgBinPath "psql.exe"
    $result = & $psql -h $Host -p $Port -U postgres -d postgres -tA -c $Sql
    if ($LASTEXITCODE -ne 0) {
        throw "psql command failed: $Sql"
    }
    return ($result | Out-String).Trim()
}

# Executes SQL command for side effects and fails on non-zero exit.
function Invoke-Psql {
    param([string]$Sql)
    $env:PGPASSWORD = $SuperPassword
    $psql = Join-Path $PgBinPath "psql.exe"
    & $psql -h $Host -p $Port -U postgres -d postgres -c $Sql | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "psql command failed: $Sql"
    }
}

$safeUser = Escape-Literal $DbUser
$safePassword = Escape-Literal $DbPassword
$safeDbName = Escape-Literal $DbName

$roleExists = Invoke-PsqlScalar "SELECT 1 FROM pg_roles WHERE rolname = '$safeUser';"
if ($roleExists -ne "1") {
    Invoke-Psql "CREATE ROLE `"$DbUser`" LOGIN PASSWORD '$safePassword' CREATEDB;"
}

$dbExists = Invoke-PsqlScalar "SELECT 1 FROM pg_database WHERE datname = '$safeDbName';"
if ($dbExists -ne "1") {
    Invoke-Psql "CREATE DATABASE `"$DbName`" OWNER `"$DbUser`" ENCODING 'UTF8';"
}

Write-Host "Database initialization complete for '$DbName'."
