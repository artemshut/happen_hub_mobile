#!/usr/bin/env bash
set -euo pipefail

# Capture example screenshots from a connected Android device/emulator.
# Produces PNGs under store/play/screenshots/.

OUT="$(dirname "$0")/../store/play/screenshots"
mkdir -p "$OUT"

echo "Connected devices:" && adb devices || true

# Example captures (adjust navigation to relevant screens before running):
adb exec-out screencap -p > "$OUT/phone-01.png"
sleep 1
adb exec-out screencap -p > "$OUT/phone-02.png"

echo "Saved screenshots to $OUT (original device resolution)."
echo "Upload directly to Play Console, or resize to 1080x1920 (portrait) if desired."

