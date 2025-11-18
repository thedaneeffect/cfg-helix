# Install fonts for current user
$fontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$fontFiles = Get-ChildItem -Path $fontsDir -Filter "ProggyClean*.ttf"

foreach ($font in $fontFiles) {
    $fontName = $font.BaseName
    # Register font in registry for current user
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

    # Check if already registered
    $existing = Get-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -ErrorAction SilentlyContinue

    if (-not $existing) {
        New-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -Value $font.FullName -PropertyType String -Force | Out-Null
        Write-Host "Registered: $fontName"
    } else {
        Write-Host "Already registered: $fontName"
    }
}

Write-Host "`nFonts registered. Please restart Windows Terminal."
