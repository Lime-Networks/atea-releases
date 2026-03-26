# ============================================================
# Lime Networks — ATEA Installer / Updater
# Gebruik: rechtermuisknop → "Uitvoeren met PowerShell"
# ============================================================

$RepoZipUrl   = "https://raw.githubusercontent.com/Lime-Networks/atea-releases/main/extension.zip"
$InstallPath  = "$env:LOCALAPPDATA\LimeNetworks\ATEA"
$TempZip      = "$env:TEMP\atea-update.zip"
$TempExtract  = "$env:TEMP\atea-extract"

Write-Host ""
Write-Host "  Lime Networks — ATEA Installer" -ForegroundColor Green
Write-Host "  ================================" -ForegroundColor DarkGray
Write-Host ""

# Download
Write-Host "  Downloaden..." -ForegroundColor Cyan
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $TempZip -UseBasicParsing
} catch {
    Write-Host "  FOUT: Download mislukt. Controleer je internetverbinding." -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor DarkGray
    Read-Host "  Druk op Enter om te sluiten"
    exit 1
}

# Uitpakken
Write-Host "  Uitpakken..." -ForegroundColor Cyan
if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force

# Bronmap bepalen (GitHub zip heeft een submap)
$ExtractedFolder = Get-ChildItem $TempExtract | Where-Object { $_.PSIsContainer } | Select-Object -First 1
$Source = if ($ExtractedFolder) { $ExtractedFolder.FullName } else { $TempExtract }

# Installatiemap aanmaken en bestanden kopiëren
if (-not (Test-Path $InstallPath)) { New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null }
Copy-Item "$Source\*" -Destination $InstallPath -Recurse -Force

# Tijdelijke bestanden opruimen
Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  Klaar! Extensie staat in:" -ForegroundColor Green
Write-Host "  $InstallPath" -ForegroundColor White
Write-Host ""
Write-Host "  Volgende stap:" -ForegroundColor Yellow
Write-Host "  1. Open Chrome en ga naar chrome://extensions" -ForegroundColor White
Write-Host "  2. Schakel 'Ontwikkelaarsmodus' in (rechtsboven)" -ForegroundColor White
Write-Host "  3. Klik 'Niet-ingepakte extensie laden' en selecteer:" -ForegroundColor White
Write-Host "     $InstallPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Bij een UPDATE: klik alleen op het reload-icoontje naast de extensie." -ForegroundColor DarkGray
Write-Host ""

# Chrome openen op de extensions pagina
$OpenChrome = Read-Host "  Chrome extensions pagina openen? (j/n)"
if ($OpenChrome -eq "j" -or $OpenChrome -eq "J") {
    Start-Process "chrome" "--new-tab chrome://extensions" -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) {
        Start-Process "msedge" "--new-tab edge://extensions" -ErrorAction SilentlyContinue
    }
}

Read-Host "  Druk op Enter om te sluiten"
