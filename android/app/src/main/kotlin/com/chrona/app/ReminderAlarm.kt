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
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File

/** Schedules the system alarm and owns the short-lived end-of-session alert. */
object ReminderAlarm {
    const val ACTION_FIRE = "com.chrona.app.action.FIRE_REMINDER"
    const val ACTION_STOP = "com.chrona.app.action.STOP_REMINDER"
    const val TIMER_NOTIFICATION_ID = 1001
    const val ALERT_NOTIFICATION_ID = 1002
    const val TIMER_CHANNEL_ID = "chrona_focus_timer_v2"
    const val ALERT_CHANNEL_ID = "chrona_completion_alert_v2"

    private const val REQUEST_CODE = 1001
    private const val PREFS = "chrona_reminder_alarm"
    private const val KEY_AT = "trigger_at"
    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    private const val KEY_TIMER_TITLE = "timer_title"
    private const val KEY_TIMER_BODY = "timer_body"
    private const val KEY_SOUND = "play_sound"
    private const val KEY_VIBRATE = "vibrate"
    private const val KEY_TRIGGERED = "triggered"
    private const val EXTRA_AT = "trigger_at"
    private const val EXTRA_TITLE = "title"
    private const val EXTRA_BODY = "body"
    private const val EXTRA_SOUND = "play_sound"
    private const val EXTRA_VIBRATE = "vibrate"
    const val MAX_ALERT_MILLIS = 60_000L
    // Three 500 ms vibration pulses separated by 500 ms pauses.
    private val vibrationPattern = LongArray(7) { index ->
        when {
            index == 0 -> 0L
            index % 2 == 1 -> 500L
            else -> 500L
        }
    }

    @Synchronized
    fun schedule(
        context: Context,
        title: String,
        body: String,
        timerTitle: String,
        timerBody: String,
        triggerAtMillis: Long,
        playSound: Boolean,
        vibrate: Boolean,
        exact: Boolean,
    ): Boolean {
        cancelPendingAlarm(context)
        stopCompletionAlert(context)
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val saved = preferences.edit()
            .putLong(KEY_AT, triggerAtMillis)
            .putString(KEY_TITLE, title)
            .putString(KEY_BODY, body)
            .putString(KEY_TIMER_TITLE, timerTitle)
            .putString(KEY_TIMER_BODY, timerBody)
            .putBoolean(KEY_SOUND, playSound)
            .putBoolean(KEY_VIBRATE, vibrate)
            .putBoolean(KEY_TRIGGERED, false)
            .commit()
        check(saved) { "Could not persist timer alarm state" }
        return setAlarm(context, triggerAtMillis, title, body, playSound, vibrate, exact)
    }

    @Synchronized
    fun cancel(context: Context) {
        cancelPendingAlarm(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().commit()
        stopAlert(context)
    }

    @Synchronized
    fun restoreAfterBoot(context: Context) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val triggerAt = preferences.getLong(KEY_AT, 0L)
        if (triggerAt == 0L) return
        val wasTriggered = preferences.getBoolean(KEY_TRIGGERED, false)
        val now = System.currentTimeMillis()
        val nextAt = if (wasTriggered || triggerAt <= now) now + 1_000L else triggerAt
        preferences.edit().putBoolean(KEY_TRIGGERED, false).commit()
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val exactAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        val exact = exactAllowed
        setAlarm(
            context,
            nextAt,
            preferences.getString(KEY_TITLE, "计时结束") ?: "计时结束",
            preferences.getString(KEY_BODY, "本轮计时已结束") ?: "本轮计时已结束",
            preferences.getBoolean(KEY_SOUND, true),
            preferences.getBoolean(KEY_VIBRATE, true),
            exact,
        )
        if (!wasTriggered && triggerAt > now) {
            showTimerNotification(
                context,
                preferences.getString(KEY_TIMER_TITLE, "拾年 · 专注中") ?: "拾年 · 专注中",
                preferences.getString(KEY_TIMER_BODY, "专注计时") ?: "专注计时",
                triggerAt,
            )
        }
    }

    @Synchronized
    fun markTriggered(context: Context): Boolean {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (preferences.getBoolean(KEY_TRIGGERED, false)) return false
        return preferences.edit().putBoolean(KEY_TRIGGERED, true).commit()
    }

    fun isAlerting(context: Context): Boolean = context
        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        .getBoolean(KEY_TRIGGERED, false)

