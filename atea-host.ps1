# ATEA Native Messaging Host
# Ontvangt update-verzoeken van de Chrome extensie en installeert de nieuwe versie.

$ErrorActionPreference = 'SilentlyContinue'
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

if ($msg.action -eq "ping") {
    Send-Response @{ success = $true; status = "ok" }
    exit 0
}

if ($msg.action -eq "update") {
    $InstallPath  = "$env:LOCALAPPDATA\LimeNetworks\ATEA"
    $TempZip      = "$env:TEMP\atea-update.zip"
    $TempExtract  = "$env:TEMP\atea-extract"
    $ZipUrl       = "https://raw.githubusercontent.com/Lime-Networks/atea-releases/main/extension.zip"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing

        if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }
        Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force

        $folder = Get-ChildItem $TempExtract | Where-Object { $_.PSIsContainer } | Select-Object -First 1
        $source = if ($folder) { $folder.FullName } else { $TempExtract }

        Copy-Item "$source\*" -Destination $InstallPath -Recurse -Force
        Remove-Item $TempZip      -Force -ErrorAction SilentlyContinue
        Remove-Item $TempExtract  -Recurse -Force -ErrorAction SilentlyContinue

        Send-Response @{ success = $true }
    } catch {
        Send-Response @{ success = $false; error = $_.Exception.Message }
    }
    exit 0
}

Send-Response @{ success = $false; error = "Onbekende actie: $($msg.action)" }
