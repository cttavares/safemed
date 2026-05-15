package com.example.safemed

import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Full-screen alarm Activity — behaves exactly like the native phone clock alarm:
 *  - Forces the screen on and shows above the lock screen
 *  - Plays sound on STREAM_ALARM (bypasses silent/vibrate profile)
 *  - Forces alarm volume audible if at 0
 *  - Strong repeating vibration
 *  - Back button blocked — must Dismiss or Snooze
 *  - Snooze reschedules 5 minutes from now
 *  - Dismiss cancels the notification
 *  - Live clock updates every second
 */
class AlarmActivity : Activity() {

    private var vibrator: Vibrator? = null
    private var mediaPlayer: MediaPlayer? = null
    private val clockHandler = Handler(Looper.getMainLooper())
    private var clockView: TextView? = null

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── Wake & show on lock screen ────────────────────────────────────────
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
        window.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )

        val title    = intent?.getStringExtra("title")    ?: "Medication Alarm"
        val body     = intent?.getStringExtra("body")     ?: "Time to take your medication"
        val soundUri = intent?.getStringExtra("soundUri")

        startAlarmSound(soundUri)
        startVibration()
        val ui = buildUi(title, body)
        setContentView(ui)
        startClock()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Intentionally blocked — user must Dismiss or Snooze
    }

    override fun onDestroy() {
        stopEverything()
        super.onDestroy()
    }

    // ── Clock ─────────────────────────────────────────────────────────────────

    private fun startClock() {
        val fmt = SimpleDateFormat("HH:mm", Locale.getDefault())
        val tick = object : Runnable {
            override fun run() {
                clockView?.text = fmt.format(Date())
                clockHandler.postDelayed(this, 1_000)
            }
        }
        tick.run()
    }

    // ── Sound ─────────────────────────────────────────────────────────────────

    private fun startAlarmSound(customUri: String?) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Force alarm stream audible if user has it muted
        if (audioManager.getStreamVolume(AudioManager.STREAM_ALARM) == 0) {
            val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(
                AudioManager.STREAM_ALARM,
                (max * 0.7).toInt().coerceAtLeast(1),
                0,
            )
        }

        val candidates = buildList {
            if (!customUri.isNullOrEmpty()) add(android.net.Uri.parse(customUri))
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)?.let { add(it) }
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)?.let { add(it) }
        }

        for (uri in candidates) {
            try {
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(applicationContext, uri)
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
                return
            } catch (_: Exception) {
                mediaPlayer?.release()
                mediaPlayer = null
            }
        }
    }

    // ── Vibration ─────────────────────────────────────────────────────────────

    private fun startVibration() {
        val pattern = longArrayOf(0, 700, 300)
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

    // ── UI ────────────────────────────────────────────────────────────────────

    private fun buildUi(title: String, body: String): LinearLayout {
        fun dp(v: Int) = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics,
        ).toInt()

        val red     = Color.parseColor("#B71C1C")
        val redDark = Color.parseColor("#7F0000")
        val white   = Color.WHITE
        val pink    = Color.parseColor("#FFCDD2")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity     = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(red)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            setPadding(dp(24), dp(56), dp(24), dp(48))
        }

        // Live clock at the top
        clockView = TextView(this).apply {
            text     = "--:--"
            textSize = 64f
            setTextColor(white)
            gravity  = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            alpha    = 0.9f
        }
        root.addView(clockView)

        // Pill emoji
        root.addView(TextView(this).apply {
            text     = "💊"
            textSize = 56f
            gravity  = Gravity.CENTER
            setPadding(0, dp(16), 0, 0)
        })

        // Profile / patient name
        root.addView(TextView(this).apply {
            text     = title
            textSize = 28f
            setTextColor(white)
            gravity  = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(16), dp(12), dp(16), dp(4))
        })

        // Medication detail
        root.addView(TextView(this).apply {
            text     = body
            textSize = 16f
            setTextColor(pink)
            gravity  = Gravity.CENTER
            setPadding(dp(16), 0, dp(16), dp(40))
        })

        // ── Buttons row ───────────────────────────────────────────────────────
        val buttonsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity     = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        fun pillButton(label: String, bgColor: Int, textColor: Int, onClick: () -> Unit): Button {
            val bg = GradientDrawable().apply {
                setColor(bgColor)
                cornerRadius = dp(32).toFloat()
            }
            return Button(this).apply {
                text       = label
                textSize   = 17f
                this.setTextColor(textColor)
                background = bg
                typeface   = Typeface.DEFAULT_BOLD
                isAllCaps  = false
                setPadding(dp(36), dp(14), dp(36), dp(14))
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { setMargins(dp(8), 0, dp(8), 0) }
                setOnClickListener { onClick() }
            }
        }

        buttonsRow.addView(pillButton("Snooze 5 min", redDark, pink)  { snooze() })
        buttonsRow.addView(pillButton("Dismiss",       white,   red)   { dismiss() })
        root.addView(buttonsRow)

        return root
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    private fun snooze() {
        stopEverything()
        cancelNotification()

        val id       = intent?.getIntExtra("notificationId", 0) ?: 0
        val title    = intent?.getStringExtra("title")    ?: "Medication Alarm"
        val body     = intent?.getStringExtra("body")     ?: "Time to take your medication"
        val soundUri = intent?.getStringExtra("soundUri")
        val snoozeTrigger = System.currentTimeMillis() + 5 * 60 * 1000L

        AlarmSchedulerHelper.scheduleAlarm(
            applicationContext,
            id,
            "⏰ Snooze — $title",
            body,
            snoozeTrigger,
            soundUri,
        )

        finish()
    }

    private fun dismiss() {
        stopEverything()
        cancelNotification()
        finish()
    }

    private fun stopEverything() {
        clockHandler.removeCallbacksAndMessages(null)
        mediaPlayer?.runCatching { stop() }
        mediaPlayer?.runCatching { release() }
        mediaPlayer = null
        vibrator?.cancel()
    }

    private fun cancelNotification() {
        val id = intent?.getIntExtra("notificationId", 0) ?: 0
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
    }
}
