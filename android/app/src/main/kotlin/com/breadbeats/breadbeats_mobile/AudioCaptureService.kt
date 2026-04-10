package com.breadbeats.breadbeats_mobile

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Parcelable
import android.os.SystemClock
import kotlin.math.max
import kotlin.math.sqrt

class AudioCaptureService : Service() {

    private val captureLock = Any()

    @Volatile
    private var captureRunning: Boolean = false
    private var captureThread: Thread? = null
    private var audioRecord: AudioRecord? = null
    private var mediaProjection: MediaProjection? = null
    private var projectionCallback: MediaProjection.Callback? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_STOP_AND_RELEASE
        when (action) {
            ACTION_START -> {
                val startIntent = intent ?: return START_NOT_STICKY
                handleStart(startIntent)
            }

            ACTION_STOP -> {
                stopCapture(
                    reason = "stop_requested",
                    emitStoppedEvent = true,
                    stopService = false,
                    keepProjection = true,
                )
            }

            ACTION_STOP_AND_RELEASE -> {
                stopCapture(
                    reason = "projection_released",
                    emitStoppedEvent = true,
                    stopService = true,
                    keepProjection = false,
                )
            }
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopCapture(
            reason = "service_destroyed",
            emitStoppedEvent = true,
            stopService = false,
            keepProjection = false,
        )
        super.onDestroy()
    }

