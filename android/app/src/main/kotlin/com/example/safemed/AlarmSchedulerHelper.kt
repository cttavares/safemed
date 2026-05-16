package com.example.safemed

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

data class PendingAlarm(
    val id: Int,
    val title: String,
    val body: String,
    val triggerAtMillis: Long,
    val soundUri: String? = null,
)

/**
 * Centralised helper for AlarmManager scheduling and SharedPreferences persistence.
 * Used by MainActivity (via MethodChannel) and AlarmBootReceiver (on reboot).
 */
object AlarmSchedulerHelper {

    private const val PREFS_NAME = "safemed_alarm_prefs"
    private const val KEY_ALARMS = "pending_alarms"

    // ── Public API ────────────────────────────────────────────────────────────

    fun scheduleAlarm(
        context: Context,
        id: Int,
        title: String,
        body: String,
        triggerAtMillis: Long,
        soundUri: String? = null,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = receiverIntent(context, id, title, body, soundUri)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val showPending = PendingIntent.getActivity(
                context, id,
                Intent(context, AlarmActivity::class.java),
                pendingFlags(),
            )
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtMillis, showPending),
                pending,
            )
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }

        saveAlarm(context, PendingAlarm(id, title, body, triggerAtMillis, soundUri))
    }

    fun cancelAlarm(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(receiverIntent(context, id, "", "", null))
        removeAlarm(context, id)
    }

    fun clearAllAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        loadAlarms(context).forEach { alarm ->
            alarmManager.cancel(receiverIntent(context, alarm.id, "", "", null))
        }
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().remove(KEY_ALARMS).apply()
    }

    fun loadAlarms(context: Context): List<PendingAlarm> {
        val json = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ALARMS, null) ?: return emptyList()
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                PendingAlarm(
                    o.getInt("id"), o.getString("title"),
                    o.getString("body"), o.getLong("triggerAtMillis"),
                    if (o.has("soundUri")) o.getString("soundUri").takeIf { it.isNotEmpty() } else null,
                )
            }
        } catch (_: Exception) { emptyList() }
    }

    /** Remove alarms that have already passed from SharedPreferences. */
    fun cleanupPast(context: Context) {
        val now = System.currentTimeMillis()
        persistAlarms(context, loadAlarms(context).filter { it.triggerAtMillis > now })
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private fun saveAlarm(context: Context, alarm: PendingAlarm) {
        val list = loadAlarms(context).toMutableList()
        list.removeAll { it.id == alarm.id }
        list.add(alarm)
        persistAlarms(context, list)
    }

    private fun removeAlarm(context: Context, id: Int) {
        persistAlarms(context, loadAlarms(context).filter { it.id != id })
    }

    private fun persistAlarms(context: Context, alarms: List<PendingAlarm>) {
        val arr = JSONArray()
        alarms.forEach { a ->
            arr.put(JSONObject().apply {
                put("id", a.id); put("title", a.title)
                put("body", a.body); put("triggerAtMillis", a.triggerAtMillis)
                put("soundUri", a.soundUri ?: "")
            })
        }
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putString(KEY_ALARMS, arr.toString()).apply()
    }

    private fun pendingFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

    private fun receiverIntent(context: Context, id: Int, title: String, body: String, soundUri: String?): PendingIntent {
        val intent = Intent(context, AlarmBroadcastReceiver::class.java).apply {
            putExtra("id", id); putExtra("title", title); putExtra("body", body)
            if (!soundUri.isNullOrEmpty()) putExtra("soundUri", soundUri)
        }
        return PendingIntent.getBroadcast(context, id, intent, pendingFlags())
    }
}
