package art.mailcutzo.notifilter

import android.Manifest
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private lateinit var store: Store
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        store = Store(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "notifilter/native").setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            if (call.method == "openAccess") {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null)
            } else if (call.method == "openPolicy") {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)); result.success(null)
            } else if (call.method == "requestPosting") {
                if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 42)
                result.success(null)
            } else worker.execute {
                try {
                    val response: Any? = when(call.method) {
                        "state" -> state()
                        "history" -> store.history()
                        "rules" -> store.rules().map { mapOf("pkg" to it.pkg, "priority" to it.priority?.name, "enabled" to it.enabled) }
                        "setting" -> {
                            val key = args["key"] as String
                            require(key in setOf("enabled", "always", "history", "onboarded"))
                            store.prefs.edit().putBoolean(key, args["value"] as Boolean).commit()
                            if (key == "history" && args["value"] == false) store.clear()
                            state()
                        }
                        "retention" -> {
                            val days = (args["days"] as Number).toInt(); require(days in 1..30)
                            store.prefs.edit().putInt("retention", days).commit(); store.prune(); state()
                        }
                        "rule" -> { store.rule(args["pkg"] as String, args["priority"] as String?, args["enabled"] as? Boolean ?: true); null }
                        "clear" -> { store.clear(); null }
                        "classify" -> Engine().classify(Event("lab", args["pkg"] as? String ?: "lab", text = (args["text"] as String).take(2048)), store.rules()).map()
                        "quiet" -> throw UnsupportedOperationException("Quiet Mode is unavailable until priority delivery and user overrides pass real-device validation. Monitoring remains available.")
                        else -> throw IllegalArgumentException("Unknown operation")
                    }
                    runOnUiThread { result.success(response) }
                } catch (e: Exception) { runOnUiThread { result.error("OPERATION_FAILED", e.message, null) } }
            }
        }
    }
    private fun state(): Map<String, Any?> {
        val component = ComponentName(this, NotificationListener::class.java).flattenToString()
        val access = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")?.split(":")?.contains(component) == true
        val rows = store.history()
        val today = java.util.Calendar.getInstance().apply { set(java.util.Calendar.HOUR_OF_DAY,0); set(java.util.Calendar.MINUTE,0); set(java.util.Calendar.SECOND,0); set(java.util.Calendar.MILLISECOND,0) }.timeInMillis
        val day = rows.filter { (it["at"] as Long) >= today }
        val latencies = rows.map { it["micros"] as Long }.sorted()
        fun percentile(p: Double): Long? = if (latencies.isEmpty()) null else latencies[(kotlin.math.ceil(p * latencies.size).toInt() - 1).coerceAtLeast(0)]
        return mapOf("access" to access, "connected" to (access && NotificationListener.connected),
            "posting" to (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED),
            "policy" to getSystemService(NotificationManager::class.java).isNotificationPolicyAccessGranted,
            "interactive" to getSystemService(PowerManager::class.java).isInteractive,
            "enabled" to store.prefs.getBoolean("enabled", false), "always" to store.prefs.getBoolean("always", false),
            "history" to store.prefs.getBoolean("history", true), "onboarded" to store.prefs.getBoolean("onboarded", false),
            "retention" to store.prefs.getInt("retention",7), "analyzed" to day.size,
            "high" to day.count { it["priority"] == "HIGH" }, "low" to day.count { it["priority"] == "LOW" },
            "quieted" to 0, "alerts" to 0, "mode" to "MONITORING", "model" to "Not installed — safe rules active",
            "p50" to percentile(0.50), "p95" to percentile(0.95), "p99" to percentile(0.99), "samples" to rows.size, "processingFailures" to NotificationListener.processingFailures.get(), "queueDrops" to NotificationListener.queueDrops.get())
    }
    override fun onDestroy() { worker.shutdown(); super.onDestroy() }
}
