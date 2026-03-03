param(
    [string]$PythonExe = ".\backend\venv\Scripts\python.exe",
    [string]$OutputRoot = ".\artifacts\windows",
    [switch]$Clean,
    [switch]$IncludeVendorTools,
    [switch]$InstallDesktopDeps,
    [switch]$StopStaleBuildProcesses,
    [ValidateSet("yes", "no", "auto")]
    [string]$Lto = "no"
)

$ErrorActionPreference = "Stop"

# Resolves current script directory safely whether called directly or dot-sourced.

function Get-InvocationDirectory {
    if ($PSScriptRoot -and $PSScriptRoot.Trim()) {
        return $PSScriptRoot
    }
    if ($MyInvocation.MyCommand.Path) {
        return Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    }
    return (Get-Location).Path
}

# Walks up the tree until repository root markers are found.
function Resolve-RepoRoot {
    param([Parameter(Mandatory = $true)][string]$StartDir)

    $current = (Resolve-Path $StartDir).Path
    while ($true) {
        if (
            (Test-Path (Join-Path $current "build\windows\build_windows.ps1")) -and
            (Test-Path (Join-Path $current "backend"))
        ) {
            return $current
        }

        $parent = Split-Path -Path $current -Parent
        if (-not $parent -or $parent -eq $current) {
            break
        }
        $current = $parent
    }

    throw "Could not resolve repository root from '$StartDir'. Run this script from inside the repository or pass full script path."
}

# Returns running python processes that currently host Nuitka/Scons builds.
function Get-NuitkaProcessList {
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
        Where-Object {
            $_.CommandLine -and (
                $_.CommandLine -match "\s-m\s+nuitka(\s|$)" -or
                $_.CommandLine -match "nuitka\\__main__\.py" -or
                $_.CommandLine -match "scons\.py"
            )
        } |
        Select-Object ProcessId, CommandLine
}

$invocationDir = Get-InvocationDirectory
$repoRoot = Resolve-RepoRoot -StartDir $invocationDir
Set-Location $repoRoot

$stale = Get-NuitkaProcessList
if ($stale) {
    if ($StopStaleBuildProcesses) {
        $pids = $stale.ProcessId
        Write-Host "Stopping stale Nuitka/Scons processes: $($pids -join ', ')"
        Stop-Process -Id $pids -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    }
    else {
        $pidList = ($stale.ProcessId | Sort-Object -Unique) -join ", "
        throw "Detected running Nuitka/Scons processes ($pidList). Close previous build terminals or rerun with -StopStaleBuildProcesses."
    }
}

if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found: $PythonExe"
}

& $PythonExe -c "import nuitka"
if ($LASTEXITCODE -ne 0) {
    throw "Nuitka is not installed in this interpreter. Install it with: `"$PythonExe`" -m pip install nuitka"
}

if ($InstallDesktopDeps) {
    & $PythonExe -m pip install -r ".\backend\requirements_windows_desktop.txt"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install desktop dependencies."
    }
}

& $PythonExe -c "import webview"
if ($LASTEXITCODE -ne 0) {
    throw "pywebview is missing. Run build_windows.ps1 with -InstallDesktopDeps or install backend\\requirements_windows_desktop.txt first."
}

& $PythonExe -c "import clr"
if ($LASTEXITCODE -ne 0) {
    throw "pythonnet (clr) is missing. Ensure backend\\requirements_windows_desktop.txt is installed before building launcher."
}

if ($Clean -and (Test-Path $OutputRoot)) {
    Remove-Item -Path $OutputRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

# Runs one Nuitka build target with common output and error handling.
function Invoke-NuitkaBuild {
    param(
        [string]$ScriptPath,
        [string]$BuildDir,
        [string]$OutputFileName,
        [string[]]$ExtraArgs
    )

    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
    $args = @(
        "-m", "nuitka",
        "--assume-yes-for-downloads",
        "--remove-output",
        "--output-dir=$BuildDir",
        "--output-filename=$OutputFileName"
    ) + $ExtraArgs + @($ScriptPath)

    Write-Host "Building $OutputFileName ..."
    & $PythonExe @args
    if ($LASTEXITCODE -ne 0) {
        throw "Nuitka build failed for $OutputFileName (exit code $LASTEXITCODE)."
    }
}

$common = @(
    "--standalone",
    "--lto=$Lto",
    "--python-flag=no_site",
    "--nofollow-import-to=*.tests"
)

Invoke-NuitkaBuild `
    -ScriptPath "backend\clienterp_server.py" `
    -BuildDir (Join-Path $OutputRoot "server") `
    -OutputFileName "clienterp_server.exe" `
    -ExtraArgs ($common + @(
        "--windows-console-mode=force",
        "--include-package=odoo",
        "--include-package=clienterp_runtime",
        "--include-data-dir=backend\addons=addons",
        "--include-data-dir=backend\custom_addons=custom_addons",
        "--include-data-dir=backend\custom_license=custom_license"
    ))

Invoke-NuitkaBuild `
    -ScriptPath "backend\clienterp_service.py" `
    -BuildDir (Join-Path $OutputRoot "service") `
    -OutputFileName "clienterp_service.exe" `
    -ExtraArgs ($common + @(
        "--onefile",
        "--windows-console-mode=disable",
        "--include-package=clienterp_runtime"
    ))

Invoke-NuitkaBuild `
    -ScriptPath "backend\clienterp_launcher.py" `
    -BuildDir (Join-Path $OutputRoot "launcher") `
    -OutputFileName "clienterp_launcher.exe" `
    -ExtraArgs ($common + @(
        "--onefile",
        "--windows-console-mode=disable",
        "--disable-plugin=pywebview",
        "--include-package-data=webview",
        "--include-module=webview.platforms.winforms",
        "--include-module=webview.platforms.edgechromium",
        "--include-module=clr"
    ))

Invoke-NuitkaBuild `
    -ScriptPath "backend\clienterp_activate.py" `
    -BuildDir (Join-Path $OutputRoot "activation") `
    -OutputFileName "clienterp_activate.exe" `
    -ExtraArgs ($common + @(
        "--onefile",
        "--windows-console-mode=force",
        "--include-package=clienterp_runtime"
    ))

if ($IncludeVendorTools) {
    Invoke-NuitkaBuild `
        -ScriptPath "backend\clienterp_vendor_license.py" `
        -BuildDir (Join-Path $OutputRoot "vendor_tools") `
        -OutputFileName "clienterp_license_vendor.exe" `
        -ExtraArgs ($common + @(
            "--onefile",
            "--windows-console-mode=force",
            "--include-package=clienterp_runtime"
        ))
}

Write-Host "Build completed. Output: $OutputRoot"
