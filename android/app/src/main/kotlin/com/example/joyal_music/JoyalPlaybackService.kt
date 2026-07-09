package com.example.joyal_music

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

class JoyalPlaybackService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_UPDATE -> {
                val snapshot = PlaybackSnapshot.fromIntent(intent)
                if (snapshot == null || !snapshot.hasSong) {
                    stopPlaybackService()
                    START_NOT_STICKY
                } else {
                    syncWakeLock(snapshot.isPlaying)
                    startPlaybackForeground(snapshot)
                    START_STICKY
                }
            }
            ACTION_STOP -> {
                stopPlaybackService()
                START_NOT_STICKY
            }
            else -> START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun startPlaybackForeground(snapshot: PlaybackSnapshot) {
        val notification = buildNotification(snapshot)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(snapshot: PlaybackSnapshot): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val title = snapshot.title?.takeIf { it.isNotBlank() } ?: "Joyal"
        val artist = snapshot.artist?.takeIf { it.isNotBlank() }
        val album = snapshot.album?.takeIf { it.isNotBlank() }

        builder
            .setSmallIcon(R.drawable.ic_stat_music_note)
            .setContentTitle(title)
            .setContentText(artist ?: album ?: "Playing")
            .setSubText(album)
            .setContentIntent(launchPendingIntent())
            .setOngoing(snapshot.isPlaying)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setLocalOnly(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }

        snapshot.coverArtPath?.let { path ->
            try {
                builder.setLargeIcon(BitmapFactory.decodeFile(path))
            } catch (error: Exception) {
                Log.w(TAG, "Failed to decode notification artwork: $path", error)
            }
        }

        return builder.build()
    }

    private fun launchPendingIntent(): PendingIntent? {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            ?: return null
        return PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            pendingIntentFlags(),
        )
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Joyal playback",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps Joyal playback active while the screen is locked"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun syncWakeLock(playing: Boolean) {
        if (!playing) {
            releaseWakeLock()
            return
        }
        val lock = wakeLock ?: newWakeLock().also { wakeLock = it }
        lock.acquire(WAKE_LOCK_TIMEOUT_MS)
    }

    private fun newWakeLock(): PowerManager.WakeLock {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "JoyalMusic:Playback")
            .apply { setReferenceCounted(false) }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (error: RuntimeException) {
            Log.w(TAG, "Failed to release playback wake lock", error)
        }
    }

    private fun stopPlaybackService() {
        releaseWakeLock()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun pendingIntentFlags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }

    companion object {
        private const val TAG = "JoyalPlaybackService"
        private const val CHANNEL_ID = "joyal_playback"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_UPDATE = "com.example.joyal_music.PLAYBACK_UPDATE"
        private const val ACTION_STOP = "com.example.joyal_music.PLAYBACK_STOP"
        private const val WAKE_LOCK_TIMEOUT_MS = 20L * 60L * 1000L

        fun update(context: Context, snapshot: PlaybackSnapshot) {
            val appContext = context.applicationContext
            val intent = Intent(appContext, JoyalPlaybackService::class.java).apply {
                action = ACTION_UPDATE
                snapshot.writeToIntent(this)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appContext.startForegroundService(intent)
            } else {
                appContext.startService(intent)
            }
        }

        fun stop(context: Context) {
            val appContext = context.applicationContext
            appContext.stopService(Intent(appContext, JoyalPlaybackService::class.java))
        }
    }
}
