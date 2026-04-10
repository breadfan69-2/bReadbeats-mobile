package com.breadbeats.breadbeats_mobile

import android.app.Activity
import android.content.Intent
import android.media.AudioManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

	private var pendingProjectionResult: MethodChannel.Result? = null
	private var projectionResultCode: Int = Activity.RESULT_CANCELED
	private var projectionData: Intent? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			CHANNEL_CAPTURE_METHODS,
		).setMethodCallHandler { call, result ->
			when (call.method) {
				METHOD_LIST_CAPTURABLE_APPS -> listCapturableApps(result)
				METHOD_REQUEST_PROJECTION -> requestProjectionConsent(result)
				METHOD_START_CAPTURE -> startCapture(call, result)
				METHOD_STOP_CAPTURE -> stopCapture(result)
				METHOD_STOP_CAPTURE_AND_RELEASE ->
					stopCaptureAndReleaseProjection(result)
				else -> result.notImplemented()
			}
		}

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			CHANNEL_MEDIA_METHODS,
		).setMethodCallHandler { call, result ->
			when (call.method) {
				METHOD_MEDIA_PREV -> handleMediaControl(KeyEvent.KEYCODE_MEDIA_PREVIOUS, result)
				METHOD_MEDIA_PLAY_PAUSE -> handleMediaControl(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, result)
				METHOD_MEDIA_NEXT -> handleMediaControl(KeyEvent.KEYCODE_MEDIA_NEXT, result)
				METHOD_MEDIA_IS_PLAYING -> result.success(
					(getSystemService(AUDIO_SERVICE) as AudioManager).isMusicActive
				)
				else -> result.notImplemented()
			}
		}

		EventChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			CHANNEL_CAPTURE_EVENTS,
		).setStreamHandler(object : EventChannel.StreamHandler {
			override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
				captureEventSink = events
			}

			override fun onCancel(arguments: Any?) {
				if (captureEventSink != null) {
					captureEventSink = null
				}
			}
		})
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)

		if (requestCode != REQUEST_MEDIA_PROJECTION) {
			return
		}

		val pending = pendingProjectionResult
		pendingProjectionResult = null

		if (pending == null) {
			return
		}

		if (resultCode == Activity.RESULT_OK && data != null) {
			projectionResultCode = resultCode
			projectionData = data
			pending.success(true)
			emitCaptureEvent(mapOf("type" to "projectionGranted"))
			captureEventHandler.postDelayed({ bringAppToForeground() }, 120)
		} else {
			projectionResultCode = Activity.RESULT_CANCELED
			projectionData = null
			pending.success(false)
			emitCaptureEvent(mapOf("type" to "projectionDenied"))
		}
	}

	private fun bringAppToForeground() {
		val launchIntent =
			packageManager.getLaunchIntentForPackage(packageName)
				?: Intent(this, MainActivity::class.java)
		launchIntent.addFlags(
			Intent.FLAG_ACTIVITY_NEW_TASK or
				Intent.FLAG_ACTIVITY_SINGLE_TOP or
				Intent.FLAG_ACTIVITY_CLEAR_TOP or
				Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
		)
		runCatching {
			startActivity(launchIntent)
		}
	}

	private fun listCapturableApps(result: MethodChannel.Result) {
		val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
			addCategory(Intent.CATEGORY_LAUNCHER)
		}

		val resolveInfoList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			packageManager.queryIntentActivities(
				launcherIntent,
				android.content.pm.PackageManager.ResolveInfoFlags.of(0L),
			)
		} else {
			@Suppress("DEPRECATION")
			packageManager.queryIntentActivities(launcherIntent, 0)
		}

		val byPackage = linkedMapOf<String, Map<String, Any>>()

		for (resolveInfo in resolveInfoList) {
			val activityInfo = resolveInfo.activityInfo ?: continue
			val appInfo = activityInfo.applicationInfo ?: continue
			val appPackageName = appInfo.packageName ?: continue

			if (appPackageName == this.packageName) {
				continue
			}

			val appLabel = packageManager.getApplicationLabel(appInfo).toString()
			byPackage[appPackageName] = mapOf(
				"packageName" to appPackageName,
				"appName" to appLabel,
				"uid" to appInfo.uid,
			)
		}

		val sorted = byPackage.values.sortedBy { (it["appName"] ?: "").toString().lowercase() }
		result.success(sorted)
	}

	private fun requestProjectionConsent(result: MethodChannel.Result) {
		if (
			Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
				projectionData != null &&
				projectionResultCode == Activity.RESULT_OK
		) {
			result.success(true)
			emitCaptureEvent(mapOf("type" to "projectionGranted"))
			return
		}

		if (pendingProjectionResult != null) {
			result.error(
				"projection_in_progress",
				"Projection consent flow is already in progress.",
				null,
			)
			return
		}

		val projectionManager =
			getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

		// On Android 14+ (API 34), use createConfigForDefaultDisplay() so the
		// system consent dialog skips the "choose app to share" picker.  The
		// actual audio filtering is done via AudioPlaybackCaptureConfiguration
		// .addMatchingUid(), so we only need projection-level consent, not an
		// app-scoped projection.  The user has already chosen their audio source
		// in the Flutter picker before this dialog is shown.
		@Suppress("NewApi")
		val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
			projectionManager.createScreenCaptureIntent(
				android.media.projection.MediaProjectionConfig.createConfigForDefaultDisplay()
			)
		} else {
			projectionManager.createScreenCaptureIntent()
		}

		pendingProjectionResult = result
		startActivityForResult(intent, REQUEST_MEDIA_PROJECTION)
	}

	private fun startCapture(call: MethodCall, result: MethodChannel.Result) {
		val appPackage = call.argument<String>("packageName")
		val requestedUid = call.argument<Int>("uid") ?: -1
		val requestedChannels = (call.argument<Int>("channels") ?: 2).coerceIn(1, 2)

		if (projectionData == null) {
			result.error(
				"projection_required",
				"Projection permission is required before starting app capture.",
				null,
			)
			return
		}

		if (appPackage.isNullOrBlank()) {
			result.error(
				"specific_app_required",
				"A target app package is required for capture.",
				null,
			)
			return
		}

		val resolvedUid = if (requestedUid > 0) {
			requestedUid
		} else {
			resolveUidForPackage(appPackage)
		}

		if (resolvedUid <= 0) {
			result.error(
				"app_uid_required",
				"Could not resolve UID for selected app package.",
				null,
			)
			return
		}

		val startIntent = AudioCaptureService.buildStartIntent(
			context = this,
			appPackage = appPackage,
			appUid = resolvedUid,
			channels = requestedChannels,
			projectionResultCode = projectionResultCode,
			projectionData = projectionData,
		)

		try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				startForegroundService(startIntent)
			} else {
				startService(startIntent)
			}
		} catch (error: Exception) {
			emitCaptureEvent(
				mapOf(
					"type" to "captureError",
					"code" to "capture_start_failed",
					"message" to
						(error.message
							?: "Unable to start Android audio capture service."),
					"appPackage" to appPackage,
				),
			)
			result.error(
				"capture_start_failed",
				"Failed to start Android audio capture service.",
				error.message,
			)
			return
		}

		emitCaptureEvent(
			mapOf(
				"type" to "captureStartRequested",
				"mode" to "specific_app",
				"appPackage" to (appPackage ?: ""),
				"appUid" to resolvedUid,
				"channels" to requestedChannels,
			)
		)
		result.success(true)
	}

	private fun resolveUidForPackage(packageName: String?): Int {
		if (packageName.isNullOrBlank()) {
			return -1
		}

		return try {
			val appInfo = packageManager.getApplicationInfo(packageName, 0)
			appInfo.uid
		} catch (_: Exception) {
			-1
		}
	}

	private fun stopCapture(result: MethodChannel.Result) {
		// Keep projection alive for fast session restart without a fresh permission prompt.
		val stopIntent = AudioCaptureService.buildStopIntent(this)
		startService(stopIntent)
		emitCaptureEvent(mapOf("type" to "captureStopRequested"))
		result.success(true)
	}

	private fun handleMediaControl(keyCode: Int, result: MethodChannel.Result) {
		val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
		audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
		audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
		result.success(null)
	}

	private fun stopCaptureAndReleaseProjection(result: MethodChannel.Result) {
		// Fully release projection (used for app teardown/dispose paths).
		projectionResultCode = Activity.RESULT_CANCELED
		projectionData = null

		val stopIntent = AudioCaptureService.buildStopAndReleaseIntent(this)
		startService(stopIntent)
		emitCaptureEvent(mapOf("type" to "captureStopRequested"))
		emitCaptureEvent(mapOf("type" to "projectionDenied"))
		result.success(true)
	}

	companion object {
		private const val CHANNEL_CAPTURE_METHODS = "com.breadbeats.mobile/audio_capture/methods"
		private const val CHANNEL_CAPTURE_EVENTS = "com.breadbeats.mobile/audio_capture/events"
		private const val CHANNEL_MEDIA_METHODS = "com.breadbeats.mobile/media/methods"

		private const val METHOD_MEDIA_PREV = "mediaPrev"
		private const val METHOD_MEDIA_PLAY_PAUSE = "mediaPlayPause"
		private const val METHOD_MEDIA_NEXT = "mediaNext"
		private const val METHOD_MEDIA_IS_PLAYING = "mediaIsPlaying"

		private const val METHOD_LIST_CAPTURABLE_APPS = "listCapturableApps"
		private const val METHOD_REQUEST_PROJECTION = "requestProjectionConsent"
		private const val METHOD_START_CAPTURE = "startCapture"
		private const val METHOD_STOP_CAPTURE = "stopCapture"
		private const val METHOD_STOP_CAPTURE_AND_RELEASE =
			"stopCaptureAndReleaseProjection"

		private const val REQUEST_MEDIA_PROJECTION = 21131

		private var captureEventSink: EventChannel.EventSink? = null
		private val captureEventHandler = Handler(Looper.getMainLooper())

		fun emitCaptureEvent(event: Map<String, Any?>) {
			captureEventHandler.post {
				captureEventSink?.success(event)
			}
		}
	}
}
