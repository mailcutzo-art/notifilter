# Notifilter

Android-first, offline notification monitoring with **High / Normal / Low** priorities. Flutter UI; native Kotlin listener and classification; SQLite metadata history. No backend or Internet permission in release builds. Debug builds permit the Flutter development VM service.

## Current implementation

Functional source paths: progressive onboarding, actual permission queries/settings links, native listener independent of Flutter, non-interactive gating via `PowerManager`, bounded single-worker processing, update deduplication, stale-result rejection, protected system categories, app rules, safe fallback, metadata history/retention/deletion, dashboard, app monitoring preferences and local simulation lab. Light/dark Material 3 UI uses platform channels. Original notifications are never cancelled, edited, or re-alerted.

**Incomplete:** neural inference, trained assets, model lifecycle/timeout management, user-editable phrase/channel/time/conversation rules, feedback dataset collection, scheduled quiet hours, and Intelligent Quiet Mode/companion alerts. The model interface and reproducible training/evaluation/export code exist; no model is installed or invoked by the app. Low is assigned only by explicit user rules today. Deterministic safety phrases can raise priority; they are not a substitute for semantic AI. No fabricated confidence, accuracy or statistics.

**Requires device verification:** installation/opening, real listener delivery with UI closed, access revocation/reconnection, screen transitions, Doze/OEM behavior, privacy redaction, and background resource use. No Android device has been tested. Quiet Mode deliberately cannot be enabled: monitoring remains the safe fallback until important-alert delivery and override behavior are verified. The inactive condition-provider service does not implement an operational quiet mode.

## Build and run

Use Flutter 3.47.8 (Dart bundled), JDK 21, Android SDK 36 and build-tools 35.0.0. Kotlin 2.2.20, AGP 8.11.1, Gradle 8.14.3. Android min/target SDK: 26/36.

In the prepared cloud environment:

```sh
cd /workspace/notifilter
source scripts/cloud-env.sh
python3 scripts/configure-java-proxy.py
bash scripts/setup-debug-key.sh
flutter --suppress-analytics pub get --enforce-lockfile
flutter --suppress-analytics analyze
flutter --suppress-analytics test
(cd android && ./gradlew testReleaseUnitTest)
flutter --suppress-analytics build apk --release
```

On another machine, install those SDKs, add Flutter to PATH, create ignored `android/local.properties` with `flutter.sdk` and `sdk.dir`, and run the commands without sourcing cloud-env.sh. The Gradle wrapper downloads its pinned distribution. Configure any required corporate proxy through your local Gradle user settings, preserving TLS verification.

Attach an authorized Android device, then `flutter run` or build a debug APK with `flutter build apk --debug`, then `adb install build/app/outputs/flutter-apk/app-debug.apk`. The cloud debug key is for development only. Release builds are unsigned until you configure private release signing: do not publish an unsigned build. Never commit a keystore or signing passwords. Follow the generated package metadata when locating APKs. The app requests notification access only after explaining implications; enable monitoring yourself. Default classification happens only while non-interactive; enable always-on in the test lab for foreground development.

## Rule and privacy behavior

System protection precedes user rules, then safety phrases, model (currently unavailable), and Normal fallback. Protected calls/alarms/ongoing system events cannot be lowered by app rules. Explicit per-app rules may choose High, Normal or Low. Conflicting core rules preserve High first. Bodies/titles/senders/notification keys stay transient and are never written to SQLite or logs. Metadata retention is 7 days by default (1/7/30 configurable), capped at 2,000 records; the UI shows the latest 500 and reports counts from retained records. Disabling history deletes it. Disabling processing preserves original Android delivery. App backup is disabled. No raw-content opt-in is exposed because encrypted content storage is not implemented.

See [platform audit](docs/ANDROID.md), [model workflow](docs/MODEL.md), [device validation](docs/VALIDATION.md), and [implementation record](docs/IMPLEMENTATION.md).

## Prepared local test artifact

`build/app/outputs/flutter-apk/notifilter-local-test.apk` is a development-signed copy of the release build, for local testing only. Its signature and packaged permissions were verified; it has no INTERNET permission. It has not been installed on a device. The original `app-release.apk` remains unsigned. The debug APK supports Flutter development tooling.
