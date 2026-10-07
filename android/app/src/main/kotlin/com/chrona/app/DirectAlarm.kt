package com.chrona.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.app.Service
import java.io.File

object DirectAlarm {
    private const val REQUEST_CODE = 73104

    fun schedule(
        context: Context,
        triggerAtMillis: Long,
        exact: Boolean,
        playSound: Boolean,
        enableVibration: Boolean,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = alarmPendingIntent(context, playSound, enableVibration)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (exact && (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms())) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
        } else if (exact) {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(alarmPendingIntent(context))
        context.stopService(Intent(context, DirectAlarmPlaybackService::class.java))
    }

    private fun alarmPendingIntent(
        context: Context,
        playSound: Boolean = false,
        enableVibration: Boolean = false,
    ): PendingIntent {
        val intent = Intent(context, DirectAlarmReceiver::class.java)
            .putExtra("playSound", playSound)
            .putExtra("enableVibration", enableVibration)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )
    }
}

class DirectAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val serviceIntent = Intent(context, DirectAlarmPlaybackService::class.java)
            .putExtra("playSound", intent.getBooleanExtra("playSound", true))
            .putExtra("enableVibration", intent.getBooleanExtra("enableVibration", true))
        try {
            context.startService(serviceIntent)
        } catch (_: RuntimeException) {
            // Android may block background service startup. The app has no notification fallback by design.
        }
    }
}

class DirectAlarmPlaybackService : Service() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private val handler = Handler(Looper.getMainLooper())
    private val stopPlayback = Runnable { stopSelf() }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (player?.isPlaying == true) return START_NOT_STICKY
        try {
            if (intent?.getBooleanExtra("playSound", true) != false) {
                val alarmFile = File(cacheDir, "chrona_alarm.mp3")
                assets.open("flutter_assets/assets/ring/ring.mp3").use { input ->
                    alarmFile.outputStream().use { output -> input.copyTo(output) }
                }
                player = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                    setDataSource(alarmFile.absolutePath)
                    isLooping = true
                    prepare()
                    start()
                }
            }
            if (intent?.getBooleanExtra("enableVibration", true) != false) {
                val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
                } else {
                    @Suppress("DEPRECATION")
                    getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                }
                vibrator = vib
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vib.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 500), 0))
                } else {
                    @Suppress("DEPRECATION")
                    vib.vibrate(longArrayOf(0, 500, 500), 0)
                }
            }
            // Bound playback so a missed stop action cannot leave the device ringing indefinitely.
            handler.postDelayed(stopPlayback, 90_000L)
        } catch (_: Exception) {
            stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(stopPlayback)
        player?.runCatching { stop(); release() }
        player = null
        vibrator?.cancel()
        vibrator = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
