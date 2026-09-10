#!/bin/bash
# ============================================================
# Lime Networks - ATEA Installer / Updater (macOS)
# Tegenhanger van updater.ps1 / updater.cmd
#
# Gebruik:
#   ./install-mac.command                 installeer vanaf GitHub releases
#   ./install-mac.command --local ../     installeer vanuit een repo-checkout
#
# De --local modus is bedoeld om te testen voordat de Mac-bestanden in
# extension.zip zitten. Zonder die modus haalt de installer de release op, en
# die bevat atea-host.sh pas nadat release.yml is bijgewerkt.
# ============================================================

set -u

INSTALL_DIR="$HOME/Library/Application Support/LimeNetworks/ATEA"
STAGING_DIR="$HOME/Library/Application Support/LimeNetworks/.atea-install"
ZIP_URL="https://raw.githubusercontent.com/Lime-Networks/atea-releases/main/extension.zip"
HASH_URL="https://raw.githubusercontent.com/Lime-Networks/atea-releases/main/extension.sha256"

# De extensie-ID staat vast door de "key" in manifest.json, dus die is op elk
# platform gelijk. Wijzigt die key, dan moet dit mee.
EXT_ID="olicheogjpiolepcgebnmeofppbffjod"

# Bestanden die de extensie vormen. Bewust expliciet, gelijk aan de allow-list
# in .github/workflows/release.yml, zodat een hernoemd bestand hier opvalt.
EXT_FILES="manifest.json version.json background.js content.crypto.js content.ai.js
           content.db.js content.polish.js content.mail.js content.observer.js
           popup.html popup.js styles.css"

RED=$'\033[31m'; GREEN=$'\033[32m'; CYAN=$'\033[36m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'

say()  { printf '  %s%s%s\n' "${2:-}" "$1" "$OFF"; }
die()  {
  printf '\n  %sFOUT: %s%s\n\n' "$RED" "$1" "$OFF"
  printf '  %s%s%s\n\n' "$DIM" "${2:-}" "$OFF"
  printf '  Druk op Enter om te sluiten'; read -r _
  exit 1
}

read_version() {
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -1
}

printf '\n'
say "Lime Networks - ATEA Installer (macOS)" "$GREEN"
say "======================================" "$DIM"
printf '\n'

# --- Bron bepalen ----------------------------------------------------------
MODE="download"
LOCAL_DIR=""
if [ "${1:-}" = "--local" ]; then
  MODE="local"
  LOCAL_DIR="${2:-}"
  [ -n "$LOCAL_DIR" ] || die "Geef een map mee: ./install-mac.command --local /pad/naar/atea"
  # Pad absoluut maken; de installer kan van elders gestart zijn.
  LOCAL_DIR=$(cd "$LOCAL_DIR" 2>/dev/null && pwd) || die "Map bestaat niet: ${2:-}"
fi

rm -rf "$STAGING_DIR" 2>/dev/null
mkdir -p "$STAGING_DIR" || die "Kan staging-map niet aanmaken onder ~/Library/Application Support/LimeNetworks."
SRC="$STAGING_DIR/src"
mkdir -p "$SRC"

if [ "$MODE" = "local" ]; then
  say "Bron: lokale map $LOCAL_DIR" "$CYAN"
  [ -f "$LOCAL_DIR/manifest.json" ] || die "Geen manifest.json in $LOCAL_DIR" \
    "Wijs naar de map met manifest.json (de repo-root, niet de mac-submap)."
  for f in $EXT_FILES; do
    [ -f "$LOCAL_DIR/$f" ] || die "Ontbrekend bestand: $f" "De repo lijkt incompleet."
    cp "$LOCAL_DIR/$f" "$SRC/" || die "Kan $f niet kopieren."
  done
  # De host: eerst uit mac/ in de checkout, anders naast deze installer.
  if   [ -f "$LOCAL_DIR/mac/atea-host.sh" ]; then cp "$LOCAL_DIR/mac/atea-host.sh" "$SRC/"
  elif [ -f "$(dirname "$0")/atea-host.sh" ];  then cp "$(dirname "$0")/atea-host.sh" "$SRC/"
  else die "atea-host.sh niet gevonden" "Verwacht in $LOCAL_DIR/mac/ of naast deze installer."
  fi
