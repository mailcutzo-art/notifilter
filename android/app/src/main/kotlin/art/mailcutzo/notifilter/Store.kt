package art.mailcutzo.notifilter

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Metadata only: message body/title/key/sender are never persisted. */
class Store(context: Context) : SQLiteOpenHelper(context.applicationContext, "metadata.db", null, 1) {
    val prefs = context.applicationContext.getSharedPreferences("settings", Context.MODE_PRIVATE)
    init { setWriteAheadLoggingEnabled(true) }
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE history(id INTEGER PRIMARY KEY, pkg TEXT NOT NULL, app TEXT NOT NULL, priority TEXT NOT NULL, source TEXT NOT NULL, explanation TEXT NOT NULL, micros INTEGER NOT NULL, at INTEGER NOT NULL)")
        db.execSQL("CREATE INDEX history_at ON history(at)")
        db.execSQL("CREATE TABLE rules(pkg TEXT PRIMARY KEY, priority TEXT, enabled INTEGER NOT NULL DEFAULT 1)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { error("Unsupported schema migration") }
    fun rules(): List<Rule> = readableDatabase.rawQuery("SELECT pkg, priority, enabled FROM rules", null).use { c ->
        buildList { while(c.moveToNext()) add(Rule(c.getString(0), c.getString(1)?.let { Priority.valueOf(it) }, c.getInt(2) == 1)) }
    }
    fun rule(pkg: String, priority: String?, enabled: Boolean) {
        require(pkg.length in 1..255)
        priority?.let { Priority.valueOf(it) }
        writableDatabase.insertWithOnConflict("rules", null, ContentValues().apply {
            put("pkg", pkg); put("priority", priority); put("enabled", if(enabled) 1 else 0)
        }, SQLiteDatabase.CONFLICT_REPLACE)
    }
    fun record(e: Event, v: Verdict) {
        if (!prefs.getBoolean("history", true)) return
        writableDatabase.insert("history", null, ContentValues().apply {
            put("pkg", e.pkg); put("app", e.app); put("priority", v.priority.name); put("source", v.source)
            put("explanation", v.explanation); put("micros", v.micros); put("at", e.at)
        })
        prune()
    }
    fun prune() {
        writableDatabase.delete("history", "at < ?", arrayOf((System.currentTimeMillis() - prefs.getInt("retention", 7) * 86400000L).toString()))
        writableDatabase.execSQL("DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY id DESC LIMIT 2000)")
    }
    fun clear() { writableDatabase.delete("history", null, null) }
    fun history(): List<Map<String, Any?>> {
        prune()
        return readableDatabase.rawQuery("SELECT id,pkg,app,priority,source,explanation,micros,at FROM history ORDER BY at DESC LIMIT 500", null).use { c ->
            buildList { while(c.moveToNext()) add(mapOf("id" to c.getLong(0), "pkg" to c.getString(1), "app" to c.getString(2),
                "priority" to c.getString(3), "source" to c.getString(4), "explanation" to c.getString(5),
                "micros" to c.getLong(6), "at" to c.getLong(7), "action" to "NO_ACTION")) }
        }
    }
}
