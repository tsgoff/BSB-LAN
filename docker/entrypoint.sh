#!/usr/bin/env bash
set -euo pipefail

cd /workspace

CUSTOM_DEFS="${CUSTOM_DEFS:-/custom/BSB_LAN_custom_defs.h}"
CUSTOM_CONFIG="${CUSTOM_CONFIG:-/custom/BSB_LAN_config.h}"
OUT_DIR="${OUT_DIR:-/out}"

mkdir -p "$OUT_DIR/bin" "$OUT_DIR/manifests"

if [ -f "$CUSTOM_DEFS" ]; then
  echo "Using custom defs: $CUSTOM_DEFS"
  cp "$CUSTOM_DEFS" BSB_LAN/BSB_LAN_custom_defs.h
else
  echo "No custom defs mounted at $CUSTOM_DEFS -- using generic BSB_LAN_custom_defs.h.default"
  cp BSB_LAN/BSB_LAN_custom_defs.h.default BSB_LAN/BSB_LAN_custom_defs.h
fi

if [ -f "$CUSTOM_CONFIG" ]; then
  echo "Using custom config: $CUSTOM_CONFIG"
  cp "$CUSTOM_CONFIG" BSB_LAN/BSB_LAN_config.h
else
  echo "No custom config mounted at $CUSTOM_CONFIG -- using generic BSB_LAN_config.h.default"
  cp BSB_LAN/BSB_LAN_config.h.default BSB_LAN/BSB_LAN_config.h
fi

# Fixed flash offsets for Arduino-ESP32
OFF_BOOT=0x1000
OFF_PART=0x8000
OFF_BOOTAPP0=0xE000
OFF_APP0=0x10000

BOOTAPP0=$(echo /root/.arduino15/packages/esp32/hardware/esp32/*/tools/partitions/boot_app0.bin)
test -f "$BOOTAPP0"

build_one () {
  local name="$1"
  local fqbn="$2"
  local board_opts="$3"      # can be empty
  local flash_size="$4"      # 4MB / 16MB
  local extra_props="${5:-}" # optional extra compile args

  local out_bin="bsb-lan-${name}-merged.bin"
  local out_manifest="bsb-lan-${name}.json"

  echo ""
  echo "============================================================"
  echo "Building: ${name}"
  echo "  FQBN:    ${fqbn}"
  echo "  Options: ${board_opts:-<none>}"
  echo "  Extra:   ${extra_props:-<none>}"
  echo "============================================================"

  mkdir -p "build/${name}"

  local -a ARGS
  ARGS=(
    --fqbn "${fqbn}"
    --libraries BSB_LAN/libraries
    --build-path "build/${name}"
    --export-binaries
    BSB_LAN
  )

  if [ -n "${board_opts}" ]; then
    ARGS=(--board-options "${board_opts}" "${ARGS[@]}")
  fi

  if [ -n "${extra_props}" ]; then
    local -a EXTRA_ARR=(${extra_props})
    ARGS=("${EXTRA_ARR[@]}" "${ARGS[@]}")
  fi

  arduino-cli compile "${ARGS[@]}"

  local BUILD="build/${name}"
  local BOOTLOADER="${BUILD}/BSB_LAN.ino.bootloader.bin"
  local PARTITIONS="${BUILD}/BSB_LAN.ino.partitions.bin"
  local APPBIN="${BUILD}/BSB_LAN.ino.bin"

  test -f "$BOOTLOADER"
  test -f "$PARTITIONS"
  test -f "$APPBIN"

  python3 -m esptool --chip esp32 merge-bin -o "${OUT_DIR}/bin/${out_bin}" \
    --flash-mode dio --flash-size "${flash_size}" \
    "${OFF_BOOT}"     "$BOOTLOADER" \
    "${OFF_PART}"     "$PARTITIONS" \
    "${OFF_BOOTAPP0}" "$BOOTAPP0" \
    "${OFF_APP0}"     "$APPBIN"

  cat > "${OUT_DIR}/manifests/${out_manifest}" <<JSON
{
  "name": "BSB-LAN (${name})",
  "version": "custom",
  "builds": [
    { "chipFamily": "ESP32", "parts": [ { "path": "../bin/${out_bin}", "offset": 0 } ] }
  ]
}
JSON

  echo "Done: ${OUT_DIR}/bin/${out_bin}"
}

build_board () {
  case "$1" in
    esp32-devkit)
      build_one "esp32-devkit" "esp32:esp32:esp32" "PartitionScheme=min_spiffs" "4MB"
      ;;
    esp32-evb)
      build_one "esp32-evb" "esp32:esp32:esp32-evb" "PartitionScheme=min_spiffs" "4MB"
      ;;
    esp32-poe-iso)
      build_one "esp32-poe-iso" "esp32:esp32:esp32-poe-iso" "PartitionScheme=min_spiffs" "4MB"
      ;;
    esp32-poe-iso-16mb)
      build_one "esp32-poe-iso-16mb" "esp32:esp32:esp32-poe-iso" "" "16MB" \
        "--build-property build.partitions=default_16MB --build-property upload.maximum_size=6553600 --build-property compiler.cpp.extra_flags=-DCUSTOM_PARTITION_TABLE"
      ;;
    *)
      echo "Unknown board '$1'. Valid: esp32-devkit, esp32-evb, esp32-poe-iso, esp32-poe-iso-16mb, all" >&2
      exit 1
      ;;
  esac
}

if [ "$#" -eq 0 ]; then
  set -- "esp32-devkit"
fi

if [ "$1" = "all" ]; then
  for b in esp32-devkit esp32-evb esp32-poe-iso esp32-poe-iso-16mb; do
    build_board "$b"
  done
else
  for b in "$@"; do
    build_board "$b"
  done
fi

echo ""
echo "All requested builds finished. Output in ${OUT_DIR}:"
ls -lh "${OUT_DIR}/bin"
