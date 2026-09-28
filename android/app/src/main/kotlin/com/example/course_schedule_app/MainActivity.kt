package com.example.course_schedule_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val launchChannel = "com.example.course_schedule_app/launch"
    private val serviceChannel = "com.example.course_schedule_app/service"

    /**
     * The status notification is the app's only reminder, so the permission
     * must be requested. This used to come from flutter_local_notifications;
     * that dependency was removed with the per-course notifications, so the
     * request lives here now — asking is a permission call, not a notification
     * feature, and doing it natively avoids restoring a plugin for one line.
     *
     * Android only applies POST_NOTIFICATIONS from API 33.
     */
    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Asked here rather than from the service: the activity is resumed, so
        // the system shows the dialog instead of silently denying it.
        requestNotificationPermissionIfNeeded()
    }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, serviceChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                // Doubles as the "update the status text" entry point: the
                // service re-runs startForeground on the same NOTIFY_ID, which
                // replaces the text in place. Keeping one path means there is no
                // separate "service not running yet" state to handle here.
                "startForegroundService" -> {
                    val body = (call.arguments as? Map<*, *>)?.get("body") as? String
                    val intent = Intent(this, CourseForegroundService::class.java).apply {
                        if (body != null) putExtra(CourseForegroundService.EXTRA_BODY, body)
                    }
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

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 1001
    }
}
