#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
printf 'Flutter: %s\nADB: %s\nJava: %s\n' "$(command -v flutter)" "$(command -v adb)" "$(command -v java)"
doctor_result=0
flutter doctor -v || doctor_result=$?
adb devices -l
exit "$doctor_result"

