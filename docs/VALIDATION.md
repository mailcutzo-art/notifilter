# Validation and release gates

## Automated commands

See README. Kotlin tests exercise the production platform-independent Engine and Deduplicator. Flutter widget test mocks only the platform boundary to verify actual dashboard state and the three priority labels. Python tests verify dataset leakage rejection. These do not validate Android service lifecycle.

## Device matrix (all unverified)

Run on API 26, 33, 35 and 36 including budget, mid-range and recent devices. Record OS/build, model, battery mode, permissions and exact app build. Do not infer device readiness from successful compilation.

1. Install/open; grant/deny/revoke listener access and return from settings. Status must reflect Android. Enable monitoring. Close UI, send notifications from a separate test application. Verify retained metadata and Normal fallback for missing/redacted text.
2. Send identical updates, changed updates, grouped/messaging notifications, ongoing services/media/calls/alarms and a burst of 500 notifications. Ensure bounded queue/cache, no loops and no original deletion. Remove/update while queued; obsolete results must not be applied. Force-stop behavior must not be described as continuous monitoring.
3. Verify interactive gating, screen transition races, Doze, Battery Saver, restart and process recreation. Grant/revoke policy and posting permissions independently. The present release must never activate DND or emit companion alerts.
4. App High/Normal/Low preferences and monitoring-off switches must persist. Protected events override Low. Metadata-disable/delete/retention work after reopening. Confirm no title/body/raw key exists in DB/backups/logcat. Test RTL, large fonts, screen reader, dark mode, and permission-setting return paths.
5. Future Quiet Mode gate: activate/deactivate only owned rule with explicit consent; respect pre-existing rules/user manual overrides; verify alarm/call exceptions; test bypass disabled, combined DND, silent originals, locked screen privacy, duplicate prevention, missing-model fail-safe, process death/reboot/revocation. If important alert delivery cannot be verified, stay in monitoring.

## Benchmark protocol

Use a separate fixture sender and label synthetic content. Capture cold initialization separately, then ≥1,000 warm events. Record P50/P95/P99 end-to-end, rule-only and model inference durations, queue drops and throughput. Current UI diagnostics are rule evaluation samples from retained history only.

Capture `adb shell dumpsys meminfo art.mailcutzo.notifilter` with UI closed, first with model absent and then loaded under identical workloads. Report total process PSS/RSS and incremental classifier peak separately, not model file size. Capture Perfetto CPU and `dumpsys batterystats` idle/burst workloads over repeatable durations. Measure installation size with APK analyzer. No performance target has been proven.

## Release

Configure private signing, run release build/tests, inspect merged manifest and APK using Android SDK `apkanalyzer manifest permissions` or `aapt dump permissions`, ensure no INTERNET or unwanted permissions are introduced. Review current Play user-data/notification-access policies, data safety disclosures and licenses. All hardware, Play policy and production signing gates remain open until recorded evidence exists.
