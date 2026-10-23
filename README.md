# Soccer Schedule

Flutter Android app for reviewing one daily soccer analysis and choosing overlapping
matches. Kickoff reminders remain in Google Calendar.

**Default mode: offline demonstration.** Real owner-only Firebase sign-in,
Firestore reviews/submissions and FCM notifications are implemented behind explicit
live configuration. Provision them through the separate IaC repository before
running live mode; see [integration status](docs/live-integration-status.md) and
[the integration contract](docs/integration.md).

## Develop entirely in Arch WSL2

Keep this repository in the Linux filesystem, not `/mnt/c`. Linux Flutter, Android
SDK/ADB and Temurin Java live in ignored `.tooling/`; your Windows Flutter and
system Java installations are preserved. Flutter, Node.js, Java and Android command-line-tool
downloads are pinned in `scripts/setup-wsl.sh`.

```bash
# First setup on x86_64 Linux; downloads several GB and accepts Android SDK licenses.
bash scripts/setup-wsl.sh

# Every new bash/zsh terminal, from this directory:
source scripts/env.sh
flutter --version
adb version
bash scripts/doctor.sh
```

Prerequisites: `curl`, `git`, `unzip`, `tar`, `xz`, `zip` and standard Linux runtime
libraries. On Arch, use its package manager to install missing prerequisites.
No Android Studio, emulator, Windows Flutter or system-wide Java replacement is needed.
The installer includes Android APIs 34/35/36, Flutter's NDK and Android CMake; the initial APK build
also downloads Gradle and plugin dependencies.
Do not run Flutter as root. Toolchain activation is session-local; re-source the
script after opening a terminal. VS Code settings select the Linux Flutter SDK;
open the folder through **WSL**, and install the recommended Dart/Flutter extensions
in the WSL extension host.
Activation also overrides any inherited `ADB_SERVER_SOCKET` bridge with the local
Linux server at `127.0.0.1:5037`, avoiding stale Windows ADB routing.

## Preview without a phone

```bash
bash scripts/preview.sh
```

Open `http://localhost:8080` in your Windows browser. This is a Flutter web preview
of the mobile interface, not the production delivery platform. Local persistence
works in the browser; Android notification testing requires the phone. If Windows
localhost forwarding is unavailable, try the WSL IP shown by `hostname -I`.
Preview assets may require internet access.

## Connect the S23 when available

1. Enable Developer options: Settings → About phone → Software information → tap
   Build number seven times. Enable Wireless debugging under Developer options.
2. Put the PC and phone on the same network. Open **Pair device with pairing code**.
3. Run the following, substituting the phone's actual IP and ports:

```bash
# Pairing port is from the pairing dialog; debug port is on the main Wireless debugging screen.
bash scripts/connect-phone.sh 192.168.1.50:DEBUG_PORT 192.168.1.50:PAIRING_PORT
# Enter the pairing code at the prompt, not in a committed file.
source scripts/env.sh
flutter devices
flutter run -d DEVICE_ID
```

After pairing, reconnect with only the first argument. Debug ports can change.
Explicit `adb connect` avoids relying on mDNS discovery across WSL. For connection
failures, check network client isolation, VPN routing and targeted firewall rules.
USB passthrough via Windows `usbipd-win` is a fallback; it is not installed here.

On the phone, use **Testar notificação local**, grant permission, switch away and
tap the notification. Test opening from both background and a normally closed app.
Force-stopping is a separate Android state. This tests local display only. Verify actual FCM delivery after the live rollout.

## Commands

Run `source scripts/env.sh` before direct Flutter/Dart commands.

```bash
flutter pub get                       # Restore locked dependencies
dart format lib test                  # Format Dart
bash scripts/check.sh                 # Formatting, analyzer and tests
flutter test --coverage               # Unit/widget tests and coverage output
flutter build apk --debug             # Build/installable debug APK without a phone
flutter build web                     # Build browser preview
```

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`. Release signing is not
configured; the generated release configuration uses a development key and is not
ready for publishing.

## Structure and behavior

- `lib/domain/`: immutable fixture/review models, 135-minute overlap rules and explicit
  `America/Sao_Paulo` conversion, independent of device timezone.
- `lib/data/`: demo adapter, Firestore adapter and strict live review decoder. Reviews use
  tomorrow's date to keep demonstration matches selectable throughout the day.
- `lib/features/review/`: selection controller and Portuguese dark Material UI.
- `lib/features/auth/`: owner-only Google sign-in and session lifecycle.
- `lib/notifications/`: local display, FCM installation registration and tap routing.
- `test/`: overlap boundaries, chain conflicts, persistence restoration validation,
  save failures, concurrent saves and the selection-to-agenda widget workflow.
- `android/`, `web/`: platform runners; `scripts/`: repeatable WSL setup and checks.

Choose compatible matches or explicitly skip each conflict group. Non-conflicting
games appear automatically in the local agenda. In demo mode, saving does **not** update Calendar. Live mode waits for server-confirmed Calendar status.
Choices are scoped to the demo review ID and revision; reset them from the app.
Never add API secrets, Calendar credentials, signing keys or local SDKs to source control.

## Live Android mode

In the IaC repository, follow the owner-only rollout and run its public configuration
export helper with this checkout as the destination. Then:

```bash
source scripts/env.sh
flutter run -d DEVICE_ID --dart-define-from-file=.config/firebase-android.json
# Build an APK with the same live configuration:
flutter build apk --debug --dart-define-from-file=.config/firebase-android.json
```

Sign in with the configured owner Google account and grant notification permission.
An accepted daily selection is final; rejected choices can be corrected. Pending
submission status is distinct from Calendar success. Generated `.config/` and
`android/app/google-services.json` remain ignored. They contain public client
configuration; OAuth secrets and Calendar credentials stay on the server.

## Tooling references

- [Flutter installation](https://docs.flutter.dev/install/manual)
- [Android wireless debugging](https://developer.android.com/tools/adb)
- [WSL networking](https://learn.microsoft.com/windows/wsl/networking)
- [WSL USB passthrough](https://learn.microsoft.com/windows/wsl/connect-usb)

