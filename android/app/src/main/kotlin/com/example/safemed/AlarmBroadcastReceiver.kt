package com.example.safemed

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Receives the AlarmManager broadcast fired by [AlarmSchedulerHelper.scheduleAlarm].
 *
 * Uses the SAME strategy as the stock Android clock app:
 *
 *  1. Acquire a partial WakeLock so the CPU stays on long enough to start the activity.
 *  2. Start [AlarmActivity] directly via startActivity().  This is explicitly
 *     allowed on Android 10+ for receivers triggered by [AlarmManager.setAlarmClock]
 *     — the OS grants a background activity start exemption.
 *  3. Post a high-priority notification with fullScreenIntent as a safety net
 *     (some OEMs block startActivity even for alarm-clock receivers).
 *
 * The notification channel is created inline (idempotent) so we never depend on
 * the Flutter engine having initialised first.
 */
class AlarmBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID   = "safemed_alarm_receiver_channel"
        private const val CHANNEL_NAME = "Medication Alarms"
        private const val WAKELOCK_TAG = "safemed:alarm_wakelock"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val title    = intent.getStringExtra("title")    ?: "Medication Alarm"
        val body     = intent.getStringExtra("body")     ?: "Time to take your medication"
        val id       = intent.getIntExtra("id", 0)
        val soundUri = intent.getStringExtra("soundUri")

        // ── 1. Acquire a partial WakeLock (released by AlarmActivity.onCreate) ──
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            WAKELOCK_TAG,
        )
        wl.acquire(30_000L)  // 30 s safety timeout

        // ── 2. Start AlarmActivity directly ─────────────────────────────────
        //    Allowed because this receiver is fired by setAlarmClock().
        val activityIntent = Intent(context, AlarmActivity::class.java).apply {
            putExtra("title",          title)
            putExtra("body",           body)
            putExtra("notificationId", id)
            if (!soundUri.isNullOrEmpty()) putExtra("soundUri", soundUri)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        try {
            context.startActivity(activityIntent)
        } catch (_: Exception) {
            // Swallowed — the fullScreenIntent fallback below will handle it.
        }

        // ── 3. Post notification with fullScreenIntent (backup / lock screen) ──
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(nm)

        val fullScreenPI = PendingIntent.getActivity(
            context, id, activityIntent, piFlags(),
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPI, true)
            .setAutoCancel(false)
            .setOngoing(true)   // stay in the shade until dismissed
            .build()

        nm.notify(id, notification)

        // Release the wake lock after a short delay — AlarmActivity holds its own
        // KEEP_SCREEN_ON flag once started.
        wl.release()
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun piFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else
            PendingIntent.FLAG_UPDATE_CURRENT

    private fun ensureChannel(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return

        val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val audioAttr = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description          = "SafeMed medication alarm"
            enableVibration(true)
            vibrationPattern     = longArrayOf(0, 800, 400)
            setSound(alarmSound, audioAttr)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)  // alarms should override Do Not Disturb
        }
        nm.createNotificationChannel(channel)
    }
}
