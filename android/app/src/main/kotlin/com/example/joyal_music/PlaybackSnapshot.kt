package com.example.joyal_music

import android.content.Intent

data class PlaybackSnapshot(
    val hasSong: Boolean,
    val songId: String?,
    val title: String?,
    val artist: String?,
    val album: String?,
    val coverArtId: String?,
    val coverArtPath: String?,
    val isPlaying: Boolean,
    val positionMs: Long,
    val durationMs: Long?,
    val currentIndex: Int,
    val playlistLength: Int,
) {
    companion object {
        fun fromMap(args: Map<*, *>): PlaybackSnapshot {
            fun number(name: String): Number? = args[name] as? Number
            return PlaybackSnapshot(
                hasSong = args["hasSong"] == true,
                songId = args["songId"] as? String,
                title = args["title"] as? String,
                artist = args["artist"] as? String,
                album = args["album"] as? String,
                coverArtId = args["coverArtId"] as? String,
                coverArtPath = args["coverArtPath"] as? String,
                isPlaying = args["isPlaying"] == true,
                positionMs = number("positionMs")?.toLong() ?: 0L,
                durationMs = number("durationMs")?.toLong(),
                currentIndex = number("currentIndex")?.toInt() ?: -1,
                playlistLength = number("playlistLength")?.toInt() ?: 0,
            )
        }

        fun fromIntent(intent: Intent): PlaybackSnapshot? {
            if (!intent.hasExtra("hasSong")) return null
            return PlaybackSnapshot(
                hasSong = intent.getBooleanExtra("hasSong", false),
                songId = intent.getStringExtra("songId"),
                title = intent.getStringExtra("title"),
                artist = intent.getStringExtra("artist"),
                album = intent.getStringExtra("album"),
                coverArtId = intent.getStringExtra("coverArtId"),
                coverArtPath = intent.getStringExtra("coverArtPath"),
                isPlaying = intent.getBooleanExtra("isPlaying", false),
                positionMs = intent.getLongExtra("positionMs", 0L),
                durationMs = if (intent.hasExtra("durationMs")) {
                    intent.getLongExtra("durationMs", 0L)
                } else {
                    null
                },
                currentIndex = intent.getIntExtra("currentIndex", -1),
                playlistLength = intent.getIntExtra("playlistLength", 0),
            )
        }
    }

    fun writeToIntent(intent: Intent) {
        intent.putExtra("hasSong", hasSong)
        intent.putExtra("songId", songId)
        intent.putExtra("title", title)
        intent.putExtra("artist", artist)
        intent.putExtra("album", album)
        intent.putExtra("coverArtId", coverArtId)
        intent.putExtra("coverArtPath", coverArtPath)
        intent.putExtra("isPlaying", isPlaying)
        intent.putExtra("positionMs", positionMs)
        durationMs?.let { intent.putExtra("durationMs", it) }
        intent.putExtra("currentIndex", currentIndex)
        intent.putExtra("playlistLength", playlistLength)
    }
}
