param(
    [Parameter(Mandatory = $true)][string]$InstallerPath,
    [string]$MinVersion = "0.0.0.0"
)

$ErrorActionPreference = "Stop"

$WebView2Guid = "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$WebView2Guid",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$WebView2Guid",
    "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$WebView2Guid"
)

# Reads installed WebView2 runtime version from known registry locations.
function Get-WebView2Version {
    foreach ($path in $RegistryPaths) {
        try {
            $item = Get-ItemProperty -Path $path -ErrorAction Stop
            if ($item.pv) {
                return "$($item.pv)".Trim()
            }
        }
        catch {
            continue
        }
    }
    return ""
}

# Safely parses version strings, defaulting to 0.0.0.0 on invalid input.
function Convert-Version {
    param([string]$Value)
    try {
        return [Version]$Value
    }
    catch {
        return [Version]"0.0.0.0"
    }
}

$installedVersionRaw = Get-WebView2Version
$installedVersion = Convert-Version $installedVersionRaw
$requiredVersion = Convert-Version $MinVersion

if ($installedVersionRaw -and $installedVersion -ge $requiredVersion) {
    Write-Host "WebView2 runtime already installed ($installedVersionRaw)."
    exit 0
}

if (-not (Test-Path $InstallerPath)) {
    throw "WebView2 installer not found: $InstallerPath"
}

$arguments = @("/silent", "/install")
$process = Start-Process -FilePath $InstallerPath -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -notin @(0, 3010)) {
    throw "WebView2 installer failed with exit code $($process.ExitCode)"
}

$postInstallVersion = Get-WebView2Version
if (-not $postInstallVersion) {
    throw "WebView2 install did not register successfully."
}

if ((Convert-Version $postInstallVersion) -lt $requiredVersion) {
    throw "WebView2 installed version ($postInstallVersion) is below required minimum ($MinVersion)."
}

Write-Host "WebView2 runtime installed/verified: $postInstallVersion"
