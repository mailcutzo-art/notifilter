# Android public API audit

Audited against Android 15 AOSP `NotificationManager.java` and `NotificationListenerService.java` (android-15.0.0_r1) during implementation. Public API source was downloaded and examined; this is source review, not device verification.

- [NotificationListenerService](https://developer.android.com/reference/android/service/notification/NotificationListenerService) receives posted notifications. It is not an interception hook. Cancellation is user dismissal and cannot undo initial sound/vibration. This application never cancels originals.
- Notification channels belong to their creating app. No attempt is made to edit another app's channel.
- [NotificationManager](https://developer.android.com/reference/android/app/NotificationManager#setInterruptionFilter(int)) documents that target 35+ calls activate/deactivate an app-associated AutomaticZenRule rather than changing global interruption state directly. Policy access is explicit.
- App-owned [AutomaticZenRule](https://developer.android.com/reference/android/app/AutomaticZenRule) conditions can be delivered through ConditionProviderService; `setAutomaticZenRuleState` is also public. Ownership, permissions, version guards and user override semantics need device validation. Combining rules can impose a stricter effective policy.
- A bypass-DND channel is not proof of audible delivery. User permission, channel configuration, global effective policy, silent originals and duplicate updates must all be checked before any companion alert. Calls and alarms require preservation independently of text.
- Android 15 sensitive/OTP content can be redacted. Empty content falls back to Normal, and no attempt is made to bypass redaction.
- Background listener execution depends on Android binding, profiles, low-RAM/OEM restrictions, and user access. No permanent foreground service or battery exemption is used.

## Permission inventory

Notification listener binding permission protects the exported service; users explicitly grant special notification access in settings. POST_NOTIFICATIONS is optional for future app-owned alerts, not monitoring. ACCESS_NOTIFICATION_POLICY is optional and does not activate anything. The condition provider is protected by BIND_CONDITION_PROVIDER_SERVICE. No INTERNET, accessibility, contacts, SMS, broad package query or wake-lock permission is declared. Both merged release manifest and packaged release APK were audited: only POST_NOTIFICATIONS, ACCESS_NOTIFICATION_POLICY and an app-scoped AndroidX signature permission are present. Debug alone adds INTERNET for the Flutter VM service.

## Quiet Mode release gate

Mode A is implemented. Mode B is unavailable, with clear UI explanation. The condition provider always publishes inactive. The app neither writes unrelated DND rules nor changes global policy. Before implementing activation: explicit consent, app-owned rule creation, screen-driven condition updates, deactivation on disable/revoke/disconnect, process/reboot recovery, and explicit user overrides must pass the validation matrix. Never use a persistent “verified=true” preference as a substitute for actual alert capability checks. Monitoring is the fallback.
