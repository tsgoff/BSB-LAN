#!/usr/bin/env bash
# =============================================================================
# BSB-LAN ESPHome Komponenten-Struktur Fix
# =============================================================================
# ESPHome erwartet alle C++ Quelldateien einer external_component direkt im
# Komponentenordner (nicht in einem src/ Unterordner). Dieses Script:
#   1. Kopiert alle .h/.cpp Dateien aus external_components/bsb_lan/src/
#      direkt nach external_components/bsb_lan/
#   2. Leert den ESPHome Build-Cache (.esphome/build/)
#
# Verwendung:
#   ./fix_esphome_component.sh
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="${REPO_ROOT}/external_components/bsb_lan"
SRC_DIR="${COMPONENT_DIR}/src"
BUILD_CACHE="${REPO_ROOT}/.esphome/build"

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  BSB-LAN ESPHome Component Fix            ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# --------------------------------------------------------------------------
# 1. Prüfen ob src/ Verzeichnis existiert
# --------------------------------------------------------------------------
if [[ ! -d "${SRC_DIR}" ]]; then
    log_error "src/ Verzeichnis nicht gefunden: ${SRC_DIR}"
    exit 1
fi

# --------------------------------------------------------------------------
# 2. C++ Dateien aus src/ in den Komponentenordner kopieren
# --------------------------------------------------------------------------
log_info "Kopiere C++ Dateien aus src/ nach ${COMPONENT_DIR}/"

COPIED=0
for file in "${SRC_DIR}"/*.h "${SRC_DIR}"/*.cpp; do
    [[ -f "${file}" ]] || continue
    filename="$(basename "${file}")"
    dest="${COMPONENT_DIR}/${filename}"

    if [[ -f "${dest}" ]]; then
        # Prüfen ob Datei identisch ist
        if cmp -s "${file}" "${dest}"; then
            log_warn "Bereits aktuell: ${filename} (übersprungen)"
            continue
        fi
    fi

    cp "${file}" "${dest}"
    log_success "Kopiert: ${filename}"
    COPIED=$((COPIED + 1))
done

if [[ ${COPIED} -eq 0 ]]; then
    log_info "Alle Dateien waren bereits aktuell."
else
    log_success "${COPIED} Datei(en) kopiert."
fi

# --------------------------------------------------------------------------
# 3. Includes in kopierten Dateien prüfen
#    Falls irgendwo "src/" als Pfad hardcoded ist, muss das entfernt werden.
# --------------------------------------------------------------------------
log_info "Prüfe #include Pfade..."

for file in "${COMPONENT_DIR}"/*.h "${COMPONENT_DIR}"/*.cpp; do
    [[ -f "${file}" ]] || continue
    filename="$(basename "${file}")"

    # Ersetze #include "src/xxx" durch #include "xxx" falls vorhanden
    if grep -q '"src/' "${file}" 2>/dev/null; then
        sed -i.bak 's|#include "src/|#include "|g' "${file}"
        rm -f "${file}.bak"
        log_success "Include-Pfad bereinigt in: ${filename}"
    fi
done

# --------------------------------------------------------------------------
# 4. ESPHome Build-Cache leeren
# --------------------------------------------------------------------------
if [[ -d "${BUILD_CACHE}" ]]; then
    log_info "Leere ESPHome Build-Cache: ${BUILD_CACHE}"
    rm -rf "${BUILD_CACHE:?}"/*
    log_success "Build-Cache geleert."
else
    log_info "Kein Build-Cache gefunden – nichts zu leeren."
fi

# --------------------------------------------------------------------------
# 5. Zusammenfassung und Hinweis
# --------------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Fix abgeschlossen                        ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
log_info "Neue Komponentenstruktur:"
ls -1 "${COMPONENT_DIR}"/*.h "${COMPONENT_DIR}"/*.cpp 2>/dev/null | while read -r f; do
    echo "  → $(basename "${f}")"
done
echo ""
log_info "Jetzt Build starten:"
echo "  ./build_esphome.sh"
echo ""
