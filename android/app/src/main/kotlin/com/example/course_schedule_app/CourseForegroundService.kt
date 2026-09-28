package com.example.course_schedule_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the app alive in the background and owns the
 * persistent course-status notification.
 *
 * The status text is computed in Dart (see foreground_status.dart) and handed
 * over through the start intent; this service stays deliberately dumb and only
 * renders it. Re-calling startForeground with the same NOTIFY_ID updates the
 * existing notification in place instead of stacking a second one.
 */
class CourseForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "course_service"
        const val NOTIFY_ID = 9000
        const val ACTION_STOP = "com.example.course_schedule_app.STOP_SERVICE"

        const val EXTRA_BODY = "bodyText"

        /** Used when Android restarts the service with a null intent. */
        const val DEFAULT_BODY = "流转"
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "课程服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "显示今日课程状态，保持后台更新"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        // A START_STICKY restart delivers a null intent, so fall back rather
        // than rendering an empty notification.
        val body = intent?.getStringExtra(EXTRA_BODY) ?: DEFAULT_BODY

        startForeground(NOTIFY_ID, buildForegroundNotification(body))
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildForegroundNotification(body: String): android.app.Notification {
        val appInfo = packageManager.getApplicationInfo(packageName, 0)
        val appLabel = packageManager.getApplicationLabel(appInfo)

        // Tapping the status should open the app. MainActivity is singleTop, so
        // an existing instance is reused instead of a second one being stacked.
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val bmp = BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            // small icon 必须是纯白剪影，不能用彩色 launcher 位图。
            .setSmallIcon(R.drawable.ic_stat_course)
            .setLargeIcon(bmp)
            .setContentTitle(appLabel)
            .setContentText(body)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
