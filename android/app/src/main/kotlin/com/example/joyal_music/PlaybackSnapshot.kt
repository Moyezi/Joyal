package com.example.joyal_music

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
    }
}