    private fun handleStart(startIntent: Intent) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            emitCaptureError(
                code = "api_not_supported",
                message = "Specific-app playback capture requires Android 10+ (API 29).",
            )
            stopCapture(
                "api_not_supported",
                emitStoppedEvent = false,
                stopService = true,
                keepProjection = false,
            )
            return
        }

        val appPackage = startIntent.getStringExtra(EXTRA_APP_PACKAGE)
        val appUid = startIntent.getIntExtra(EXTRA_APP_UID, -1)
        val projectionResultCode =
            startIntent.getIntExtra(EXTRA_PROJECTION_RESULT_CODE, Activity.RESULT_CANCELED)
        val projectionData =
            startIntent.getParcelableExtraCompat(EXTRA_PROJECTION_DATA, Intent::class.java)
        val requestedChannels =
            startIntent.getIntExtra(EXTRA_CHANNELS, DEFAULT_CHANNELS).coerceIn(1, 2)
        val hasRetainedProjection = synchronized(captureLock) {
            mediaProjection != null
        }

        if (appPackage.isNullOrBlank() || appUid <= 0) {
            emitCaptureError(
                code = "invalid_capture_target",
                message = "A valid app package and UID are required to start capture.",
            )
            stopCapture(
                "invalid_capture_target",
                emitStoppedEvent = false,
                stopService = true,
                keepProjection = false,
            )
            return
        }

        if (!hasRetainedProjection &&
            (projectionResultCode != Activity.RESULT_OK || projectionData == null)
        ) {
            emitCaptureError(
                code = "projection_invalid",
                message = "Projection consent data is missing or invalid.",
            )
            stopCapture(
                "projection_invalid",
                emitStoppedEvent = false,
                stopService = true,
                keepProjection = false,
            )
            return
        }

        stopCapture(
            reason = "capture_restart",
            emitStoppedEvent = false,
            stopService = false,
            keepProjection = true,
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(appPackage),
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
                )
            } else {
                startForeground(NOTIFICATION_ID, buildNotification(appPackage))
            }
        } catch (securityError: SecurityException) {
            emitCaptureError(
                code = "projection_permission_missing",
                message =
                    "Screen/audio capture permission expired. Grant projection permission again.",
                appPackage = appPackage,
            )
            MainActivity.emitCaptureEvent(mapOf("type" to "projectionDenied"))
            stopCapture(
                reason = "projection_permission_missing",
                emitStoppedEvent = false,
                stopService = true,
                keepProjection = false,
            )
            return
        }

        captureRunning = true
        val captureStart = CaptureStart(
            appPackage = appPackage,
            appUid = appUid,
            channels = requestedChannels,
            projectionResultCode = projectionResultCode,
            projectionData = projectionData,
        )

        val thread = Thread({ runCaptureLoop(captureStart) }, "breadbeats-audio-capture")
        captureThread = thread
        thread.start()
    }

    private fun runCaptureLoop(start: CaptureStart) {
        var stopReason = "capture_finished"

        try {
            val projection = synchronized(captureLock) {
                mediaProjection
            } ?: run {
                val projectionData = start.projectionData
                if (projectionData == null) {
                    null
                } else {
                    val projectionManager =
                        getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    projectionManager.getMediaProjection(start.projectionResultCode, projectionData)
                }
            }

            if (projection == null) {
                emitCaptureError(
                    code = "projection_unavailable",
                    message = "Failed to initialize MediaProjection.",
                    appPackage = start.appPackage,
                )
                stopReason = if (start.projectionData == null) {
                    "projection_invalid"
                } else {
                    "projection_unavailable"
                }
                return
            }

            var callback = synchronized(captureLock) {
                projectionCallback
            }
            if (callback == null) {
                callback = object : MediaProjection.Callback() {
                    override fun onStop() {
                        MainActivity.emitCaptureEvent(
                            mapOf(
                                "type" to "projectionRevoked",
                                "appPackage" to start.appPackage,
                            )
                        )
                        stopCapture(
                            reason = "projection_revoked",
                            emitStoppedEvent = true,
                            stopService = true,
                            keepProjection = false,
                        )
                    }
                }
                projection.registerCallback(callback, Handler(Looper.getMainLooper()))
                synchronized(captureLock) {
                    mediaProjection = projection
                    projectionCallback = callback
                }
            } else {
                synchronized(captureLock) {
                    mediaProjection = projection
                }
            }

            val captureConfig = AudioPlaybackCaptureConfiguration.Builder(projection)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .addMatchingUid(start.appUid)
                .build()

            val numChannels = if (start.channels >= 2) 2 else 1
            val channelMask =
                if (numChannels >= 2) AudioFormat.CHANNEL_IN_STEREO else AudioFormat.CHANNEL_IN_MONO

            val format = AudioFormat.Builder()
                .setSampleRate(SAMPLE_RATE_HZ)
                .setChannelMask(channelMask)
                .setEncoding(ENCODING)
                .build()

            val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE_HZ, channelMask, ENCODING)
            if (minBufferSize <= 0) {
                emitCaptureError(
                    code = "audio_buffer_error",
                    message = "AudioRecord minimum buffer size query failed.",
                    appPackage = start.appPackage,
                )
                stopReason = "audio_buffer_error"
                return
            }

            val record = AudioRecord.Builder()
                .setAudioFormat(format)
                .setBufferSizeInBytes(max(minBufferSize * 4, FRAME_SAMPLES * numChannels * 2 * 4))
                .setAudioPlaybackCaptureConfig(captureConfig)
                .build()

            if (record.state != AudioRecord.STATE_INITIALIZED) {
                emitCaptureError(
                    code = "audio_record_init_failed",
                    message = "AudioRecord failed to initialize for playback capture.",
                    appPackage = start.appPackage,
                )
                try {
                    record.release()
                } catch (_: Exception) {
                }
                stopReason = "audio_record_init_failed"
                return
            }

            synchronized(captureLock) {
                audioRecord = record
            }

            record.startRecording()

            MainActivity.emitCaptureEvent(
                mapOf(
                    "type" to "captureStarted",
                    "mode" to "specific_app",
                    "appPackage" to start.appPackage,
                    "appUid" to start.appUid,
                    "sampleRate" to SAMPLE_RATE_HZ,
                    "channels" to numChannels,
                    "encoding" to "pcm16",
                )
            )

            // Interleaved PCM: FRAME_SAMPLES * channel count.
            val totalSamplesPerRead = FRAME_SAMPLES * numChannels
            val sampleBuffer = ShortArray(totalSamplesPerRead)
            val bytesBuffer = ByteArray(totalSamplesPerRead * 2)

            var silenceDurationMs = 0L
            var sourceBlocked = false
            var lastFrameTimeMs = SystemClock.elapsedRealtime()

            while (captureRunning) {
                val read =
                    record.read(sampleBuffer, 0, sampleBuffer.size, AudioRecord.READ_BLOCKING)

                if (!captureRunning) {
                    break
                }

                if (read <= 0) {
                    if (read == AudioRecord.ERROR_DEAD_OBJECT) {
                        emitCaptureError(
                            code = "audio_dead_object",
                            message = "AudioRecord became unavailable during capture.",
                            appPackage = start.appPackage,
                        )
                        stopReason = "audio_dead_object"
                        break
                    }
                    continue
                }

                var sumSquaresL = 0.0
                var sumSquaresR = 0.0
                var sampleCountL = 0
                var sampleCountR = 0
                var byteIndex = 0
                for (i in 0 until read) {
                    val sample = sampleBuffer[i].toInt()
                    val normalized = sample / 32768.0
                    if (numChannels >= 2) {
                        if (i % 2 == 0) {
                            sumSquaresL += normalized * normalized
                            sampleCountL++
                        } else {
                            sumSquaresR += normalized * normalized
                            sampleCountR++
                        }
                    } else {
                        sumSquaresL += normalized * normalized
                        sampleCountL++
                    }
                    bytesBuffer[byteIndex++] = (sample and 0xFF).toByte()
                    bytesBuffer[byteIndex++] = ((sample shr 8) and 0xFF).toByte()
                }

                val rmsL = if (sampleCountL > 0) sqrt(sumSquaresL / sampleCountL).toFloat() else 0f
                val rmsR =
                    if (sampleCountR > 0) sqrt(sumSquaresR / sampleCountR).toFloat() else rmsL
                val rms =
                    if (numChannels >= 2) {
                        sqrt((sumSquaresL + sumSquaresR) / read.coerceAtLeast(1)).toFloat()
                    } else {
                        sqrt(sumSquaresL / read.coerceAtLeast(1)).toFloat()
                    }
                val nowMs = SystemClock.elapsedRealtime()
                val deltaMs = (nowMs - lastFrameTimeMs).coerceAtLeast(0L)
                lastFrameTimeMs = nowMs

                if (rms < BLOCKED_RMS_THRESHOLD) {
                    silenceDurationMs += deltaMs
                    if (!sourceBlocked && silenceDurationMs >= BLOCKED_DETECTION_MS) {
                        sourceBlocked = true
                        MainActivity.emitCaptureEvent(
                            mapOf(
                                "type" to "captureSourceBlocked",
                                "appPackage" to start.appPackage,
                                "appUid" to start.appUid,
                                "reason" to
                                    "Selected app may block playback capture or currently emits silence. Choose another app.",
                            )
                        )
                    }
                } else if (rms >= ACTIVE_RMS_THRESHOLD) {
                    silenceDurationMs = 0L
                    if (sourceBlocked) {
                        sourceBlocked = false
                        MainActivity.emitCaptureEvent(
                            mapOf(
                                "type" to "captureSourceActive",
                                "appPackage" to start.appPackage,
                                "appUid" to start.appUid,
                            )
                        )
                    }
                } else {
                    silenceDurationMs = 0L
                }

                // frameSamples = per-channel frame count.
                val frameSamplesPerChannel = read / numChannels
                MainActivity.emitCaptureEvent(
                    mapOf(
                        "type" to "pcm16",
                        "appPackage" to start.appPackage,
                        "appUid" to start.appUid,
                        "sampleRate" to SAMPLE_RATE_HZ,
                        "channels" to numChannels,
                        "frameSamples" to frameSamplesPerChannel,
                        "rms" to rms,
                        "rmsLeft" to rmsL,
                        "rmsRight" to rmsR,
                        "data" to bytesBuffer,
                    )
                )
            }
        } catch (error: Exception) {
            emitCaptureError(
                code = "capture_loop_exception",
                message = error.message ?: "Capture loop failed unexpectedly.",
                appPackage = start.appPackage,
            )
            stopReason = "capture_loop_exception"
        } finally {
            if (captureThread !== Thread.currentThread()) {
                return
            }
            stopCapture(
                reason = stopReason,
                emitStoppedEvent = true,
                stopService = true,
                keepProjection = false,
            )
        }
    }

    private fun stopCapture(
        reason: String,
        emitStoppedEvent: Boolean,
        stopService: Boolean,
        keepProjection: Boolean,
    ) {
        val wasRunning = captureRunning
        captureRunning = false

        val threadToInterrupt = captureThread
        captureThread = null
        threadToInterrupt?.interrupt()

        cleanupCaptureResources(keepProjection = keepProjection)
        if (!keepProjection) {
            stopForegroundCompat()
        }

        if (emitStoppedEvent && wasRunning) {
            MainActivity.emitCaptureEvent(
                mapOf(
                    "type" to "captureStopped",
                    "reason" to reason,
                )
            )
        }

        if (stopService && !keepProjection) {
            stopSelf()
        }
    }

    private fun cleanupCaptureResources(keepProjection: Boolean) {
        synchronized(captureLock) {
            val localRecord = audioRecord
            audioRecord = null
            if (localRecord != null) {
                try {
                    if (localRecord.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                        localRecord.stop()
                    }
                } catch (_: Exception) {
                }
                try {
                    localRecord.release()
                } catch (_: Exception) {
                }
            }

            if (keepProjection) {
                return@synchronized
            }

            val localProjection = mediaProjection
            val localCallback = projectionCallback
            mediaProjection = null
            projectionCallback = null

            if (localProjection != null && localCallback != null) {
                try {
                    localProjection.unregisterCallback(localCallback)
                } catch (_: Exception) {
                }
            }

            if (localProjection != null) {
                try {
                    localProjection.stop()
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun emitCaptureError(code: String, message: String, appPackage: String? = null) {
        MainActivity.emitCaptureEvent(
            mapOf(
                "type" to "captureError",
                "code" to code,
                "message" to message,
                "appPackage" to (appPackage ?: ""),
            )
        )
    }

    private fun buildNotification(appPackage: String?): Notification {
        createNotificationChannel()

        val launchIntent =
            packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val detail = "Listening to app: ${appPackage ?: "unknown"}"

        return Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("bREadbeats Mobile Audio Capture")
            .setContentText(detail)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Audio Capture",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Foreground capture for bREadbeats Mobile"
        manager.createNotificationChannel(channel)
    }

    private fun <T : Parcelable> Intent.getParcelableExtraCompat(key: String, clazz: Class<T>): T? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(key, clazz)
        } else {
            @Suppress("DEPRECATION")
            getParcelableExtra(key) as? T
        }
    }

    private data class CaptureStart(
        val appPackage: String,
        val appUid: Int,
        val channels: Int,
        val projectionResultCode: Int,
        val projectionData: Intent?,
    )

    companion object {
        const val ACTION_START = "com.breadbeats.breadbeats_mobile.capture.START"
        const val ACTION_STOP = "com.breadbeats.breadbeats_mobile.capture.STOP"
        const val ACTION_STOP_AND_RELEASE =
            "com.breadbeats.breadbeats_mobile.capture.STOP_AND_RELEASE"

        const val EXTRA_APP_PACKAGE = "appPackage"
        const val EXTRA_APP_UID = "appUid"
        const val EXTRA_CHANNELS = "channels"
        const val EXTRA_PROJECTION_RESULT_CODE = "projectionResultCode"
        const val EXTRA_PROJECTION_DATA = "projectionData"

        private const val NOTIFICATION_CHANNEL_ID = "breadbeats_audio_capture"
        private const val NOTIFICATION_ID = 44021
        private const val SAMPLE_RATE_HZ = 48_000
        private const val DEFAULT_CHANNELS = 2
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
        private const val FRAME_SAMPLES = 1024  // per channel
        private const val BLOCKED_RMS_THRESHOLD = 0.01f
        private const val ACTIVE_RMS_THRESHOLD = 0.02f
        private const val BLOCKED_DETECTION_MS = 2500L

        fun buildStartIntent(
            context: Context,
            appPackage: String?,
            appUid: Int,
            channels: Int,
            projectionResultCode: Int,
            projectionData: Intent?,
        ): Intent {
            val safeChannels = if (channels >= 2) 2 else 1
            return Intent(context, AudioCaptureService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_APP_PACKAGE, appPackage)
                putExtra(EXTRA_APP_UID, appUid)
                putExtra(EXTRA_CHANNELS, safeChannels)
                putExtra(EXTRA_PROJECTION_RESULT_CODE, projectionResultCode)
                putExtra(EXTRA_PROJECTION_DATA, projectionData)
            }
        }

        fun buildStopIntent(context: Context): Intent {
            return Intent(context, AudioCaptureService::class.java).apply {
                action = ACTION_STOP
            }
        }

        fun buildStopAndReleaseIntent(context: Context): Intent {
            return Intent(context, AudioCaptureService::class.java).apply {
                action = ACTION_STOP_AND_RELEASE
            }
        }
    }
}
