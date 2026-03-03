param(
    [string]$BuildRoot = ".\artifacts\windows",
    [string]$StageRoot = ".\artifacts\windows\package"
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
            (Test-Path (Join-Path $current "build\windows\stage_installer.ps1")) -and
            (Test-Path (Join-Path $current "installer\windows\clienterp.iss")) -and
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

    throw "Could not resolve repository root from '$StartDir'."
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

# Validates that the staged public key is present and appears to be PEM.
function Assert-ValidPublicKeyTemplate {
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-FileExists -Path $Path -Hint "Public key template is required for staging."
    $content = Get-Content -Path $Path -Raw

    if ($content -match "REPLACE_WITH_VENDOR_PUBLIC_KEY") {
        throw "Public key template still contains placeholder text. Update $Path with a real PEM public key."
    }
    if ($content -notmatch "-----BEGIN PUBLIC KEY-----" -or $content -notmatch "-----END PUBLIC KEY-----") {
        throw "Public key template is not a valid PEM public key file: $Path"
    }
}

$invocationDir = Get-InvocationDirectory
$repoRoot = Resolve-RepoRoot -StartDir $invocationDir
Set-Location $repoRoot

$buildRootPath = if ([System.IO.Path]::IsPathRooted($BuildRoot)) { $BuildRoot } else { Join-Path $repoRoot $BuildRoot }
$stageRootPath = if ([System.IO.Path]::IsPathRooted($StageRoot)) { $StageRoot } else { Join-Path $repoRoot $StageRoot }

$publicKeyTemplate = Join-Path $repoRoot "installer\windows\templates\public_key.pem"
Assert-ValidPublicKeyTemplate -Path $publicKeyTemplate

$serverDist = Join-Path $buildRootPath "server\clienterp_server.dist"
Assert-FileExists -Path $serverDist -Hint "Build artifacts are incomplete. Run build/windows/build_windows.ps1 first."

@(
    (Join-Path $buildRootPath "service\clienterp_service.exe"),
    (Join-Path $buildRootPath "launcher\clienterp_launcher.exe"),
    (Join-Path $buildRootPath "activation\clienterp_activate.exe")
) | ForEach-Object {
    Assert-FileExists -Path $_ -Hint "Build artifacts are incomplete. Run build/windows/build_windows.ps1 first."
}

$bundledWebView2Installer = Join-Path $repoRoot "third_party\webview2\MicrosoftEdgeWebView2RuntimeInstallerX64.exe"
Assert-NonEmptyFile -Path $bundledWebView2Installer -MinimumBytes 1024 -Hint "WebView2 offline installer is required. Download the Evergreen Standalone installer and place it at the expected path."

if (Test-Path $stageRootPath) {
    Remove-Item -Path $stageRootPath -Recurse -Force
}

New-Item -ItemType Directory -Path $stageRootPath -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stageRootPath "app") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stageRootPath "scripts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stageRootPath "templates") -Force | Out-Null

Copy-Item -Path $serverDist -Destination (Join-Path $stageRootPath "app\server") -Recurse -Force
Copy-Item -Path (Join-Path $buildRootPath "service\clienterp_service.exe") -Destination (Join-Path $stageRootPath "app\clienterp_service.exe") -Force
Copy-Item -Path (Join-Path $buildRootPath "launcher\clienterp_launcher.exe") -Destination (Join-Path $stageRootPath "app\clienterp_launcher.exe") -Force
Copy-Item -Path (Join-Path $buildRootPath "activation\clienterp_activate.exe") -Destination (Join-Path $stageRootPath "app\clienterp_activate.exe") -Force

Copy-Item -Path (Join-Path $repoRoot "installer\windows\scripts\*.ps1") -Destination (Join-Path $stageRootPath "scripts") -Force
Copy-Item -Path (Join-Path $repoRoot "installer\windows\templates\*") -Destination (Join-Path $stageRootPath "templates") -Force
Copy-Item -Path (Join-Path $repoRoot "installer\windows\clienterp.iss") -Destination (Join-Path $stageRootPath "clienterp.iss") -Force

$bundledPgInstaller = Join-Path $repoRoot "third_party\postgresql\postgresql-installer.exe"
if (Test-Path $bundledPgInstaller) {
    Copy-Item -Path $bundledPgInstaller -Destination (Join-Path $stageRootPath "postgresql-installer.exe") -Force
}

Copy-Item -Path $bundledWebView2Installer -Destination (Join-Path $stageRootPath "MicrosoftEdgeWebView2RuntimeInstallerX64.exe") -Force

Write-Host "Installer staging complete: $stageRootPath"
