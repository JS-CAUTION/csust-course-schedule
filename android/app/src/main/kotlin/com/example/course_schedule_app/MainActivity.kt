package com.example.course_schedule_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val launchChannel = "com.example.course_schedule_app/launch"
    private val alarmChannel = "com.example.course_schedule_app/alarm"
    private val serviceChannel = "com.example.course_schedule_app/service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, launchChannel).setMethodCallHandler { call, result ->
            if (call.method == "bringToForeground") {
                moveTaskToBack(false)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmChannel).setMethodCallHandler { call, result ->
            if (call.method == "fireImmediate") {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any> ?: run {
                    result.error("ARGS_ERROR", "arguments is not a Map", null)
                    return@setMethodCallHandler
                }
                val notifyId = (args["notifyId"] as? Number)?.toInt() ?: 0
                val title = args["title"] as? String ?: "通知"
                val body = args["body"] as? String ?: ""
                val channelId = args["channelId"] as? String ?: "course_ongoing"
                val channelName = args["channelName"] as? String ?: "上课常驻"
                val channelDesc = args["channelDesc"] as? String ?: ""
                // "reminder" | "ongoing" | "dismiss" — 未知值一律降级为 "ongoing"
                // （常驻优先：宁可划不掉，也不能让正在上课的提醒被误划掉）。
                val rawType = args["type"] as? String
                val type = if (rawType == "reminder" || rawType == "dismiss") rawType else "ongoing"
                // 时间区间后缀，如 "8:00~9:40"；为空则不加。
                val durationText = args["durationText"] as? String ?: ""

                val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val ch = android.app.NotificationChannel(
                    channelId, channelName, NotificationManager.IMPORTANCE_LOW
                ).apply { description = channelDesc }
                mgr.createNotificationChannel(ch)

                val largeIcon = Icon.createWithResource(packageName, R.mipmap.ic_launcher)

                val contentText =
                    if (durationText.isEmpty()) body else "$body · $durationText"

                val notification = NotificationCompat.Builder(this, channelId)
                    .setSmallIcon(R.mipmap.ic_launcher)

                    .setLargeIcon(largeIcon)
                    .setContentTitle(title)
                    .setContentText(contentText)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    // 只有「上课中」常驻；「课程提醒」可左右划掉。
                    .setOngoing(type == "ongoing")
                    .setAutoCancel(type != "ongoing")
                    .setSilent(type != "reminder")
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setCategory(NotificationCompat.CATEGORY_SERVICE)
                    .build()
                mgr.notify(notifyId, notification)
                result.success(null)
            } else if (call.method == "cancelNotification") {
                val notifyId = (call.arguments as? Map<*, *>)?.get("notifyId") as? Number
                if (notifyId != null) {
                    val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    mgr.cancel(notifyId.toInt())
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, serviceChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val intent = Intent(this, CourseForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopForegroundService" -> {
                    val intent = Intent(this, CourseForegroundService::class.java).apply {
                        action = CourseForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        stopService(Intent(this, CourseForegroundService::class.java))
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
