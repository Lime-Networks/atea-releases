# ATEA Native Messaging Host
# Ontvangt update-verzoeken van de Chrome extensie en installeert de nieuwe versie.

$ErrorActionPreference = 'SilentlyContinue'
$LogFile = "$env:LOCALAPPDATA\LimeNetworks\ATEA\atea-host.log"
function Write-Log($msg) {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg" | Add-Content -Path $LogFile -Encoding UTF8
}
$stdout = [System.Console]::OpenStandardOutput()
$stdin  = [System.Console]::OpenStandardInput()

# Lees 4-byte lengte prefix (little-endian)
$lenBytes = New-Object byte[] 4
$read = 0
while ($read -lt 4) {
    $r = $stdin.Read($lenBytes, $read, 4 - $read)
    if ($r -le 0) { exit 1 }
    $read += $r
}
$len = [BitConverter]::ToInt32($lenBytes, 0)

# Lees JSON bericht
$msgBytes = New-Object byte[] $len
$read = 0
while ($read -lt $len) {
    $r = $stdin.Read($msgBytes, $read, $len - $read)
    if ($r -le 0) { exit 1 }
    $read += $r
}
$msg = [System.Text.Encoding]::UTF8.GetString($msgBytes) | ConvertFrom-Json

function Send-Response($obj) {
    $json  = $obj | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $lenB  = [BitConverter]::GetBytes([int32]$bytes.Length)
    $stdout.Write($lenB, 0, 4)
    $stdout.Write($bytes, 0, $bytes.Length)
    $stdout.Flush()
}

Write-Log "Host gestart, actie: $($msg.action)"

if ($msg.action -eq "ping") {
    Write-Log "Ping ontvangen"
    Send-Response @{ success = $true; status = "ok" }
    exit 0
}

if ($msg.action -eq "update") {
    $InstallPath  = "$env:LOCALAPPDATA\LimeNetworks\ATEA"
    $TempZip      = "$env:TEMP\atea-update.zip"
    $TempExtract  = "$env:TEMP\atea-extract"
    $ZipUrl       = "https://raw.githubusercontent.com/Lime-Networks/atea-releases/main/extension.zip"

    try {
        Write-Log "Downloaden van $ZipUrl"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing
        Write-Log "Download klaar"

        if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
        Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force
        Write-Log "Uitgepakt"

        $folder = Get-ChildItem $TempExtract | Where-Object { $_.PSIsContainer } | Select-Object -First 1
        $source = if ($folder) { $folder.FullName } else { $TempExtract }

        Copy-Item "$source\*" -Destination $InstallPath -Recurse -Force
        Remove-Item $TempZip      -Force -ErrorAction SilentlyContinue
        Remove-Item $TempExtract  -Recurse -Force -ErrorAction SilentlyContinue

        Write-Log "Update succesvol geinstalleerd"
        Send-Response @{ success = $true }
    } catch {
        Write-Log "FOUT: $($_.Exception.Message)"
        Send-Response @{ success = $false; error = $_.Exception.Message }
    }
    exit 0
}

Write-Log "Onbekende actie: $($msg.action)"
Send-Response @{ success = $false; error = "Onbekende actie: $($msg.action)" }