    private fun setAlarm(
        context: Context,
        triggerAtMillis: Long,
        title: String,
        body: String,
        playSound: Boolean,
        vibrate: Boolean,
        exact: Boolean,
    ): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_AT, triggerAtMillis)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_SOUND, playSound)
            putExtra(EXTRA_VIBRATE, vibrate)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
        return try {
            if (exact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else if (exact) {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
            exact
        } catch (error: SecurityException) {
            if (!exact) throw error
            Log.w("CHRONA", "Exact alarm denied; scheduling an inexact alarm", error)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
            false
        }
    }

    private fun cancelPendingAlarm(context: Context) {
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply { action = ACTION_FIRE }
        val flags = PendingIntent.FLAG_NO_CREATE or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
        if (pendingIntent != null) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    fun startVibration(context: Context, enabled: Boolean) {
        if (!enabled) return
        val vibrator = getVibrator(context)
        if (!vibrator.hasVibrator()) {
            Log.w("CHRONA", "This device does not report a vibrator")
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val amplitudes = IntArray(vibrationPattern.size) { index ->
                    if (index > 0 && index % 2 == 1) 255 else 0
                }
                val effect = VibrationEffect.createWaveform(vibrationPattern, amplitudes, -1)
                val attributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                vibrator.vibrate(effect, attributes)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(vibrationPattern, -1)
            }
            Log.i("CHRONA", "Started timer alarm vibration")
        } catch (error: Exception) {
            Log.e("CHRONA", "Could not start timer alarm vibration", error)
        }
    }

    private fun getVibrator(context: Context): Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    fun stopAlert(context: Context) {
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).apply {
            cancel(TIMER_NOTIFICATION_ID)
        }
        stopCompletionAlert(context)
    }

    private fun stopCompletionAlert(context: Context) {
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(ALERT_NOTIFICATION_ID)
        getVibrator(context).cancel()
        context.stopService(Intent(context, ReminderAlertService::class.java))
    }

    fun createAlertChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(ALERT_CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(ALERT_CHANNEL_ID, "计时完成提醒", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "显示计时结束状态；震动和铃声由 CHRONA 提醒服务控制"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                },
            )
        }
    }

    private fun createTimerChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(TIMER_CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(TIMER_CHANNEL_ID, "专注计时", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "静音显示专注或休息倒计时"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                },
            )
        }
    }

    private fun showTimerNotification(
        context: Context,
        title: String,
        body: String,
        endsAtMillis: Long,
    ) {
        createTimerChannel(context)
        val notification = NotificationCompat.Builder(context, TIMER_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory("progress")
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setWhen(endsAtMillis)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .build()
        try {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(TIMER_NOTIFICATION_ID, notification)
        } catch (error: SecurityException) {
            Log.w("CHRONA", "Could not restore timer notification after boot", error)
        }
    }

    fun buildAlertNotification(
        context: Context,
        title: String,
        body: String,
        ongoing: Boolean = true,
    ): Notification {
        createAlertChannel(context)
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val stopIntent = Intent(context, StopReminderReceiver::class.java).apply { action = ACTION_STOP }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context, ALERT_NOTIFICATION_ID, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(context, ALERT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(ongoing)
            .setAutoCancel(!ongoing)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setTimeoutAfter(MAX_ALERT_MILLIS)
            .setContentIntent(contentIntent)
            .addAction(android.R.drawable.ic_lock_idle_alarm, "停止震动", stopPendingIntent)
            .build()
    }
}

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ReminderAlarm.ACTION_FIRE || !ReminderAlarm.markTriggered(context)) return
        val title = intent.getStringExtra("title") ?: "计时结束"
        val body = intent.getStringExtra("body") ?: "本轮计时已结束"
        val vibrate = intent.getBooleanExtra("vibrate", true)
        val playSound = intent.getBooleanExtra("play_sound", true)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(ReminderAlarm.TIMER_NOTIFICATION_ID)
        ReminderAlarm.startVibration(context, vibrate)
        val serviceIntent = Intent(context, ReminderAlertService::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
            putExtra("play_sound", playSound)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(serviceIntent)
            else context.startService(serviceIntent)
        } catch (error: RuntimeException) {
            Log.e("CHRONA", "Could not start reminder foreground service", error)
            // Keep the finite direct vibration and leave a stop action if FGS launch is blocked.
            try {
                manager.notify(
                    ReminderAlarm.ALERT_NOTIFICATION_ID,
                    ReminderAlarm.buildAlertNotification(context, title, body, ongoing = false),
                )
            } catch (notificationError: SecurityException) {
                Log.e("CHRONA", "Completion notification permission is unavailable", notificationError)
            }
        }
    }
}

class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) ReminderAlarm.restoreAfterBoot(context)
    }
}

class StopReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ReminderAlarm.ACTION_STOP) ReminderAlarm.cancel(context)
    }
}

class ReminderAlertService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private val stopAlert = Runnable { ReminderAlarm.cancel(this) }
    private var hasStartedAlert = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (hasStartedAlert) return START_NOT_STICKY
        val title = intent?.getStringExtra("title") ?: "计时结束"
        val body = intent?.getStringExtra("body") ?: "本轮计时已结束"
        val notification = ReminderAlarm.buildAlertNotification(this, title, body)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                ReminderAlarm.ALERT_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE,
            )
        } else {
            startForeground(ReminderAlarm.ALERT_NOTIFICATION_ID, notification)
        }
        hasStartedAlert = true
        if (intent?.getBooleanExtra("play_sound", true) != false) startSound()
        handler.postDelayed(stopAlert, ReminderAlarm.MAX_ALERT_MILLIS)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(stopAlert)
        mediaPlayer?.runCatching { if (isPlaying) stop(); release() }
        mediaPlayer = null
        super.onDestroy()
    }

    private fun startSound() {
        val player = MediaPlayer()
        mediaPlayer = player
        try {
            val alarmFile = File(cacheDir, "chrona_alarm.mp3")
            assets.open("flutter_assets/assets/ring/ring.mp3").use { input ->
                alarmFile.outputStream().use { output -> input.copyTo(output) }
            }
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setWakeMode(applicationContext, android.os.PowerManager.PARTIAL_WAKE_LOCK)
            player.setDataSource(alarmFile.absolutePath)
            player.isLooping = false
            player.setOnCompletionListener { completedPlayer ->
                completedPlayer.release()
                if (mediaPlayer === completedPlayer) mediaPlayer = null
            }
            player.prepare()
            player.start()
        } catch (error: Exception) {
            player.runCatching { release() }
            if (mediaPlayer === player) mediaPlayer = null
            Log.e("CHRONA", "Could not play bundled timer sound", error)
        }
    }
}
