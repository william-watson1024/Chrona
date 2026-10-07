package com.chrona.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.chrona.app/direct_alarm",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("invalid_arguments", "Missing alarm data", null)
                    } else {
                        try {
                            DirectAlarm.schedule(
                                this,
                                (args["triggerAtMillis"] as Number).toLong(),
                                args["exact"] as Boolean,
                                args["playSound"] as Boolean,
                                args["enableVibration"] as Boolean,
                            )
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("schedule_failed", error.message, null)
                        }
                    }
                }

                "cancel" -> {
                    DirectAlarm.cancel(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}

