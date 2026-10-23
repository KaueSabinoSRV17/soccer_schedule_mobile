#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$SOCCER_PROJECT_ROOT"
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

