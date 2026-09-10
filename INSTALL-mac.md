# ATEA installeren op macOS

Werkt op Chrome en Edge. Duurt ongeveer een minuut.

## 1. Installer ophalen

Download `install-mac.command` uit de
[atea-releases repository](https://github.com/Lime-Networks/atea-releases).

macOS zet een quarantainevlag op alles wat via een browser, AirDrop of e-mail
binnenkomt, en dan weigert Gatekeeper het script te starten. Eenmalig weghalen,
in de map waar je het bestand hebt opgeslagen:

```bash
xattr -d com.apple.quarantine install-mac.command
chmod +x install-mac.command
```

## 2. Installer starten

```bash
./install-mac.command
```

De installer downloadt de laatste versie, verifieert de SHA-256, plaatst de
extensie in `~/Library/Application Support/LimeNetworks/ATEA` en registreert de
update-host voor Chrome en Edge. Hij controleert daarna zelf of de installatie
echt geland is en stopt met een duidelijke fout als dat niet zo is.

Start Chrome minimaal één keer voordat je dit doet, anders bestaat het
browserprofiel nog niet en kan de host niet geregistreerd worden.

> **Vanuit een repo-checkout** installeer je met `./mac/install-mac.command --local .`
> vanuit de repo-root. Dat gebruikt je lokale bestanden in plaats van de release,
> handig bij ontwikkelen.

## 3. Extensie eenmalig laden

1. Open `chrome://extensions` (of `edge://extensions`)
2. Zet **Ontwikkelaarsmodus** aan, rechtsboven
3. Klik **Uitgepakte extensie laden** en kies:
   `~/Library/Application Support/LimeNetworks/ATEA`

Finder verbergt `~/Library`. Open de map met:

```bash
open ~/Library/Application\ Support/LimeNetworks/ATEA
```

## Klaar

Open een Autotask-ticket; naast **Summary Notes** horen de knoppen ✨ 📝 ⚡ te
staan. Zet de sneltoets naar wens via `chrome://extensions/shortcuts` — die is
standaard niet gebonden.

Updates gaan daarna via de **Bijwerken**-knop in de extensie; stap 2 hoef je niet
opnieuw te doen.

## Werkt iets niet

De popup toont bij een mislukte update zelf de oorzaak. Meer detail staat in:

```bash
tail -20 ~/Library/Application\ Support/LimeNetworks/ATEA/atea-host.log
```

Staat daar na een klik op **Bijwerken** geen nieuwe regel, dan is de update-host
niet gestart en is het een registratieprobleem. Voer stap 2 dan opnieuw uit.
