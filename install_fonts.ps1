# Install and register fonts for current user
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceFontsDir = Join-Path $scriptDir "fonts"
$destFontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

# Create destination directory if it doesn't exist
if (-not (Test-Path $destFontsDir)) {
    New-Item -ItemType Directory -Path $destFontsDir -Force | Out-Null
}

# Get all font files from source
$fontFiles = Get-ChildItem -Path $sourceFontsDir -Filter "*.ttf"
$installedCount = 0

foreach ($font in $fontFiles) {
    $destPath = Join-Path $destFontsDir $font.Name
    $fontName = $font.BaseName

    # Copy font file
    Copy-Item -Path $font.FullName -Destination $destPath -Force

    # Register font in registry
    $existing = Get-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -ErrorAction SilentlyContinue

    if (-not $existing) {
        New-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -Value $destPath -PropertyType String -Force | Out-Null
    }

    $installedCount++
}

Write-Host "Installed $installedCount fonts"
