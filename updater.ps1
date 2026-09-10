# ============================================================
# Lime Networks - ATEA Installer / Updater
# Gebruik: dubbelklik op updater.cmd
# ============================================================

$RepoZipUrl   = "https://raw.githubusercontent.com/Lime-Networks/atea-releases/main/extension.zip"
$InstallPath  = "$env:LOCALAPPDATA\LimeNetworks\ATEA"
$TempZip      = "$env:TEMP\atea-update.zip"
$TempExtract  = "$env:TEMP\atea-extract"

Write-Host ""
Write-Host "  Lime Networks - ATEA Installer" -ForegroundColor Green
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

# Uitpakken en installeren
# LET OP: uitpakken en kopieren stonden hier zonder foutafhandeling, terwijl het script
# onderaan onvoorwaardelijk "Klaar!" printte. Een mislukte Copy-Item (bijvoorbeeld omdat
# de browser de extensie uit deze map geladen heeft en bestanden vasthoudt) scrollde dan
# als rode tekst voorbij en de gebruiker concludeerde dat de update gelukt was.
Write-Host "  Uitpakken..." -ForegroundColor Cyan
try {
    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force -ErrorAction Stop }
    Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force -ErrorAction Stop

    # Bronmap bepalen (een GitHub-source-zip heeft een submap, extension.zip niet)
    $ExtractedFolder = Get-ChildItem $TempExtract | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    $Source = if ($ExtractedFolder) { $ExtractedFolder.FullName } else { $TempExtract }

    if (-not (Test-Path "$Source\manifest.json")) {
        throw "Uitgepakte map bevat geen manifest.json - onverwachte zip-inhoud."
    }
    $NewVersion = ((Get-Content "$Source\manifest.json" -Raw) | Select-String '"version":\s*"([^"]+)"').Matches[0].Groups[1].Value

    Write-Host "  Installeren van v$NewVersion..." -ForegroundColor Cyan
    if (-not (Test-Path $InstallPath)) { New-Item -ItemType Directory -Path $InstallPath -Force -ErrorAction Stop | Out-Null }
    Copy-Item "$Source\*" -Destination $InstallPath -Recurse -Force -ErrorAction Stop

    # Verifieer dat het kopieren echt effect had; anders is "Klaar!" misleidend.
    $Installed = ((Get-Content "$InstallPath\manifest.json" -Raw) | Select-String '"version":\s*"([^"]+)"').Matches[0].Groups[1].Value
    if ($Installed -ne $NewVersion) {
        throw "Installatie niet doorgevoerd: map staat op v$Installed, verwacht v$NewVersion. Sluit de browser volledig en probeer opnieuw."
    }
    Write-Host "  Geverifieerd: v$Installed geinstalleerd." -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "  FOUT: installeren mislukt." -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Meestal komt dit doordat de browser de extensie nog geopend heeft." -ForegroundColor DarkGray
    Write-Host "  Sluit Chrome/Edge volledig af en voer updater.cmd opnieuw uit." -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Druk op Enter om te sluiten"
    exit 1
}

# Tijdelijke bestanden opruimen
Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue

# Native messaging host registreren
Write-Host "  Native messaging host registreren..." -ForegroundColor Cyan
$HostManifestPath = "$InstallPath\com.limenetworks.atea.json"
$HostCmdPath      = "$InstallPath\atea-host.cmd"

$hostManifest = [ordered]@{
    name            = "com.limenetworks.atea"
    description     = "ATEA Update Host"
    path            = $HostCmdPath
    type            = "stdio"
    allowed_origins = @("chrome-extension://olicheogjpiolepcgebnmeofppbffjod/")
}
$hostManifest | ConvertTo-Json | Set-Content -Path $HostManifestPath -Encoding UTF8

# Chrome EN Edge registreren. Edge leest een eigen registry-pad; stond dat er niet, dan
# faalde "Bijwerken" in de popup stil op Edge met "host not found" terwijl README Edge
# als ondersteund noemt.
foreach ($regPath in @(
    "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.limenetworks.atea",
    "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.limenetworks.atea"
)) {
    try {
        New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
        Set-ItemProperty -Path $regPath -Name "(Default)" -Value $HostManifestPath -ErrorAction Stop
        Write-Host "    geregistreerd: $($regPath -replace '^HKCU:\\Software\\','')" -ForegroundColor DarkGray
    } catch {
        Write-Host "    WAARSCHUWING: registreren mislukt voor $regPath" -ForegroundColor Yellow
        Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

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
Write-Host "  Updates verlopen voortaan automatisch via de extensie zelf." -ForegroundColor DarkGray
Write-Host ""

Read-Host "  Druk op Enter om te sluiten"
