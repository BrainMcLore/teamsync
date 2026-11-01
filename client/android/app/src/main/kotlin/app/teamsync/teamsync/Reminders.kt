package app.teamsync.teamsync

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

/** No credentials, team names or event titles are stored in alarms/notifications. */
object Reminders {
    private const val CHANNEL = "teamsync_practice"
    private const val PREFS = "teamsync_reminders"
    private val idPattern = Regex("^[a-f0-9]{16}$")
    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun rows(c: Context): List<JSONObject> {
        val data = JSONArray(prefs(c).getString("rows", "[]"))
        return (0 until data.length()).map { data.getJSONObject(it) }
    }
    private fun save(c: Context, data: List<JSONObject>) {
        check(prefs(c).edit().putString("rows", JSONArray(data).toString()).commit())
    }
    fun enabled(c: Context): Boolean {
        if (!NotificationManagerCompat.from(c).areNotificationsEnabled() ||
            (Build.VERSION.SDK_INT >= 33 && c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)) return false
        return Build.VERSION.SDK_INT < 26 || c.getSystemService(android.app.NotificationManager::class.java)
            .getNotificationChannel(CHANNEL)?.importance != android.app.NotificationManager.IMPORTANCE_NONE
    }
    fun channel(c: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = c.getSystemService(android.app.NotificationManager::class.java)
            manager.createNotificationChannel(android.app.NotificationChannel(CHANNEL, "TeamSync", android.app.NotificationManager.IMPORTANCE_DEFAULT))
        }
    }
    private fun intent(c: Context, id: String): PendingIntent = PendingIntent.getBroadcast(c, 0,
        Intent(c, ReminderReceiver::class.java).setData(Uri.parse("teamsync-reminder://$id")),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancel(c: Context, row: JSONObject) {
        val id = row.getString("id")
        val pending = intent(c, id)
        (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending)
        pending.cancel()
        NotificationManagerCompat.from(c).cancel(id, 0)
    }
    private fun arm(c: Context, row: JSONObject) {
        val whenAt = maxOf(System.currentTimeMillis() + 1000, row.getLong("at"))
        (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, whenAt, intent(c, row.getString("id")))
    }
    @Synchronized fun replace(c: Context, input: List<Map<*, *>>): Int {
        require(input.size <= 64)
        val now = System.currentTimeMillis()
        val incoming = input.map { raw ->
            val id = raw["id"] as String
            val at = (raw["at"] as Number).toLong()
            val start = (raw["start"] as Number).toLong()
            val title = raw["title"] as String
            val body = raw["body"] as String
            require(idPattern.matches(id) && title.length <= 80 && body.length <= 400)
            require(at >= 0 && start >= at && start - at <= 120 * 60000 && start <= now + 31L * 86400000)
            JSONObject().put("id", id).put("at", at).put("start", start).put("title", title).put("body", body)
        }
        require(incoming.map { it.getString("id") }.distinct().size == incoming.size)
        channel(c)
        val previous = rows(c).associateBy { it.getString("id") }
        val active = incoming.filter { it.getLong("start") + 300000 > now }.associateBy { it.getString("id") }
        previous.values.filter { !active.containsKey(it.getString("id")) }.forEach { cancel(c, it) }
        val kept = mutableListOf<JSONObject>()
        for ((id, row) in active) {
            val old = previous[id]
            if (old != null && old.getLong("at") == row.getLong("at") && old.getLong("start") == row.getLong("start")) {
                row.put("delivered", old.optBoolean("delivered")).put("armed", old.optBoolean("armed"))
                kept.add(row)
            } else if (row.getLong("at") > now) {
                if (old != null) cancel(c, old)
                row.put("delivered", false).put("armed", false)
                kept.add(row)
            }
        }
        // Persist before arming; a racing receiver can only read this validated plan.
        save(c, kept)
        for (row in kept) {
            if (!row.optBoolean("delivered") && !row.optBoolean("armed")) {
                arm(c, row); row.put("armed", true); save(c, kept)
            }
        }
        return kept.count { !it.optBoolean("delivered") }
    }
    @Synchronized fun clear(c: Context) {
        val old = rows(c)
        save(c, emptyList())
        old.forEach { cancel(c, it) }
        NotificationManagerCompat.from(c).cancel("test-reminder", 0)
    }
    @Synchronized fun restore(c: Context) {
        val now = System.currentTimeMillis()
        val all = rows(c)
        all.forEach { it.put("armed", false) }; save(c, all)
        for (row in all) if (!row.optBoolean("delivered") && row.getLong("start") + 300000 > now) {
            arm(c, row); row.put("armed", true); save(c, all)
        }
    }
    private fun show(c: Context, id: String, title: String, body: String) {
        if (!enabled(c)) return
        channel(c)
        val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(c, CHANNEL).setSmallIcon(R.drawable.ic_reminder)
            .setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setColor(0xff93e6ca.toInt()).setContentIntent(open).setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).setCategory(NotificationCompat.CATEGORY_EVENT)
            .setTimeoutAfter(2L * 60 * 60 * 1000).build()
        NotificationManagerCompat.from(c).notify(id, 0, notification)
    }
    @Synchronized fun deliver(c: Context, id: String) {
        val all = rows(c)
        val row = all.firstOrNull { it.getString("id") == id } ?: return
        val now = System.currentTimeMillis()
        if (row.optBoolean("delivered") || now < row.getLong("at") || now > row.getLong("start") + 300000 || !enabled(c)) return
        row.put("delivered", true)
        save(c, all)
        show(c, id, row.getString("title"), row.getString("body"))
    }
    fun test(c: Context, title: String, body: String): Boolean {
        if (!enabled(c)) return false
        show(c, "test-reminder", title.take(80), body.take(400))
        return true
    }
    fun status(c: Context): Map<String, Any> {
        channel(c)
        val active = if (Build.VERSION.SDK_INT >= 23) c.getSystemService(android.app.NotificationManager::class.java).activeNotifications.size else 0
        return mapOf("supported" to true, "enabled" to enabled(c), "count" to rows(c).count { !it.optBoolean("delivered") && it.getLong("start") + 300000 > System.currentTimeMillis() }, "active" to active)
    }
    fun settings(c: Context) {
        val page = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, c.packageName)
            else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${c.packageName}"))
        c.startActivity(page.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { Reminders.deliver(context, intent.data?.host ?: return) } catch (_: Exception) { }
    }
}
class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
            try { Reminders.restore(context) } catch (_: Exception) { }
        }
    }
}
