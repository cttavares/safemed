package com.example.safemed

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives the AlarmManager broadcast at the exact scheduled time and launches
 * AlarmActivity directly.  Because we use AlarmManager (not just the notification
 * fullScreenIntent) the activity is started even when the app is in the foreground
 * or the screen is off, bypassing the Android 10+ fullScreenIntent suppression for
 * foreground apps.
 */
class AlarmBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Medication Alarm"
        val body  = intent.getStringExtra("body")  ?: "Time to take your medication"
        val id    = intent.getIntExtra("id", 0)

        val alarmIntent = Intent(context, AlarmActivity::class.java).apply {
            putExtra("title",          title)
            putExtra("body",           body)
            putExtra("notificationId", id)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK    or
                Intent.FLAG_ACTIVITY_CLEAR_TOP   or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        context.startActivity(alarmIntent)
    }
}
