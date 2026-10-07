package com.chrona.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.core.app.NotificationCompat

/** Owns the system alarm and the app-controlled end-of-session alert. */
object ReminderAlarm {
    const val CHANNEL_NAME = "com.chrona.app/reminder_alarm"
    const val ACTION_FIRE = "com.chrona.app.action.FIRE_REMINDER"
    const val ACTION_STOP = "com.chrona.app.action.STOP_REMINDER"
    const val NOTIFICATION_ID = 1001
    const val CHANNEL_ID = "chrona_reminder_service_v1"

    private const val PREFS = "chrona_reminder_alarm"
    private const val KEY_AT = "trigger_at"
    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    private const val KEY_SOUND = "play_sound"
    private const val KEY_VIBRATE = "vibrate"
    private const val KEY_TRIGGERED = "triggered"

    private const val EXTRA_AT = "trigger_at"
    private const val EXTRA_TITLE = "title"
    private const val EXTRA_BODY = "body"
    private const val EXTRA_SOUND = "play_sound"
    private const val EXTRA_VIBRATE = "vibrate"

    fun schedule(
        context: Context,
        title: String,
        body: String,
        triggerAtMillis: Long,
        playSound: Boolean,
        vibrate: Boolean,
        exact: Boolean,
    ) {
        cancelPendingAlarm(context)
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        preferences.edit()
            .putLong(KEY_AT, triggerAtMillis)
            .putString(KEY_TITLE, title)
            .putString(KEY_BODY, body)
            .putBoolean(KEY_SOUND, playSound)
            .putBoolean(KEY_VIBRATE, vibrate)
            .putBoolean(KEY_TRIGGERED, false)
            .apply()
        setAlarm(context, triggerAtMillis, title, body, playSound, vibrate, exact)
    }

    fun cancel(context: Context) {
        cancelPendingAlarm(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        context.stopService(Intent(context, ReminderAlertService::class.java))
        stopAlert(context)
    }

    fun restoreAfterBoot(context: Context) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val triggerAt = preferences.getLong(KEY_AT, 0L)
        if (triggerAt == 0L) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) return
        }

        val wasTriggered = preferences.getBoolean(KEY_TRIGGERED, false)
        val nextAt = if (wasTriggered) System.currentTimeMillis() + 1_000L else triggerAt
        setAlarm(
            context = context,
            triggerAtMillis = nextAt,
            title = preferences.getString(KEY_TITLE, "计时结束") ?: "计时结束",
            body = preferences.getString(KEY_BODY, "本轮计时已结束") ?: "本轮计时已结束",
            playSound = preferences.getBoolean(KEY_SOUND, true),
            vibrate = preferences.getBoolean(KEY_VIBRATE, true),
            exact = true,
        )
    }

    fun markTriggered(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_TRIGGERED, true).apply()
    }

    private fun setAlarm(
        context: Context,
        triggerAtMillis: Long,
        title: String,
        body: String,
        playSound: Boolean,
        vibrate: Boolean,
        exact: Boolean,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_AT, triggerAtMillis)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_SOUND, playSound)
            putExtra(EXTRA_VIBRATE, vibrate)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            NOTIFICATION_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        try {
            if (exact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
        } catch (error: SecurityException) {
            if (exact) throw error
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
        }
    }

    private fun cancelPendingAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            NOTIFICATION_ID,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    fun stopAlert(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                .defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        vibrator.cancel()
    }
}

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderAlarm.ACTION_FIRE) return
        ReminderAlarm.markTriggered(context)
        val serviceIntent = Intent(context, ReminderAlertService::class.java).apply {
            putExtras(intent)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            ReminderAlarm.restoreAfterBoot(context)
        }
    }
}

class StopReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderAlarm.cancel(context)
    }
}

class ReminderAlertService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var audioManager: AudioManager? = null
    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ReminderAlarm.ACTION_STOP) {
            ReminderAlarm.cancel(this)
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra("title") ?: "计时结束"
        val body = intent?.getStringExtra("body") ?: "本轮计时已结束"
        val playSound = intent?.getBooleanExtra("play_sound", true) ?: true
        val vibrate = intent?.getBooleanExtra("vibrate", true) ?: true
        startForeground(ReminderAlarm.NOTIFICATION_ID, buildNotification(title, body))
        stopAlertEffects()
        if (playSound) startSound()
        if (vibrate) startVibration()
        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        stopAlertEffects()
        super.onDestroy()
    }

    private fun buildNotification(title: String, body: String): Notification {
        createNotificationChannel()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val stopIntent = Intent(this, StopReminderReceiver::class.java).apply {
            action = ReminderAlarm.ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            this,
            ReminderAlarm.NOTIFICATION_ID,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, ReminderAlarm.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(contentIntent)
            .addAction(android.R.drawable.ic_lock_idle_alarm, "停止提醒", stopPendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(ReminderAlarm.CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    ReminderAlarm.CHANNEL_ID,
                    "计时结束提醒",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "显示计时结束提醒；声音和震动由 CHRONA 控制"
                    setSound(null, null)
                    enableVibration(false)
                },
            )
        }
    }

    private fun startSound() {
        val uri = Settings.System.DEFAULT_NOTIFICATION_URI
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager = manager
        @Suppress("DEPRECATION")
        manager.requestAudioFocus(
            audioFocusListener,
            AudioManager.STREAM_ALARM,
            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
        )

        try {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(attributes)
                isLooping = true
                setDataSource(this@ReminderAlertService, uri)
                setOnPreparedListener { player ->
                    if (mediaPlayer === player) {
                        player.start()
                    } else {
                        player.release()
                    }
                }
                setOnErrorListener { player, _, _ ->
                    player.release()
                    if (mediaPlayer === player) mediaPlayer = null
                    true
                }
                prepareAsync()
            }
        } catch (_: Exception) {
            mediaPlayer?.release()
            mediaPlayer = null
        }
    }

    private fun startVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0L, 500L, 500L)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun stopAlertEffects() {
        try {
            mediaPlayer?.let { player ->
                if (player.isPlaying) player.stop()
                player.release()
            }
        } catch (_: IllegalStateException) {
            mediaPlayer?.release()
        }
        mediaPlayer = null
        vibrator?.cancel()
        vibrator = null
        @Suppress("DEPRECATION")
        audioManager?.abandonAudioFocus(audioFocusListener)
        audioManager = null
    }
}
