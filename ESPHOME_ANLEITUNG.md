# BSB-LAN – ESPHome Installationsanleitung

Diese Anleitung beschreibt, wie BSB-LAN als **ESPHome External Component** auf einem ESP32 eingerichtet wird. Damit lässt sich die Heizungsanbindung direkt in **Home Assistant** integrieren, ohne die klassische Arduino-IDE-Methode zu verwenden.

---

## Voraussetzungen

| Anforderung | Details |
|-------------|---------|
| **Hardware** | ESP32-Board (z. B. ESP32 NodeMCU, Olimex ESP32-EVB, ESP32-POE) |
| **BSB-LAN Adapter** | Passende Interface-Platine für den ESP32 |
| **ESPHome** | Version 2023.x oder neuer |
| **Home Assistant** | Optional, aber empfohlen |

### ESPHome installieren

Falls ESPHome noch nicht installiert ist, gibt es zwei Möglichkeiten:

**Option A – Home Assistant Add-on** *(empfohlen)*:
  - Home Assistant → *Einstellungen → Add-ons → Add-on Store*
  - „ESPHome" suchen und installieren

**Option B – Python/pip**:
```bash
pip install esphome
```

---

## Repository klonen

Das BSB-LAN-Repository enthält bereits die notwendige ESPHome External Component im Ordner `external_components/`:

```bash
git clone https://github.com/fredlcore/BSB-LAN.git
cd BSB-LAN
```

Die relevanten Dateien für ESPHome:

```
BSB-LAN/
├── example_esphome.yaml        ← Beispiel-Konfiguration
└── external_components/
    └── bsb_lan/                ← ESPHome Component
        ├── __init__.py
        ├── sensor.py
        └── src/
            ├── bsb_lan.h / .cpp
            ├── bsb_protocol.h / .cpp
            ├── bsb_sensor.h / .cpp
            └── bsb_types.h
```

---

## Konfiguration erstellen

Erstelle eine neue Datei, z. B. `meine-heizung.yaml`, basierend auf der mitgelieferten `example_esphome.yaml`. Passe die folgenden Abschnitte an deine Hardware an:

```yaml
esphome:
  name: bsb-lan-esphome

esp32:
  board: esp32dev  # Anpassen: esp32dev, esp32-poe, esp32-evb, etc.

# WLAN-Verbindung
wifi:
  ssid: "DeinNetzwerk"
  password: "DeinPasswort"

# Optional: Fallback Hotspot wenn WLAN nicht erreichbar
  ap:
    ssid: "BSB-LAN Fallback"
    password: "fallback123"

# Home Assistant API (für direkte HA-Integration)
api:
  encryption:
    key: "dein-api-key"  # Kann in ESPHome generiert werden

# OTA-Updates
ota:
  password: "dein-ota-passwort"

# Logging über serielle Schnittstelle
logger:

# Externe BSB-LAN Komponente aus dem lokalen Verzeichnis laden
external_components:
  - source:
      type: local
      path: external_components  # Pfad zum external_components Ordner im Repository

# UART-Konfiguration für den BSB-Adapter
# BSB nutzt 4800 Baud, 8 Bit, Even Parity, 1 Stopbit
uart:
  id: uart_bus
  tx_pin: GPIO17  # TX-Pin anpassen (Adapterabhängig)
  rx_pin: GPIO16  # RX-Pin anpassen (Adapterabhängig)
  baud_rate: 4800
  parity: EVEN
  stop_bits: 1

# BSB-LAN Komponente
bsb_lan:
  id: bsb_adapter
  bus_type: BSB   # BSB, LPB oder PPS
  my_addr: 0x42   # Adresse dieses Geräts auf dem Bus
  dest_addr: 0x00 # Adresse der Heizung (Standard: 0x00)

# Sensoren definieren
sensor:
  - platform: bsb_lan
    name: "Außentemperatur"
    parameter: 0x053D050E  # Command-ID für Parameter 8700
    type: TEMP
    update_interval: 60s

  - platform: bsb_lan
    name: "Kesseltemperatur"
    parameter: 0x053D0510  # Command-ID für Parameter 8740
    type: TEMP
    update_interval: 60s
```

