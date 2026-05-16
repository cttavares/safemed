package com.example.safemed

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired by Android after a device reboot (BOOT_COMPLETED).
 * Re-registers all future AlarmManager alarms that were stored in SharedPreferences
 * when they were originally scheduled — identical to how the native clock app works.
 */
class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON"
        ) return

        val now = System.currentTimeMillis()
        val alarms = AlarmSchedulerHelper.loadAlarms(context)

        for (alarm in alarms) {
            if (alarm.triggerAtMillis <= now) continue   // already past — skip
            AlarmSchedulerHelper.scheduleAlarm(
                context,
                alarm.id,
                alarm.title,
                alarm.body,
                alarm.triggerAtMillis,
                alarm.soundUri,
            )
        }

        // Clean up stale past alarms from SharedPreferences
        AlarmSchedulerHelper.cleanupPast(context)
    }
}
