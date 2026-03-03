param(
    [string]$OutputPath = ".\third_party\webview2\MicrosoftEdgeWebView2RuntimeInstallerX64.exe",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$RuntimeDownloadUrl = "https://go.microsoft.com/fwlink/?linkid=2124701"

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
            (Test-Path (Join-Path $current "build\windows\get_webview2_runtime.ps1")) -and
            (Test-Path (Join-Path $current "build\windows\release_windows.ps1")) -and
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

$invocationDir = Get-InvocationDirectory
$repoRoot = Resolve-RepoRoot -StartDir $invocationDir
Set-Location $repoRoot

$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
}
else {
    Join-Path $repoRoot $OutputPath
}

$outputDir = Split-Path -Path $resolvedOutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

if ((Test-Path $resolvedOutputPath) -and -not $Force) {
    $existing = Get-Item -Path $resolvedOutputPath -ErrorAction Stop
    Write-Host "WebView2 runtime installer already exists: $($existing.FullName) ($($existing.Length) bytes)"
    Write-Host "Use -Force to re-download."
    exit 0
}

$tempPath = "$resolvedOutputPath.download"
if (Test-Path $tempPath) {
    Remove-Item -Path $tempPath -Force
}

try {
    $head = Invoke-WebRequest -Uri $RuntimeDownloadUrl -Method Head -MaximumRedirection 10 -ErrorAction Stop
    if ($head.BaseResponse.ResponseUri) {
        Write-Host "Resolved download URL: $($head.BaseResponse.ResponseUri.AbsoluteUri)"
    }
}
catch {
    Write-Host "Could not resolve HEAD redirect. Continuing with direct download URL."
}

Write-Host "Downloading WebView2 x64 runtime installer..."
Invoke-WebRequest -Uri $RuntimeDownloadUrl -OutFile $tempPath -MaximumRedirection 10 -ErrorAction Stop

$downloaded = Get-Item -Path $tempPath -ErrorAction Stop
if ($downloaded.Length -lt 1024) {
    throw "Downloaded file is too small and appears invalid: $tempPath ($($downloaded.Length) bytes)"
}

if (Test-Path $resolvedOutputPath) {
    Remove-Item -Path $resolvedOutputPath -Force
}

Move-Item -Path $tempPath -Destination $resolvedOutputPath -Force
$final = Get-Item -Path $resolvedOutputPath -ErrorAction Stop

Write-Host "Saved WebView2 installer to: $($final.FullName)"
Write-Host "File size: $($final.Length) bytes"