---

## Verfügbare Bus-Typen

| `bus_type` | Beschreibung |
|-----------|--------------|
| `BSB` | Boiler System Bus – Standard bei den meisten Siemens-geregelten Heizungen |
| `LPB` | Local Process Bus – für ältere oder vernetzte Anlagen |
| `PPS` | Punkt-zu-Punkt-Schnittstelle – für sehr einfache Steuergeräte |

---

## Verfügbare Sensor-Typen (`type`)

| Typ | Beschreibung | Einheit |
|-----|-------------|---------|
| `TEMP` | Temperatur | °C |
| `PRESSURE` | Druck | bar |
| `PERCENT` | Prozentwert | % |
| `TEMP_SHORT5` | Kurztemperatur (0,5°-Auflösung) | °C |
| `ONOFF` | Ein/Aus-Status | – |

---

## Firmware flashen

### Via ESPHome CLI

```bash
# Aus dem BSB-LAN Stammverzeichnis ausführen
esphome run meine-heizung.yaml
```

Beim ersten Flash muss das ESP32-Board per USB verbunden sein. Danach sind OTA-Updates möglich.

### Via Home Assistant ESPHome Add-on

1. ESPHome-Dashboard öffnen
2. **„+ New Device"** → Konfiguration manuell einfügen oder YAML hochladen
3. Auf **„Install"** klicken → „Plug into this computer" oder direkt via OTA

---

## Erster Start & Integration in Home Assistant

1. Nach dem Flash erscheint das Gerät automatisch unter  
   *Home Assistant → Einstellungen → Geräte & Dienste → ESPHome*
2. Integration hinzufügen und API-Key bestätigen
3. Alle definierten Sensoren erscheinen als Entitäten in Home Assistant

---

## GPIO-Pinbelegung nach Board

| Board | TX-Pin | RX-Pin | Hinweis |
|-------|--------|--------|---------|
| ESP32 NodeMCU (Dev Module) | GPIO17 | GPIO16 | Standard Hardware Serial 2 |
| Olimex ESP32-EVB | GPIO17 | GPIO16 | Adapter auf UEXT oder GPIO |
| Olimex ESP32-POE-ISO | GPIO17 | GPIO16 | PoE-Versorgung möglich |

> Die genaue Pinbelegung hängt vom verwendeten BSB-LAN-Adapterboard ab. Im Zweifel die Schaltpläne unter `BSB_LAN/schematics/` prüfen.

---

## Häufige Probleme

| Problem | Lösung |
|---------|--------|
| `external_components` nicht gefunden | YAML-Datei muss im selben Verzeichnis wie `external_components/` liegen oder der Pfad muss angepasst werden |
| Keine Daten vom Bus | TX/RX-Pins prüfen, ggf. tauschen; Signal-Inversion aktivieren (`use_signal_inversion: true` im uart-Block) |
| Heizung antwortet nicht | `dest_addr` prüfen; mit `bus_type: BSB` und `dest_addr: 0x00` starten |
| OTA-Update schlägt fehl | ESP32 kurz neu starten und erneut versuchen |
| Sensor zeigt `NaN` | `parameter` (Command-ID) prüfen – muss zur Heizungssteuerung passen |

---

## Weiterführende Dokumentation

- Offizielle BSB-LAN Dokumentation: https://docs.bsb-lan.de
- ESPHome Dokumentation: https://esphome.io
- GitHub-Repository: https://github.com/fredlcore/BSB-LAN
- Parameter & Command-IDs: In der Datei `BSB_LAN/BSB_LAN_defs.h` oder in der BSB-LAN Weboberfläche nachschlagen
