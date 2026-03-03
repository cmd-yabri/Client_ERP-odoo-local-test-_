param(
    [Parameter(Mandatory = $true)][string]$InstallerPath,
    [Parameter(Mandatory = $true)][string]$SuperPassword,
    [string]$ServiceName = "ClientERPPostgreSQL",
    [string]$InstallDir = "C:\Program Files\PostgreSQL\18",
    [string]$DataDir = "$env:ProgramData\ClientERP\postgres\data",
    [int]$Port = 5432
)

$ErrorActionPreference = "Stop"

# Returns true when a Windows service with the given name exists.
function Test-ServiceExists {
    param([string]$Name)
    try {
        Get-Service -Name $Name -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

if (Test-ServiceExists -Name $ServiceName) {
    Write-Host "PostgreSQL service '$ServiceName' already installed."
    exit 0
}

if (-not (Test-Path $InstallerPath)) {
    throw "PostgreSQL installer not found: $InstallerPath"
}

New-Item -ItemType Directory -Path $DataDir -Force | Out-Null

$arguments = @(
    "--mode", "unattended",
    "--unattendedmodeui", "none",
    "--disable-components", "stackbuilder",
    "--servicename", $ServiceName,
    "--serviceaccount", "NT AUTHORITY\NetworkService",
    "--superpassword", $SuperPassword,
    "--serverport", "$Port",
    "--datadir", $DataDir,
    "--prefix", $InstallDir
)

$proc = Start-Process -FilePath $InstallerPath -ArgumentList $arguments -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    throw "PostgreSQL installer failed with exit code $($proc.ExitCode)"
}

if (-not (Test-ServiceExists -Name $ServiceName)) {
    throw "PostgreSQL service was not created."
}

Write-Host "PostgreSQL installed successfully as service '$ServiceName'."
