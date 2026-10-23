#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
if [[ $# -ne 1 && $# -ne 2 ]]; then
  echo "Usage: bash scripts/connect-phone.sh PHONE_IP:DEBUG_PORT [PHONE_IP:PAIRING_PORT]" >&2
  echo 'Find both ports in Android Settings > Developer options > Wireless debugging.' >&2
  exit 1
fi
if [[ $# -eq 2 ]]; then
  adb pair "$2"
fi
adb connect "$1"
adb devices -l
flutter devices

