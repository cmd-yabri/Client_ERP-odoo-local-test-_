param(
    [string]$PythonExe = ".\backend\venv\Scripts\python.exe",
    [string]$InnoCompiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    [string]$BuildRoot = ".\artifacts\windows",
    [string]$StageRoot = ".\artifacts\windows\package",
    [switch]$Clean,
    [switch]$InstallDesktopDeps,
    [switch]$IncludeVendorTools,
    [switch]$SkipChecksum,
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

# Walks up directories to locate repository root based on expected markers.
function Resolve-RepoRoot {
    param([Parameter(Mandatory = $true)][string]$StartDir)

    $current = (Resolve-Path $StartDir).Path
    while ($true) {
        if (
            (Test-Path (Join-Path $current "build\windows\build_windows.ps1")) -and
            (Test-Path (Join-Path $current "build\windows\stage_installer.ps1")) -and
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

# Throws with optional hint when a required file/directory is missing.
function Assert-FileExists {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Hint = ""
    )

    if (-not (Test-Path $Path)) {
        if ($Hint) {
            throw "$Hint`nMissing path: $Path"
        }
        throw "Required path not found: $Path"
    }
}

# Ensures a file exists and has at least a minimum byte length.
function Assert-NonEmptyFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int64]$MinimumBytes = 1,
        [string]$Hint = ""
    )

    Assert-FileExists -Path $Path -Hint $Hint
    $item = Get-Item -Path $Path -ErrorAction Stop
    if ($item.PSIsContainer) {
        throw "Expected file but found directory: $Path"
    }
    if ($item.Length -lt $MinimumBytes) {
        throw "File is too small or empty: $Path (size: $($item.Length) bytes, required >= $MinimumBytes bytes)"
    }
}

# Validates that the public key template is present and appears to be PEM.
function Assert-ValidPublicKeyTemplate {
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-FileExists -Path $Path -Hint "Public key template is required before release."
    $content = Get-Content -Path $Path -Raw

    if ($content -match "REPLACE_WITH_VENDOR_PUBLIC_KEY") {
        throw "Public key template still contains placeholder text. Update $Path with a real PEM public key."
    }
    if ($content -notmatch "-----BEGIN PUBLIC KEY-----" -or $content -notmatch "-----END PUBLIC KEY-----") {
        throw "Public key template is not a valid PEM public key file: $Path"
    }
}

# Resolves ISCC path across machine-level and user-level Inno Setup installs.
function Resolve-InnoCompilerPath {
    param([Parameter(Mandatory = $true)][string]$PreferredPath)

    $candidates = @(
        $PreferredPath,
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
        "C:\Program Files\Inno Setup 5\ISCC.exe"
    ) | Select-Object -Unique

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    throw "Inno Setup compiler not found. Checked: $($candidates -join '; ')"
}

$invocationDir = Get-InvocationDirectory
$repoRoot = Resolve-RepoRoot -StartDir $invocationDir
Set-Location $repoRoot

$InnoCompiler = Resolve-InnoCompilerPath -PreferredPath $InnoCompiler

$buildScript = Join-Path $repoRoot "build\windows\build_windows.ps1"
$stageScript = Join-Path $repoRoot "build\windows\stage_installer.ps1"
$installerScript = Join-Path $repoRoot "build\windows\build_installer.ps1"
$publicKeyTemplate = Join-Path $repoRoot "installer\windows\templates\public_key.pem"
$webView2Installer = Join-Path $repoRoot "third_party\webview2\MicrosoftEdgeWebView2RuntimeInstallerX64.exe"
$stageRootPath = if ([System.IO.Path]::IsPathRooted($StageRoot)) { $StageRoot } else { Join-Path $repoRoot $StageRoot }

Assert-FileExists -Path $PythonExe -Hint "Python executable for build pipeline is missing."
Assert-ValidPublicKeyTemplate -Path $publicKeyTemplate
Assert-NonEmptyFile -Path $webView2Installer -MinimumBytes 1024 -Hint "WebView2 offline installer is required. Download the Evergreen Standalone installer and place it at the expected path."

$buildArgs = @{
    PythonExe = $PythonExe
    OutputRoot = $BuildRoot
    Lto = $Lto
}
if ($Clean) { $buildArgs.Clean = $true }
if ($InstallDesktopDeps) { $buildArgs.InstallDesktopDeps = $true }
if ($IncludeVendorTools) { $buildArgs.IncludeVendorTools = $true }
if ($StopStaleBuildProcesses) { $buildArgs.StopStaleBuildProcesses = $true }

Write-Host "[1/4] Building binaries..."
& $buildScript @buildArgs
if ($LASTEXITCODE -ne 0) {
    throw "Build step failed."
}

Write-Host "[2/4] Staging installer package..."
& $stageScript -BuildRoot $BuildRoot -StageRoot $stageRootPath
if ($LASTEXITCODE -ne 0) {
    throw "Stage step failed."
}

Write-Host "[3/4] Compiling installer..."
& $installerScript -InnoCompiler $InnoCompiler -StageRoot $stageRootPath
if ($LASTEXITCODE -ne 0) {
    throw "Installer compile step failed."
}

$setupExeCandidates = @(
    (Join-Path $stageRootPath "ClientERP-Setup.exe"),
    (Join-Path $stageRootPath "Output\ClientERP-Setup.exe")
)

$setupExe = $null
foreach ($candidatePath in $setupExeCandidates) {
    if (Test-Path $candidatePath) {
        $setupExe = $candidatePath
        break
    }
}

if (-not $setupExe) {
    $candidate = Get-ChildItem -Path $stageRootPath -Filter "*Setup*.exe" -File -Recurse |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $candidate) {
        throw "Setup EXE not found in $stageRootPath or subdirectories."
    }
    $setupExe = $candidate.FullName
}

if (-not $SkipChecksum) {
    Write-Host "[4/4] Generating checksum..."
    $hash = Get-FileHash -Path $setupExe -Algorithm SHA256
    $checksumPath = "$setupExe.sha256"
    "$($hash.Hash.ToLower()) *$([System.IO.Path]::GetFileName($setupExe))" |
        Set-Content -Path $checksumPath -Encoding ASCII
    Write-Host "Checksum written: $checksumPath"
}
else {
    Write-Host "[4/4] Checksum skipped by request."
}

Write-Host "Release pipeline complete."
Write-Host "Installer: $setupExe"
