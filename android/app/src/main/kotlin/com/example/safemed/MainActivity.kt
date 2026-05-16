package com.example.safemed

import android.content.Intent
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
                            val triggerAtMillis: Long = when (val raw = call.argument<Any>("triggerAtMillis")) {
                                is Int  -> raw.toLong()
                                is Long -> raw
                                else    -> return@setMethodCallHandler result.error("BAD_ARG", "triggerAtMillis required", null)
                            }
                            val soundUri = call.argument<String>("soundUri")
                            AlarmSchedulerHelper.scheduleAlarm(this, id, title, body, triggerAtMillis, soundUri)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_ERROR", e.message, null)
                        }
                    }
                    "cancelAlarm" -> {
                        try {
                            val id = call.argument<Int>("id")
                                ?: return@setMethodCallHandler result.error("BAD_ARG", "id required", null)
                            AlarmSchedulerHelper.cancelAlarm(this, id)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_ERROR", e.message, null)
                        }
                    }
                    "clearAllAlarms" -> {
                        try {
                            AlarmSchedulerHelper.clearAllAlarms(this)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CLEAR_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }


    // ── Notification tap handler ─────────────────────────────────────────────

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
