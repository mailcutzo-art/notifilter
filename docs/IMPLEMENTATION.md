# Implementation record

The repository was empty/unborn. All application files are new. The agreed output priorities are exactly High, Normal and Low.

## Files and decisions

- `lib/main.dart`: Flutter Material 3 application; onboarding, dashboard, metadata history/filtering, app rules, test lab/model status, privacy/permission controls. Native settings are authoritative; resume refreshes permission state.
- `android/app/src/main/kotlin/art/mailcutzo/notifilter/Engine.kt`: platform-independent rule/model interface and conservative orchestration; bounded deduplication. No model is installed. Rule confidence is null.
- `NotificationListener.kt`: Android-managed listener with one background worker/64 pending work items, 512-entry TTL cache, content revisions/removal checks, loop/group exclusions, protected ongoing categories, and overload fail-open behavior. No Flutter engine starts in this path. Error/drop counters contain no payloads.
- `Store.kt`: Android SQLite metadata history with WAL for native/UI concurrency, indexed timestamp, capped retention, shared native preferences, per-package rules. No message text or raw notification keys written to disk. Schema version 1 rejects unsupported upgrades rather than destructive reset.
- `MainActivity.kt`: platform bridge with serialized database work, actual permission/device-state queries, lab classification and persistence. Quiet activation is explicitly rejected.
- `QuietConditionProvider.kt`: inactive-only compatibility boundary; not an implemented quiet controller. API 36 marks this legacy path deprecated. Modern app-owned rule activation needs a separately validated implementation.
- Android manifests/resources/Gradle wrapper/build files, Dart manifests/lockfile, `scripts/cloud-env.sh`: build/runtime configuration. Java proxy refresh and debug-key helpers prepare this cloud snapshot without embedding credentials; the Temurin JDK 21.0.13 archive checksum was verified before extraction. The Gradle 8.14.3 distribution checksum was verified against its official published SHA256 and pinned.
- Kotlin `EngineTest.kt`, Flutter `widget_test.dart`, Python `ml/test_schema.py`: safety/precedence/fallback/dedup, UI platform-boundary and dataset integrity checks.
- `ml/pipeline.py`, `ml/requirements.txt`: actual CPU training/baseline/ONNX export/quantization/evaluation workflow, not yet trained or deployed. Requires licensed data and Android tokenizer/runtime integration.
- README and docs: limitations, model delivery, release/device checks and this record.

Dependencies: Flutter SDK/material/widgets/services; flutter_lints 6.x for development; Kotlin/Android standard library and Flutter embedding; JUnit 4.13.2 for tests. SQLite uses platform APIs. No Riverpod, Room, analytics or runtime ML dependency was added; this minimizes dependencies until trained inference can be integrated and validated. Research Python dependencies are pinned separately and not installed in the application.

## Verified so far

- Flutter 3.47.8 SDK, Android API 36 compile SDK and NDK 27 toolchain prepared under `/workspace/toolchains`.
- Flutter frozen dependency installation passed.
- `flutter analyze`: no issues.
- `flutter test`: 1 widget test passed.
- Kotlin production Engine/Deduplicator compiled with Kotlin 2.1.0 standalone compiler; JUnit: 21 tests passed. Gradle uses Kotlin 2.2.20.
- All five native Kotlin source files compiled against actual Android 36 and Flutter embedding jars (warnings for deprecated legacy provider/Bundle API). A missing lifecycle method found by this check was fixed.
- Python dataset validation and synthetic baseline pipeline smoke: 5 tests passed. This verifies workflow mechanics, not model quality. Python scripts compile.
- Base model API metadata inspected: MIT model-card tag, immutable revision recorded in MODEL.md. No weights acquired or accuracy claimed.

Gradle testReleaseUnitTest passed: 21 tests, zero failures/errors/skips. Merged release manifest audit passed: only POST_NOTIFICATIONS, ACCESS_NOTIFICATION_POLICY, and an AndroidX app-scoped signature permission. No INTERNET permission. Full release packaging results follow below. Hardware testing, Android installation, background memory, battery, cold and warm end-to-end latency are unverified. UI diagnostics measure only rule-evaluation duration from real retained metadata; no host timing is presented as a device benchmark.

## Open acceptance conditions

This is a monitoring MVP, not the complete master specification. Remaining work: real trained model and Android inference/tokenizer lifecycle/timeouts, operational device-verified quiet mode/priority companion alerts, fine-grained rule editing, feedback collection, schedules, encrypted opt-in content storage if offered, Android instrumentation/device matrix, release signing and Play policy review. No required missing feature is represented by fake production results. The safe monitoring path leaves ordinary Android delivery intact.

## Saved environment configuration

Saved install_script and start_skill, plus custom network destinations: storage.googleapis.com, developer.android.com, huggingface.co, hf.co, cas-bridge.xethub.hf.co. The draft is persisted, not published. Review/save environment settings and publish when appropriate. No new credentials or secret values are required for monitoring development. Future model training needs legally usable data, not a cloud inference key.

## Build artifacts

`flutter build apk --release` succeeded: 49,640,608-byte universal APK, min SDK 26/target SDK 36. `aapt dump permissions` verified the packaged release has no INTERNET permission. `apksigner verify` confirms this artifact is unsigned (expected); it cannot be installed until signed. No production signing identity was invented. The debug variant enables INTERNET solely for Flutter development tooling; release remains offline by manifest.

The signed debug APK also built successfully; Android apksigner verified its v2 signature. A final sequential rebuild keeps packaged outputs aligned with the final source. A separate development-signed release copy is provided for local testing only; production signing remains unconfigured. No hardware test has run. ADB device discovery in this host was blocked by its read-only home configuration directory, and no device/emulator is supplied.

Final local-test release copy passed apksigner v2/v3 verification and packaged-permission audit (no INTERNET). Debug APK includes only the intended development networking permission in addition to the audited release permissions.
