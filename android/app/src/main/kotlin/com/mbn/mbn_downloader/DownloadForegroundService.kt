package com.mbn.dl

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlinx.coroutines.*
import java.net.URL

class DownloadForegroundService : Service() {
    companion object {
        private const val TAG = "DownloadService"
        private const val CHANNEL_ID = "download_channel"
        private const val NOTIFICATION_ID = 1001

        private var wakeLock: PowerManager.WakeLock? = null
        private var isServiceRunning = false
        private var currentDownloads = mutableMapOf<String, DownloadInfo>()

        fun startService(context: Context, downloadId: String, title: String, thumbnailUrl: String?) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = "START_DOWNLOAD"
                putExtra("downloadId", downloadId)
                putExtra("title", title)
                putExtra("thumbnailUrl", thumbnailUrl)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun updateProgress(context: Context, downloadId: String, progress: Double) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = "UPDATE_PROGRESS"
                putExtra("downloadId", downloadId)
                putExtra("progress", progress)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun completeDownload(context: Context, downloadId: String, success: Boolean) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = "COMPLETE_DOWNLOAD"
                putExtra("downloadId", downloadId)
                putExtra("success", success)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private data class DownloadInfo(
        val id: String,
        val title: String,
        val thumbnailUrl: String?,
        var progress: Double = 0.0,
        var thumbnail: Bitmap? = null,
        var isCompleted: Boolean = false,
        var isSuccess: Boolean = false
    )

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
        isServiceRunning = true
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_DOWNLOAD" -> {
                val downloadId = intent.getStringExtra("downloadId") ?: return START_NOT_STICKY
                val title = intent.getStringExtra("title") ?: "Downloading..."
                val thumbnailUrl = intent.getStringExtra("thumbnailUrl")

                val downloadInfo = DownloadInfo(downloadId, title, thumbnailUrl)
                currentDownloads[downloadId] = downloadInfo

                // Load thumbnail asynchronously
                if (thumbnailUrl != null) {
                    scope.launch(Dispatchers.IO) {
                        try {
                            val url = URL(thumbnailUrl)
                            val bitmap = BitmapFactory.decodeStream(url.openStream())
                            downloadInfo.thumbnail = bitmap
                            withContext(Dispatchers.Main) {
                                updateNotification()
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to load thumbnail", e)
                        }
                    }
                }

                startForeground(NOTIFICATION_ID, buildNotification())
            }

            "UPDATE_PROGRESS" -> {
                val downloadId = intent.getStringExtra("downloadId") ?: return START_NOT_STICKY
                val progress = intent.getDoubleExtra("progress", 0.0)

                currentDownloads[downloadId]?.apply {
                    this.progress = progress
                    updateNotification()
                }
            }

            "COMPLETE_DOWNLOAD" -> {
                val downloadId = intent.getStringExtra("downloadId") ?: return START_NOT_STICKY
                val success = intent.getBooleanExtra("success", false)

                currentDownloads[downloadId]?.apply {
                    isCompleted = true
                    isSuccess = success
                    progress = if (success) 100.0 else progress
                    updateNotification()

                    // Remove after delay
                    scope.launch {
                        delay(5000)
                        currentDownloads.remove(downloadId)
                        if (currentDownloads.isEmpty()) {
                            stopSelfAndRelease()
                        } else {
                            updateNotification()
                        }
                    }
                }
            }
        }

        return START_STICKY
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "DownloadService::WakeLock"
        ).apply {
            acquire(6 * 60 * 60 * 1000L) // Android's data-sync FGS time window
        }
        Log.d(TAG, "WakeLock acquired")
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "WakeLock released")
            }
        }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Downloads",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Download progress notifications"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(true)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val activeDownload = currentDownloads.values.firstOrNull { !it.isCompleted }
            ?: currentDownloads.values.firstOrNull()
            ?: return buildEmptyNotification()

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(!activeDownload.isCompleted)
            .setOnlyAlertOnce(true)
            .setAutoCancel(activeDownload.isCompleted)

        if (activeDownload.isCompleted) {
            // Completed notification with modern design
            val title = if (activeDownload.isSuccess) "Download complete" else "Download failed"
            val color = if (activeDownload.isSuccess) 0xFF4CAF50.toInt() else 0xFFF44336.toInt()

            builder.setContentTitle(title)
            builder.setContentText(activeDownload.title)
            builder.setSmallIcon(
                if (activeDownload.isSuccess)
                    android.R.drawable.stat_sys_download_done
                else
                    android.R.drawable.stat_notify_error
            )
            builder.setColor(color)
            builder.setOngoing(false)

            if (activeDownload.thumbnail != null) {
                builder.setLargeIcon(activeDownload.thumbnail)
                builder.setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(activeDownload.thumbnail)
                        .bigLargeIcon(null as Bitmap?)
                        .setBigContentTitle(title)
                        .setSummaryText(activeDownload.title)
                )
            } else {
                builder.setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText(activeDownload.title)
                        .setBigContentTitle(title)
                )
            }
        } else {
            // In-progress notification with modern design
            val progress = activeDownload.progress.toInt()
            val progressText = if (progress >= 0) "$progress%" else "Starting..."

            builder.setContentTitle(activeDownload.title)
            builder.setContentText("Downloading · $progressText")
            builder.setProgress(100, maxOf(0, progress), progress < 0)
            builder.setSubText(progressText)
            builder.setColor(0xFF2196F3.toInt()) // Blue color

            if (activeDownload.thumbnail != null) {
                builder.setLargeIcon(activeDownload.thumbnail)
                builder.setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText("Downloading · $progressText")
                        .setBigContentTitle(activeDownload.title)
                )
            }
        }

        // Add download count if multiple
        if (currentDownloads.size > 1) {
            val inProgressCount = currentDownloads.values.count { !it.isCompleted }
            if (inProgressCount > 1) {
                builder.setSubText("$inProgressCount downloads")
            }
        }

        return builder.build()
    }

    private fun buildEmptyNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Download Service")
            .setContentText("Ready to download")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .build()
    }

    private fun updateNotification() {
        try {
            val notification = buildNotification()
            val notificationManager = NotificationManagerCompat.from(this)
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update notification", e)
        }
    }

    private fun stopSelfAndRelease() {
        releaseWakeLock()
        isServiceRunning = false
        stopForeground(true)
        stopSelf()
        Log.d(TAG, "Service stopped")
    }

    override fun onDestroy() {
        super.onDestroy()
        releaseWakeLock()
        scope.cancel()
        currentDownloads.clear()
        isServiceRunning = false
        Log.d(TAG, "Service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
