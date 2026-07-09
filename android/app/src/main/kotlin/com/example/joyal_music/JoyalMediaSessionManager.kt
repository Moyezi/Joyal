package com.example.joyal_music

import android.content.Context
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.Uri
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.File

class JoyalMediaSessionManager(
    context: Context,
    private val controlChannel: MethodChannel,
    private val oppoBridge: OppoFluidCloudBridge = OppoFluidCloudBridge(context.applicationContext),
) {
    private val appContext = context.applicationContext
    private var foregroundServiceStarted = false
    private val mediaSession = MediaSession(appContext, "JoyalMusicSession").apply {
        setCallback(object : MediaSession.Callback() {
            override fun onPlay() = sendControl("togglePlayPause")
            override fun onPause() = sendControl("togglePlayPause")
            override fun onSkipToNext() = sendControl("next")
            override fun onSkipToPrevious() = sendControl("previous")
            override fun onStop() = clear()
        })
        setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS)
        isActive = true
    }

    fun update(snapshot: PlaybackSnapshot) {
        if (!snapshot.hasSong) {
            clear()
            return
        }

        val metadata = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_MEDIA_ID, snapshot.songId)
            .putString(MediaMetadata.METADATA_KEY_TITLE, snapshot.title ?: "")
            .putString(MediaMetadata.METADATA_KEY_ARTIST, snapshot.artist ?: "")
            .putString(MediaMetadata.METADATA_KEY_ALBUM, snapshot.album ?: "")
            .apply {
                albumArtUri(snapshot.coverArtPath)?.let { uri ->
                    putString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI, uri.toString())
                }
                loadAlbumArt(snapshot.coverArtPath)?.let { bitmap ->
                    putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, bitmap)
                    putBitmap(MediaMetadata.METADATA_KEY_ART, bitmap)
                }
                snapshot.durationMs?.let {
                    putLong(MediaMetadata.METADATA_KEY_DURATION, it)
                }
            }
            .build()

        val state = PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY or
                    PlaybackState.ACTION_PAUSE or
                    PlaybackState.ACTION_PLAY_PAUSE or
                    PlaybackState.ACTION_SKIP_TO_NEXT or
                    PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackState.ACTION_STOP,
            )
            .setState(
                if (snapshot.isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                snapshot.positionMs,
                if (snapshot.isPlaying) 1.0f else 0.0f,
            )
            .build()

        mediaSession.setMetadata(metadata)
        mediaSession.setPlaybackState(state)
        mediaSession.isActive = true
        oppoBridge.updatePlaybackState(snapshot)
        syncForegroundService(snapshot)
    }

    fun clear() {
        mediaSession.setMetadata(null)
        mediaSession.setPlaybackState(
            PlaybackState.Builder()
                .setState(PlaybackState.STATE_STOPPED, 0L, 0.0f)
                .build(),
        )
        oppoBridge.clear()
        stopForegroundService()
    }

    fun release() {
        clear()
        mediaSession.release()
    }

    private fun sendControl(action: String) {
        try {
            controlChannel.invokeMethod("mediaControl", action)
        } catch (error: Exception) {
            Log.w("JoyalMediaSession", "Failed to send media control: $action", error)
        }
    }

    private fun syncForegroundService(snapshot: PlaybackSnapshot) {
        if (!snapshot.isPlaying && !foregroundServiceStarted) return
        try {
            JoyalPlaybackService.update(appContext, snapshot)
            foregroundServiceStarted = true
        } catch (error: Exception) {
            Log.w("JoyalMediaSession", "Failed to update playback foreground service", error)
        }
    }

    private fun stopForegroundService() {
        foregroundServiceStarted = false
        try {
            JoyalPlaybackService.stop(appContext)
        } catch (error: Exception) {
            Log.w("JoyalMediaSession", "Failed to stop playback foreground service", error)
        }
    }

    private fun loadAlbumArt(path: String?) = try {
        albumArtFile(path)?.let { BitmapFactory.decodeFile(it.path) }
    } catch (error: Exception) {
        Log.w("JoyalMediaSession", "Failed to decode album art: $path", error)
        null
    }

    private fun albumArtUri(path: String?): Uri? = albumArtFile(path)?.let { Uri.fromFile(it) }

    private fun albumArtFile(path: String?): File? {
        if (path.isNullOrBlank()) return null
        val file = File(path)
        return if (file.isFile) file else null
    }
}
