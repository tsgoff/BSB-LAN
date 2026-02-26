#!/usr/bin/env bash
# =============================================================================
# BSB-LAN ESPHome Docker Build Script
# =============================================================================
# Baut die ESPHome-Firmware für BSB-LAN in einem Docker-Container,
# analog zur GitHub Actions CI-Pipeline.
#
# Verwendung:
#   ./build_esphome.sh [YAML-Datei] [ESPHome-Version]
#
# Beispiele:
#   ./build_esphome.sh
#   ./build_esphome.sh example_esphome.yaml
#   ./build_esphome.sh example_esphome.yaml 2026.2.2
#   ./build_esphome.sh example_esphome.yaml latest
# =============================================================================

# Ausführbar machen falls nötig: chmod +x build_esphome.sh
set -euo pipefail

# --------------------------------------------------------------------------
# Konfiguration
# --------------------------------------------------------------------------
YAML_FILE="${1:-example_esphome.yaml}"
ESPHOME_VERSION="${2:-latest}"
DOCKER_IMAGE="ghcr.io/esphome/esphome:${ESPHOME_VERSION}"
BUILD_OUTPUT_DIR="$(pwd)/build_output"
SECRETS_FILE="secrets.yaml"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------------------------------------------------
# Farben für Terminal-Ausgabe
# --------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# --------------------------------------------------------------------------
# Voraussetzungen prüfen
# --------------------------------------------------------------------------
check_requirements() {
    log_info "Prüfe Voraussetzungen..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker ist nicht installiert oder nicht im PATH."
        log_error "Installiere Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker-Daemon läuft nicht. Bitte Docker starten."
        exit 1
    fi

    log_success "Docker gefunden: $(docker --version)"
}

# --------------------------------------------------------------------------
# YAML-Datei prüfen
# --------------------------------------------------------------------------
check_yaml() {
    if [[ ! -f "${REPO_ROOT}/${YAML_FILE}" ]]; then
        log_error "YAML-Datei nicht gefunden: ${REPO_ROOT}/${YAML_FILE}"
        log_info  "Verfügbare YAML-Dateien:"
        find "${REPO_ROOT}" -maxdepth 1 -name "*.yaml" -o -name "*.yml" | sed 's/^/  /'
        exit 1
    fi
    log_success "YAML-Datei gefunden: ${YAML_FILE}"
}

# --------------------------------------------------------------------------
# secrets.yaml erstellen (falls nicht vorhanden)
# --------------------------------------------------------------------------
create_secrets() {
    if [[ -f "${REPO_ROOT}/${SECRETS_FILE}" ]]; then
        log_warn "secrets.yaml existiert bereits – wird nicht überschrieben."
        log_warn "Stelle sicher, dass die Datei NICHT in git committed wird!"
        return
    fi

    log_info "Erstelle dummy secrets.yaml..."
    cat > "${REPO_ROOT}/${SECRETS_FILE}" <<EOF
# BSB-LAN ESPHome Secrets
# ACHTUNG: Diese Datei enthält sensible Daten!
# Sie ist in .gitignore eingetragen und sollte NICHT committed werden.

wifi_ssid: "DeinNetzwerkName"
wifi_password: "DeinNetzwerkPasswort"
ota_password: "DeinOTAPasswort"
api_encryption_key: "MTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTI="
EOF
    log_success "secrets.yaml erstellt."
    log_warn "Bitte secrets.yaml mit deinen echten Zugangsdaten befüllen!"

    # secrets.yaml zur .gitignore hinzufügen falls noch nicht vorhanden
    if [[ -f "${REPO_ROOT}/.gitignore" ]]; then
        if ! grep -q "secrets.yaml" "${REPO_ROOT}/.gitignore"; then
            echo "secrets.yaml" >> "${REPO_ROOT}/.gitignore"
            log_info "secrets.yaml zu .gitignore hinzugefügt."
        fi
    else
        echo "secrets.yaml" > "${REPO_ROOT}/.gitignore"
        log_info ".gitignore erstellt mit secrets.yaml."
    fi
}

# --------------------------------------------------------------------------
# Output-Verzeichnis vorbereiten
# --------------------------------------------------------------------------
prepare_output() {
    mkdir -p "${BUILD_OUTPUT_DIR}"
    log_success "Build-Output-Verzeichnis: ${BUILD_OUTPUT_DIR}"
}

# --------------------------------------------------------------------------
# Docker Image pullen
# --------------------------------------------------------------------------
pull_image() {
    log_info "Lade ESPHome Docker-Image: ${DOCKER_IMAGE}"
    docker pull "${DOCKER_IMAGE}"
    log_success "Docker-Image bereit."
}

