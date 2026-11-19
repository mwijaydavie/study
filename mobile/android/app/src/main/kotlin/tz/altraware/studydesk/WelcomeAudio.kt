package tz.altraware.studydesk

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build

/** A short, bundled media clip; no network, speaker override or service. */
internal class WelcomeAudio(private val context: Context) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()
    private val onFocusChange = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) stop()
    }
    private var focusRequest: AudioFocusRequest? = null
    private var hasFocus = false
    private var player: MediaPlayer? = null
    var foreground = false
        set(value) {
            field = value
            if (!value) stop()
        }

    fun play(clip: String?): Boolean {
        val resource = when (clip) {
            "karibu" -> R.raw.welcome_karibu
            "mambo" -> R.raw.welcome_mambo
            "welcome" -> R.raw.welcome_welcome
            "inakuaje" -> R.raw.welcome_inakuaje
            "tujipime" -> R.raw.welcome_tujipime
            else -> return false
        }
        if (!foreground || player != null || audio.isMusicActive ||
            audio.ringerMode != AudioManager.RINGER_MODE_NORMAL ||
            audio.getStreamVolume(AudioManager.STREAM_MUSIC) == 0
        ) return false

        return try {
            if (!requestFocus()) return false
            val next = MediaPlayer()
            player = next
            val file = context.resources.openRawResourceFd(resource)
                ?: throw IllegalStateException("The welcome clip must be an uncompressed raw resource.")
            file.use { asset ->
                next.setDataSource(asset.fileDescriptor, asset.startOffset, asset.length)
            }
            next.setAudioAttributes(attributes)
            next.setOnPreparedListener { ready ->
                if (player === ready && foreground) {
                    try {
                        ready.start()
                    } catch (_: IllegalStateException) {
                        stop()
                    }
                }
            }
            next.setOnCompletionListener { complete -> if (player === complete) stop() }
            next.setOnErrorListener { failed, _, _ ->
                if (player === failed) stop()
                true
            }
            next.prepareAsync()
            true
        } catch (_: Exception) {
            stop()
            false
        }
    }

    @Suppress("DEPRECATION") // Android 21–25 use the older audio focus API.
    private fun requestFocus(): Boolean {
        val result = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(onFocusChange)
                .build()
            focusRequest = request
            audio.requestAudioFocus(request)
        } else {
            audio.requestAudioFocus(onFocusChange, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
        hasFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        if (!hasFocus) focusRequest = null
        return hasFocus
    }

    @Suppress("DEPRECATION")
    fun stop() {
        val previous = player
        player = null
        previous?.release()
        if (hasFocus) {
            hasFocus = false
            if (Build.VERSION.SDK_INT >= 26) {
                val request = focusRequest
                focusRequest = null
                if (request != null) audio.abandonAudioFocusRequest(request)
            } else {
                audio.abandonAudioFocus(onFocusChange)
            }
        }
    }
}
