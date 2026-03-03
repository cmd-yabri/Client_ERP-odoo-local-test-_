param(
    [string]$InnoCompiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    [string]$StageRoot = ".\artifacts\windows\package"
)

$ErrorActionPreference = "Stop"

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

$InnoCompiler = Resolve-InnoCompilerPath -PreferredPath $InnoCompiler

if (-not (Test-Path $StageRoot)) {
    throw "Stage root not found: $StageRoot"
}

$iss = Join-Path $StageRoot "clienterp.iss"
if (-not (Test-Path $iss)) {
    throw "Installer script not found: $iss"
}

& $InnoCompiler $iss
if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}

Write-Host "Installer build complete."