# --------------------------------------------------------------------------
# Komponentenstruktur sicherstellen (src/ → Komponentenordner)
# --------------------------------------------------------------------------
fix_component_structure() {
    local component_dir="${REPO_ROOT}/external_components/bsb_lan"
    local src_dir="${component_dir}/src"

    if [[ ! -d "${src_dir}" ]]; then
        return  # Kein src/ Verzeichnis – nichts zu tun
    fi

    local needs_copy=false
    for file in "${src_dir}"/*.h "${src_dir}"/*.cpp; do
        [[ -f "${file}" ]] || continue
        filename="$(basename "${file}")"
        if [[ ! -f "${component_dir}/${filename}" ]]; then
            needs_copy=true
            break
        fi
    done

    if [[ "${needs_copy}" == true ]]; then
        log_info "Korrigiere Komponentenstruktur (src/ → Komponentenordner)..."
        for file in "${src_dir}"/*.h "${src_dir}"/*.cpp; do
            [[ -f "${file}" ]] || continue
            cp "${file}" "${component_dir}/"
        done
        log_success "Komponentenstruktur korrigiert."

        # Build-Cache leeren da Struktur geändert
        if [[ -d "${REPO_ROOT}/.esphome/build" ]]; then
            rm -rf "${REPO_ROOT}/.esphome/build"/*
            log_info "Build-Cache nach Struktur-Fix geleert."
        fi
    else
        log_success "Komponentenstruktur OK."
    fi
}

# --------------------------------------------------------------------------
# ESPHome Build ausführen
# --------------------------------------------------------------------------
run_build() {
    log_info "Starte ESPHome Build..."
    log_info "  YAML:    ${YAML_FILE}"
    log_info "  Version: ${ESPHOME_VERSION}"
    log_info "  Output:  ${BUILD_OUTPUT_DIR}"
    echo ""

    docker run --rm \
        --name "bsb-lan-esphome-build" \
        -v "${REPO_ROOT}:/config" \
        -v "${BUILD_OUTPUT_DIR}:/build_output" \
        -w /config \
        "${DOCKER_IMAGE}" \
        compile "/config/${YAML_FILE}"

    echo ""
    log_success "Build erfolgreich abgeschlossen!"
}

# --------------------------------------------------------------------------
# Firmware-Dateien kopieren
# --------------------------------------------------------------------------
copy_firmware() {
    # Ermittle den Projektnamen aus der YAML (name-Feld)
    local project_name
    project_name=$(grep -E "^  name:" "${REPO_ROOT}/${YAML_FILE}" | head -1 | awk '{print $2}' | tr -d '"')

    local firmware_src="${REPO_ROOT}/.esphome/build/${project_name}/.pioenvs/${project_name}"

    if [[ -d "${firmware_src}" ]]; then
        log_info "Kopiere Firmware-Dateien nach ${BUILD_OUTPUT_DIR}..."

        # Firmware-Binary suchen und kopieren
        find "${firmware_src}" -name "firmware.bin" -o -name "firmware-factory.bin" 2>/dev/null | while read -r bin_file; do
            cp "${bin_file}" "${BUILD_OUTPUT_DIR}/"
            log_success "Firmware kopiert: $(basename "${bin_file}")"
        done
    else
        log_warn "Firmware-Verzeichnis nicht gefunden: ${firmware_src}"
        log_warn "Firmware liegt im .esphome/build Verzeichnis."
    fi
}

# --------------------------------------------------------------------------
# Zusammenfassung
# --------------------------------------------------------------------------
print_summary() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  BSB-LAN ESPHome Build – Abgeschlossen    ${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    log_info "Firmware-Dateien:"

    # Alle .bin Dateien im Output anzeigen
    if find "${BUILD_OUTPUT_DIR}" -name "*.bin" 2>/dev/null | grep -q .; then
        find "${BUILD_OUTPUT_DIR}" -name "*.bin" | while read -r f; do
            echo "  → ${f}"
        done
    else
        log_info "  → Firmware liegt unter: ${REPO_ROOT}/.esphome/build/"
    fi

    echo ""
    log_info "Nächste Schritte:"
    echo "  1. Firmware über ESPHome-CLI flashen:"
    echo "     esphome run ${YAML_FILE}"
    echo ""
    echo "  2. Oder manuell via esptool.py flashen:"
    echo "     esptool.py --port /dev/ttyUSB0 write_flash 0x0 firmware.bin"
    echo ""
    echo "  3. OTA-Update (nach erstem Flash per USB):"
    echo "     esphome upload ${YAML_FILE}"
    echo ""
}

# --------------------------------------------------------------------------
# Hilfe anzeigen
# --------------------------------------------------------------------------
print_help() {
    echo "BSB-LAN ESPHome Docker Build Script"
    echo ""
    echo "Verwendung:"
    echo "  $(basename "$0") [YAML-Datei] [ESPHome-Version]"
    echo ""
    echo "Argumente:"
    echo "  YAML-Datei       ESPHome YAML-Konfiguration (Standard: example_esphome.yaml)"
    echo "  ESPHome-Version  Docker-Image-Tag            (Standard: latest)"
    echo ""
    echo "Beispiele:"
    echo "  $(basename "$0")"
    echo "  $(basename "$0") example_esphome.yaml"
    echo "  $(basename "$0") meine-heizung.yaml 2026.2.2"
    echo "  $(basename "$0") example_esphome.yaml latest"
    echo ""
    echo "Voraussetzungen:"
    echo "  - Docker installiert und gestartet"
    echo "  - ESPHome YAML-Datei vorhanden"
    echo ""
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
main() {
    # Hilfe anzeigen
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        print_help
        exit 0
    fi

    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  BSB-LAN ESPHome Docker Build             ${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    cd "${REPO_ROOT}"

    check_requirements
    check_yaml
    create_secrets
    fix_component_structure
    prepare_output
    pull_image
    run_build
    copy_firmware
    print_summary
}

main "$@"
