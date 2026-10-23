#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$SOCCER_PROJECT_ROOT"
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 "$@"

