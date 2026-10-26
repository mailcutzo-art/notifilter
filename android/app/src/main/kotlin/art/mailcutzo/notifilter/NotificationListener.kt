package art.mailcutzo.notifilter

import android.app.Notification
import android.os.PowerManager
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

class NotificationListener : NotificationListenerService() {
    companion object {
        @Volatile var connected = false; private set
        val processingFailures = AtomicLong()
        val queueDrops = AtomicLong()
    }
    private lateinit var store: Store
    private val engine = Engine()
    private val dedup = Deduplicator()
    private val pending = ConcurrentHashMap<String, Long>()
    private val sequence = AtomicLong()
    private val worker = ThreadPoolExecutor(1, 1, 30, TimeUnit.SECONDS, ArrayBlockingQueue(64),
        ThreadPoolExecutor.AbortPolicy()).apply { allowCoreThreadTimeOut(true) }
    override fun onCreate() { super.onCreate(); store = Store(this) }
    override fun onListenerConnected() { connected = true }
    override fun onListenerDisconnected() {
        pending.clear(); worker.queue.clear()
        connected = false
        // Never enable quiet mode from listener reconnection.
    }
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try { processPosted(sbn) } catch (_: Exception) { processingFailures.incrementAndGet() }
    }
    private fun processPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName || !store.prefs.getBoolean("enabled", false)) return
        val interactive = getSystemService(PowerManager::class.java).isInteractive
        if (interactive && !store.prefs.getBoolean("always", false)) return
        val n = sbn.notification
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val extras = n.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.take(512).orEmpty()
        val expanded = extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val messages = Notification.MessagingStyle.Message.getMessagesFromBundleArray(extras?.getParcelableArray(Notification.EXTRA_MESSAGES))
        val body = messages.lastOrNull()?.text?.toString() ?: expanded ?: extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val ranking = Ranking()
        val ranked = currentRanking.getRanking(sbn.key, ranking)
        val event = Event(sbn.key, sbn.packageName, appName(sbn.packageName), title, body.take(2048), n.category,
            n.channelId.orEmpty(), n.flags and (Notification.FLAG_ONGOING_EVENT or Notification.FLAG_FOREGROUND_SERVICE) != 0,
            ranked && ranking.importance < android.app.NotificationManager.IMPORTANCE_DEFAULT, sbn.postTime, messages.lastOrNull()?.timestamp ?: n.`when`)
        if (!dedup.accept(event, SystemClock.elapsedRealtime())) return
        val revision = sequence.incrementAndGet()
        pending[event.key] = revision
        try { worker.execute {
            try {
                if (pending[event.key] != revision || !store.prefs.getBoolean("enabled", false)) return@execute
                val rules = store.rules()
                if (rules.any { it.pkg == event.pkg && !it.enabled }) return@execute
                val verdict = engine.classify(event, rules)
                if (pending[event.key] == revision && store.prefs.getBoolean("enabled", false)) store.record(event, verdict)
            } catch (_: Exception) { processingFailures.incrementAndGet() } finally { pending.remove(event.key, revision) }
        } } catch (_: java.util.concurrent.RejectedExecutionException) {
            queueDrops.incrementAndGet()
            pending.remove(event.key, revision)
            dedup.remove(event.key)
            // No notification cancellation: overload preserves original system delivery.
        }
    }
    private fun appName(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) { pkg }
    override fun onNotificationRemoved(sbn: StatusBarNotification) { pending.remove(sbn.key); dedup.remove(sbn.key) }
    override fun onDestroy() { pending.clear(); worker.shutdownNow(); connected = false; super.onDestroy() }
}
