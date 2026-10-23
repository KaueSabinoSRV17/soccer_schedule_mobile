#!/usr/bin/env bash
# Installs pinned Linux SDKs locally. Android SDK installation accepts its licenses.
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$SOCCER_PROJECT_ROOT"
if [[ "$(uname -sm)" != 'Linux x86_64' ]]; then
  echo 'This installer targets x86_64 Linux (including Arch WSL2).' >&2
  exit 1
fi
for binary in curl git unzip tar xz sha256sum; do
  command -v "$binary" >/dev/null || { echo "Missing prerequisite: $binary" >&2; exit 1; }
done
mkdir -p .tooling/downloads
download() {
  local url="$1" archive="$2" checksum="$3"
  if [[ ! -f "$archive" ]] || ! echo "$checksum  $archive" | sha256sum --check --status; then
    curl --fail --location --retry 3 "$url" --output "$archive.part"
    echo "$checksum  $archive.part" | sha256sum --check -
    mv "$archive.part" "$archive"
  fi
}
if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  download 'https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz' \
    .tooling/downloads/flutter.tar.xz af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230
  tar -xf .tooling/downloads/flutter.tar.xz -C .tooling
fi
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  download 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9/OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz' \
    .tooling/downloads/jdk.tar.gz d7f5d5cf865a2902b70ff549b97586a7d3f234e016f041ab447ea740c7d66d1c
  mkdir -p "$JAVA_HOME"
  tar -xf .tooling/downloads/jdk.tar.gz -C "$JAVA_HOME" --strip-components=1
fi
if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
  download 'https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip' \
    .tooling/downloads/android-cli.zip 4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -q .tooling/downloads/android-cli.zip -d .tooling/downloads/android-cli
  mv .tooling/downloads/android-cli/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
fi
# yes may receive SIGPIPE when sdkmanager exits; inspect sdkmanager's exit code.
set +o pipefail
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses
license_status=${PIPESTATUS[1]}
set -o pipefail
[[ "$license_status" -eq 0 ]] || exit "$license_status"
sdkmanager --sdk_root="$ANDROID_HOME" \
  'platform-tools' 'platforms;android-34' 'platforms;android-35' 'platforms;android-36' \
  'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
flutter config --no-analytics --no-enable-linux-desktop --android-sdk "$ANDROID_HOME" --jdk-dir "$JAVA_HOME"
flutter precache --android --web
flutter pub get
if [[ ! -x .tooling/node/bin/node ]]; then
  download 'https://nodejs.org/dist/v22.23.4/node-v22.23.4-linux-x64.tar.xz' \
    .tooling/downloads/node.tar.xz 1805bcd35e6815559bd2eb97db438d3fdb0eb3a5e6a977b7c1badca76337e9ce
  mkdir -p .tooling/node
  tar -xf .tooling/downloads/node.tar.xz -C .tooling/node --strip-components=1
fi
echo 'Ready. In each development terminal: source scripts/env.sh' 

