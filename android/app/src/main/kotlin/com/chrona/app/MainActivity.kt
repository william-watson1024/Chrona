package com.chrona.app

import android.view.KeyEvent
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chrona.app/reminder_alarm",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("invalid_arguments", "Missing alarm data", null)
                    } else {
                        try {
                            val usedExact = ReminderAlarm.schedule(
                                this,
                                args["title"] as String,
                                args["body"] as String,
                                args["timerTitle"] as String,
                                args["timerBody"] as String,
                                (args["triggerAtMillis"] as Number).toLong(),
                                args["playSound"] as Boolean,
                                args["vibrate"] as Boolean,
                                args["exact"] as Boolean,
                            )
                            if (!usedExact && args["promptOnFallback"] == true) {
                                Toast.makeText(
                                    this,
                                    "系统未授权精确闹钟，结束提醒可能延迟",
                                    Toast.LENGTH_LONG,
                                ).show()
                            }
                            result.success(usedExact)
                        } catch (error: Exception) {
                            result.error("schedule_failed", error.message, null)
                        }
                    }
                }
                "cancel", "stop" -> {
                    ReminderAlarm.cancel(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) &&
            ReminderAlarm.isAlerting(this)
        ) {
            // Stop CHRONA's active alert while preserving normal volume-key behavior.
            ReminderAlarm.cancel(this)
        }
        return super.dispatchKeyEvent(event)
    }
}
