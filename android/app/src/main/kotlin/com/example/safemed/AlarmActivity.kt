package com.example.safemed

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen alarm Activity launched when a medication alarm fires with the device locked.
 * MainActivity intercepts the flutter_local_notifications fullScreenIntent and starts this
 * when the keyguard is locked.
 *
 * This Activity owns its own alarm sound (MediaPlayer → STREAM_ALARM) and vibration,
 * guaranteeing true alarm-clock behaviour regardless of notification-channel settings.
 */
class AlarmActivity : Activity() {

    private var vibrator: Vibrator? = null
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── Wake screen & show on lock screen ──────────────────────────────
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON   or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val title = intent?.getStringExtra("title") ?: "Medication Alarm"
        val body  = intent?.getStringExtra("body")  ?: "Time to take your medication"

        startAlarmSound()
        startVibration()
        setContentView(buildUi(title, body))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    // ── Alarm sound via MediaPlayer on STREAM_ALARM ─────────────────────────
    private fun startAlarmSound() {
        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: return

        try {
            mediaPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, alarmUri)
                isLooping = true
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                } else {
                    @Suppress("DEPRECATION")
                    setAudioStreamType(AudioManager.STREAM_ALARM)
                }
                prepare()
                start()
            }
        } catch (_: Exception) {
            // If we can't play the alarm URI, ignore — vibration still provides feedback
        }
    }

    // ── Strong repeating vibration ───────────────────────────────────────────
    private fun startVibration() {
        val pattern = longArrayOf(0, 800, 400)
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    // ── UI ───────────────────────────────────────────────────────────────────
    private fun buildUi(title: String, body: String): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity     = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#B71C1C"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
        root.addView(TextView(this).apply {
            text     = "💊"
            textSize = 72f
            gravity  = Gravity.CENTER
        })
        root.addView(TextView(this).apply {
            text     = title
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity  = Gravity.CENTER
            setPadding(32, 24, 32, 8)
        })
        root.addView(TextView(this).apply {
            text     = body
            textSize = 18f
            setTextColor(Color.parseColor("#FFCDD2"))
            gravity  = Gravity.CENTER
            setPadding(32, 0, 32, 40)
        })
        root.addView(Button(this).apply {
            text     = "Dismiss"
            textSize = 18f
            setTextColor(Color.parseColor("#B71C1C"))
            setBackgroundColor(Color.WHITE)
            setPadding(64, 24, 64, 24)
            setOnClickListener { dismiss() }
        })
        return root
    }

    private fun dismiss() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        vibrator?.cancel()
        finish()
    }

    override fun onDestroy() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        vibrator?.cancel()
        super.onDestroy()
    }
}