else
  say "Downloaden..." "$CYAN"
  curl -fsSL --max-time 120 -o "$STAGING_DIR/extension.zip" "$ZIP_URL" \
    || die "Download mislukt." "Controleer de internetverbinding."

  say "Integriteit controleren..." "$CYAN"
  EXPECTED=$(curl -fsSL --max-time 30 "$HASH_URL" | tr -d ' \r\n' | tr 'A-F' 'a-f') \
    || die "Kan de verwachte hash niet ophalen."
  printf '%s' "$EXPECTED" | grep -Eq '^[0-9a-f]{64}$' || die "Ongeldige hash ontvangen."
  ACTUAL=$(shasum -a 256 "$STAGING_DIR/extension.zip" | awk '{print $1}')
  [ "$ACTUAL" = "$EXPECTED" ] || die "SHA-256 mismatch - installatie afgebroken." \
    "Verwacht: $EXPECTED / Werkelijk: $ACTUAL"
  say "Hash geverifieerd." "$DIM"

  say "Uitpakken..." "$CYAN"
  unzip -o -q "$STAGING_DIR/extension.zip" -d "$SRC" || die "Uitpakken mislukt."
  if [ ! -f "$SRC/manifest.json" ]; then
    SUB=$(find "$SRC" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
    if [ -n "$SUB" ] && [ -f "$SUB/manifest.json" ]; then
      mv "$SUB"/* "$SRC"/ 2>/dev/null
    fi
  fi
  [ -f "$SRC/manifest.json" ] || die "Zip bevat geen manifest.json."

  if [ ! -f "$SRC/atea-host.sh" ]; then
    if [ -f "$(dirname "$0")/atea-host.sh" ]; then
      say "atea-host.sh zit nog niet in de release - de versie naast deze installer wordt gebruikt." "$YELLOW"
      cp "$(dirname "$0")/atea-host.sh" "$SRC/"
    else
      die "atea-host.sh zit niet in de release en staat niet naast deze installer." \
          "Voeg mac/atea-host.sh toe aan de zip-lijst in release.yml, of gebruik --local."
    fi
  fi
fi

NEW_VERSION=$(read_version "$SRC/manifest.json")
[ -n "$NEW_VERSION" ] || die "Kan de versie niet uit manifest.json lezen."

# --- Installeren -----------------------------------------------------------
say "Installeren van v$NEW_VERSION..." "$CYAN"
mkdir -p "$INSTALL_DIR" || die "Kan installatiemap niet aanmaken."

# mv i.p.v. cp: als de host op dit moment draait, vervangt een rename alleen de
# directory-entry en blijft de draaiende shell de oude inode lezen.
for f in "$SRC"/*; do
  [ -e "$f" ] || continue
  mv -f "$f" "$INSTALL_DIR/$(basename "$f")" || die "Kan $(basename "$f") niet plaatsen." \
    "Sluit Chrome/Edge volledig af en probeer opnieuw."
done

chmod +x "$INSTALL_DIR/atea-host.sh" || die "Kan atea-host.sh niet uitvoerbaar maken."

# Verifieer dat het echt geland is; anders is een succesmelding misleidend.
INSTALLED=$(read_version "$INSTALL_DIR/manifest.json")
[ "$INSTALLED" = "$NEW_VERSION" ] || die \
  "Installatie niet doorgevoerd: map staat op v${INSTALLED:-onbekend}, verwacht v$NEW_VERSION." \
  "Sluit Chrome/Edge volledig af en probeer opnieuw."
say "Geverifieerd: v$INSTALLED geinstalleerd." "$GREEN"

# --- Native messaging host registreren -------------------------------------
# Geen registry op macOS: de locatie van dit manifest IS de registratie.
say "Native messaging host registreren..." "$CYAN"
HOST_MANIFEST="{
  \"name\": \"com.limenetworks.atea\",
  \"description\": \"ATEA Update Host\",
  \"path\": \"$INSTALL_DIR/atea-host.sh\",
  \"type\": \"stdio\",
  \"allowed_origins\": [ \"chrome-extension://$EXT_ID/\" ]
}"

REGISTERED=0
for target in \
  "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts" \
  "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
do
  # Alleen registreren als de browser daadwerkelijk een profielmap heeft.
  parent=$(dirname "$target")
  if [ ! -d "$parent" ]; then
    say "overgeslagen (niet geinstalleerd): $(basename "$parent")" "$DIM"
    continue
  fi
  if mkdir -p "$target" 2>/dev/null &&
     printf '%s\n' "$HOST_MANIFEST" > "$target/com.limenetworks.atea.json" 2>/dev/null; then
    say "geregistreerd: $(basename "$parent")" "$DIM"
    REGISTERED=$((REGISTERED + 1))
  else
    say "WAARSCHUWING: registreren mislukt voor $(basename "$parent")" "$YELLOW"
  fi
done
[ "$REGISTERED" -gt 0 ] || die "Geen enkele browser geregistreerd." \
  "Start Chrome of Edge minimaal een keer, zodat het profiel bestaat, en probeer opnieuw."

rm -rf "$STAGING_DIR" 2>/dev/null

printf '\n'
say "Klaar. Extensie staat in:" "$GREEN"
say "$INSTALL_DIR" "$OFF"
printf '\n'
say "Volgende stap - eenmalig de extensie laden:" "$YELLOW"
say "1. Open chrome://extensions (of edge://extensions)"
say "2. Zet 'Ontwikkelaarsmodus' aan, rechtsboven"
say "3. Klik 'Uitgepakte extensie laden' en kies de map hierboven"
printf '\n'
say "Tip: open de map met  open \"$INSTALL_DIR\"" "$DIM"
say "Updates verlopen daarna via de Bijwerken-knop in de extensie." "$DIM"
printf '\n'
printf '  Druk op Enter om te sluiten'; read -r _
