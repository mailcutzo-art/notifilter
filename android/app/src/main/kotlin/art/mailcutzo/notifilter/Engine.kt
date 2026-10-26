package art.mailcutzo.notifilter

import java.util.LinkedHashMap

enum class Priority { HIGH, NORMAL, LOW }
data class Event(val key: String, val pkg: String, val app: String = pkg,
    val title: String = "", val text: String = "", val category: String? = null,
    val channel: String = "", val protected: Boolean = false, val silent: Boolean = false,
    val at: Long = System.currentTimeMillis(), val messageStamp: Long = 0)
data class Rule(val pkg: String, val priority: Priority?, val enabled: Boolean = true,
    val phrase: String = "", val channel: String = "")
data class Verdict(val priority: Priority, val source: String, val explanation: String,
    val confidence: Double? = null, val model: String? = null, val micros: Long = 0) {
    fun map(): Map<String, Any?> = mapOf("priority" to priority.name, "source" to source,
        "explanation" to explanation, "confidence" to confidence, "model" to model,
        "micros" to micros, "decision" to "NO_ACTION")
}
interface LocalModel : AutoCloseable {
    val version: String
    fun predict(event: Event): Verdict
}
/** No bundled trained artifact: unavailable is explicit, never a simulated prediction. */
class Engine(private val model: LocalModel? = null, private val threshold: Double = 0.9) {
    fun classify(event: Event, rules: List<Rule> = emptyList()): Verdict {
        val start = System.nanoTime()
        val result = evaluate(event, rules)
        return result.copy(micros = (System.nanoTime() - start) / 1000)
    }
    private fun evaluate(e: Event, rules: List<Rule>): Verdict {
        if (e.protected || e.category in setOf("call", "alarm", "emergency", "sys", "transport", "service"))
            return Verdict(Priority.HIGH, "SYSTEM_PROTECTION", "PROTECTED_EVENT")
        val text = "${e.title} ${e.text}"
        val matching = rules.filter { it.enabled && it.priority != null && (it.pkg == e.pkg || it.pkg == "*") &&
            (it.channel.isEmpty() || it.channel == e.channel) &&
            (it.phrase.isEmpty() || text.contains(it.phrase, ignoreCase = true)) }
        // Preserve awareness on conflicting rules; specific rules precede app-wide rules.
        val rule = matching.sortedWith(compareByDescending<Rule> { it.channel.isNotEmpty() || it.phrase.isNotEmpty() }
            .thenBy { it.priority!!.ordinal }).firstOrNull()
        if (rule != null) return Verdict(rule.priority!!, "USER_RULE", "EXPLICIT_RULE")
        if (text.isBlank()) return Verdict(Priority.NORMAL, "FALLBACK", "CONTENT_UNAVAILABLE")
        // Safety rules only raise priority. Promotional text alone never lowers it.
        if (Regex("(?i)(emergency|suspicious activity|payment.{0,20}failed|security alert|urgent|arrived|overdue|आपातकाल|जरूरी|इमरजेंसी|zaroori|turant)").containsMatchIn(text))
            return Verdict(Priority.HIGH, "SIMPLE_RULE", "SAFETY_PHRASE")
        if (model == null) return Verdict(Priority.NORMAL, "FALLBACK", "MODEL_UNAVAILABLE")
        return try {
            val v = model.predict(e)
            val p = v.confidence
            if (p == null || !p.isFinite() || p !in 0.0..1.0 || p < threshold)
                Verdict(Priority.NORMAL, "FALLBACK", "UNCERTAIN_PREDICTION")
            else v.copy(source = "AI", model = model.version)
        } catch (_: Exception) { Verdict(Priority.NORMAL, "FALLBACK", "INFERENCE_FAILED") }
    }
}
/** Bounded, monotonic-time TTL cache. Removal invalidates a key; changed text is new work. */
class Deduplicator(private val capacity: Int = 512, private val ttlMillis: Long = 120000) {
    private val entries = LinkedHashMap<String, Pair<Event, Long>>()
    @Synchronized fun accept(e: Event, now: Long): Boolean {
        entries.entries.removeAll { now - it.value.second >= ttlMillis }
        val old = entries[e.key]
        val same = old != null && old.first.copy(at = e.at) == e
        if (same) return false
        entries.remove(e.key); entries[e.key] = e to now
        while (entries.size > capacity) entries.remove(entries.keys.first())
        return true
    }
    @Synchronized fun remove(key: String) { entries.remove(key) }
}
