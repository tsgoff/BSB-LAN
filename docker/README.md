# BSB-LAN Firmware lokal mit Docker bauen

Baut die BSB-LAN-Firmware mit deiner eigenen `BSB_LAN_custom_defs.h` – ohne Arduino IDE, ohne
GitHub-Account, komplett lokal. Ergebnis ist eine fertig geflashte, gemergte `.bin`-Datei pro
Board (Bootloader + Partitionstabelle + App in einer Datei), analog zu den Recovery-Images unter
`docs.bsb-lan.de/recovery_flasher`.

## Voraussetzung

Nur [Docker](https://docs.docker.com/get-docker/). Kein arduino-cli, keine Board-Pakete, keine
Bibliotheken – alles davon steckt bereits im Image.

## 1. Image bauen

Aus dem Wurzelverzeichnis des Repos (nicht aus `docker/`):

```bash
docker build -f docker/Dockerfile -t bsb-lan-builder .
```

Das Image enthält den Stand des Repos zum Build-Zeitpunkt inkl. arduino-cli, ESP32-Core und
benötigter Bibliotheken. Wenn sich der BSB-LAN-Quellcode ändert (z.B. `git pull`), muss das Image
neu gebaut werden.

## 2. Eigene Konfigurationsdateien bereitlegen

Du brauchst mindestens deine individuelle `BSB_LAN_custom_defs.h` (die Datei mit den
Klartext-Bezeichnungen für deine Heizung, siehe Haupt-Dokumentation zu
`BSB_LAN_custom_defs.h.default`). `BSB_LAN_config.h` (WLAN/Netzwerk) ist optional – ohne sie wird
die generische `.default`-Vorlage verwendet.

Lege die Dateien irgendwo lokal ab, z.B.:

```
~/bsb-lan-build/BSB_LAN_custom_defs.h
~/bsb-lan-build/BSB_LAN_config.h      # optional
```

## 3. Container laufen lassen

```bash
mkdir -p ~/bsb-lan-build/out

docker run --rm \
  -v ~/bsb-lan-build/BSB_LAN_custom_defs.h:/custom/BSB_LAN_custom_defs.h:ro \
  -v ~/bsb-lan-build/BSB_LAN_config.h:/custom/BSB_LAN_config.h:ro \
  -v ~/bsb-lan-build/out:/out \
  bsb-lan-builder esp32-poe-iso
```

Die `BSB_LAN_config.h`-Zeile kannst du weglassen, wenn du keine eigene Netzwerk-Konfiguration
mitgeben willst.

**Board-Auswahl** (letztes Argument):

| Argument             | Board                                    | Flash |
|----------------------|-------------------------------------------|-------|
| `esp32-devkit`       | Standard-ESP32-NodeMCU                    | 4 MB  |
| `esp32-evb`          | Olimex ESP32-EVB                          | 4 MB  |
| `esp32-poe-iso`      | Olimex ESP32-POE-ISO                      | 4 MB  |
| `esp32-poe-iso-16mb` | Olimex ESP32-POE-ISO mit 16 MB Flash-Chip | 16 MB |
| `all`                | alle vier oben, nacheinander              | –     |

Ohne Argument wird `esp32-devkit` gebaut.

## 4. Ergebnis

Nach erfolgreichem Lauf liegt in `~/bsb-lan-build/out/`:

```
out/
├── bin/
│   └── bsb-lan-esp32-poe-iso-merged.bin
└── manifests/
    └── bsb-lan-esp32-poe-iso.json
```

Die `.bin`-Datei ist ein **fertig gemergtes Komplett-Image** (Bootloader + Partitionstabelle +
`boot_app0` + Anwendung) – du musst nicht mehr mehrere Dateien auf verschiedene Flash-Adressen
verteilen, es reicht **eine Adresse: `0x0`**.

## 5. Firmware aufs Gerät bringen

### Option A: esptool.py (lokal, per USB)

```bash
pip install esptool
esptool.py --chip esp32 --port /dev/ttyUSB0 --baud 921600 \
  write_flash 0x0 ~/bsb-lan-build/out/bin/bsb-lan-esp32-poe-iso-merged.bin
```

(`/dev/ttyUSB0` durch den tatsächlichen seriellen Port ersetzen, unter Windows z.B. `COM5`.)

### Option B: esptool-js (Browser, ohne Installation)

1. Öffne [esptool-js](https://espressif.github.io/esptool-js/) in Chrome oder Edge
   (WebSerial wird von Firefox nicht unterstützt).
2. "Connect" klicken, seriellen Port auswählen.
3. Datei `bsb-lan-esp32-poe-iso-merged.bin` bei **Adresse `0x0`** hinzufügen.
4. "Program" klicken und warten, bis der Vorgang abgeschlossen ist.

### Option C: ESP Web Tools

Die mitgelieferte `bsb-lan-<board>.json`-Manifest-Datei ist im Format von
[ESP Web Tools](https://esphome.github.io/esp-web-tools/) kompatibel und kann z.B. für eine
eigene statische Flash-Seite verwendet werden (`bin/` und `manifests/` müssen dabei im gleichen
relativen Pfad zueinander bleiben, wie sie hier erzeugt wurden).

## Hinweise

- Der Container schreibt nichts außerhalb der gemounteten Verzeichnisse (`/custom`, `/out`) – dein
  Repo-Checkout bleibt unverändert.
- Mehrere Boards in einem Lauf: `... bsb-lan-builder all` baut alle vier Varianten hintereinander
  in denselben `out/`-Ordner.
- Die eigentliche Build-Logik (`docker/entrypoint.sh`) ist bewusst identisch zum
  `build_one`-Schritt in `.github/workflows/esp32-recovery.yaml` gehalten, damit lokale und
  CI-Builds nicht auseinanderlaufen.
