package com.example.safemed

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val SELECT_NOTIFICATION = "SELECT_NOTIFICATION"
        private const val ALARM_CHANNEL       = "safemed/alarm_manager"
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAlarmIntent(intent)
    }

    // ── Flutter MethodChannel ────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        try {
                            val id    = call.argument<Int>("id")
                                ?: return@setMethodCallHandler result.error("BAD_ARG", "id required", null)
                            val title = call.argument<String>("title") ?: "Medication Alarm"
                            val body  = call.argument<String>("body")  ?: "Time to take your medication"
                            // Dart int arrives as Int or Long depending on value magnitude
                            val triggerAtMillis: Long = when (val raw = call.argument<Any>("triggerAtMillis")) {
                                is Int  -> raw.toLong()
                                is Long -> raw
                                else    -> return@setMethodCallHandler result.error("BAD_ARG", "triggerAtMillis required", null)
                            }
                            scheduleAlarmManagerAlarm(id, title, body, triggerAtMillis)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_ERROR", e.message, null)
                        }
                    }
                    "cancelAlarm" -> {
                        try {
                            val id = call.argument<Int>("id")
                                ?: return@setMethodCallHandler result.error("BAD_ARG", "id required", null)
                            cancelAlarmManagerAlarm(id)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── AlarmManager helpers ─────────────────────────────────────────────────

    private fun pendingIntentFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else
            PendingIntent.FLAG_UPDATE_CURRENT

    private fun receiverPendingIntent(id: Int, title: String, body: String): PendingIntent {
        val intent = Intent(this, AlarmBroadcastReceiver::class.java).apply {
            putExtra("id",    id)
            putExtra("title", title)
            putExtra("body",  body)
        }
        return PendingIntent.getBroadcast(this, id, intent, pendingIntentFlags())
    }

    private fun scheduleAlarmManagerAlarm(
        id: Int, title: String, body: String, triggerAtMillis: Long
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending      = receiverPendingIntent(id, title, body)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            // setAlarmClock fires exactly even in Doze mode and shows the clock icon
            val showIntent  = Intent(this, AlarmActivity::class.java)
            val showPending = PendingIntent.getActivity(this, id, showIntent, pendingIntentFlags())
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtMillis, showPending),
                pending
            )
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }
    }

    private fun cancelAlarmManagerAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending      = receiverPendingIntent(id, "","")
        alarmManager.cancel(pending)
    }

    // ── Notification tap handler ─────────────────────────────────────────────

    /**
     * When the user taps the notification (or fullScreenIntent fires via MainActivity),
     * always launch AlarmActivity — regardless of keyguard state.
     */
    private fun handleAlarmIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action != SELECT_NOTIFICATION) return

        val alarmIntent = Intent(this, AlarmActivity::class.java).apply {
            putExtra("title",   intent.getStringExtra("title")   ?: "Medication Alarm")
            putExtra("body",    intent.getStringExtra("body")    ?: "Time to take your medication")
            putExtra("payload", intent.getStringExtra("payload") ?: "")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(alarmIntent)
    }
}
