package com.example.joyal_music

import android.content.Context
import android.util.Log

class OppoFluidCloudBridge(private val context: Context) {
    fun isAvailable(): Boolean = false

    fun updatePlaybackState(snapshot: PlaybackSnapshot) {
        if (!isAvailable()) return
        Log.d("OppoFluidCloud", "OPPO Fluid Cloud SDK unavailable for ${snapshot.songId}")
    }

    fun clear() {
        if (!isAvailable()) return
        Log.d("OppoFluidCloud", "OPPO Fluid Cloud SDK unavailable for clear")
    }
}
