import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/focstim_api_service.dart';
import 'audio_capture_platform_service.dart';

typedef Pcm16EventHandler = bool Function(Pcm16CaptureEvent event);

class CaptureEventProcessingResult {
  const CaptureEventProcessingResult({
    required this.shouldNotify,
    this.captureStarted = false,
    this.captureSampleRate,
    this.captureChannels,
    this.resetLiveAudio = false,
    this.resetMotionDrive = false,
    this.errorMessage,
  });

  const CaptureEventProcessingResult.noNotify()
    : shouldNotify = false,
      captureStarted = false,
      captureSampleRate = null,
      captureChannels = null,
      resetLiveAudio = false,
      resetMotionDrive = false,
      errorMessage = null;

  final bool shouldNotify;
  final bool captureStarted;
  final int? captureSampleRate;
  final int? captureChannels;
  final bool resetLiveAudio;
  final bool resetMotionDrive;
  final String? errorMessage;
}

@immutable
class Pcm16CaptureEvent {
  const Pcm16CaptureEvent({
    required this.sampleRate,
    required this.channels,
    required this.frameSamples,
    this.data,
    this.rms,
    this.appPackage,
    this.appUid,
  });

  final int sampleRate;
  final int channels;
  final int frameSamples;
  final Uint8List? data;
  final double? rms;
  final String? appPackage;
  final int? appUid;
}

class CaptureController {
  CaptureController({
    AudioCapturePlatformService? captureService,
    Future<PermissionStatus> Function()? requestMicrophonePermission,
    Future<PermissionStatus> Function()? getNotificationPermissionStatus,
    Future<PermissionStatus> Function()? requestNotificationPermission,
  }) : _captureService = captureService ?? AudioCapturePlatformService(),
       _requestMicrophonePermission =
           requestMicrophonePermission ??
           (() => Permission.microphone.request()),
       _getNotificationPermissionStatus =
           getNotificationPermissionStatus ??
           (() => Permission.notification.status),
       _requestNotificationPermission =
           requestNotificationPermission ??
           (() => Permission.notification.request());

  final AudioCapturePlatformService _captureService;
  final Future<PermissionStatus> Function() _requestMicrophonePermission;
  final Future<PermissionStatus> Function() _getNotificationPermissionStatus;
  final Future<PermissionStatus> Function() _requestNotificationPermission;

  static final RegExp _packageNamePattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$',
  );

  bool projectionGranted = false;
  bool captureRunning = false;
  String captureStatus = 'idle';
  List<CapturableApp> captureApps = const <CapturableApp>[];
  CapturableApp? selectedCaptureApp;
  bool captureSourceBlocked = false;
  String? captureSourceMessage;

  static bool isValidPackageName(String packageName) {
    final String normalized = packageName.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return _packageNamePattern.hasMatch(normalized);
  }

  Stream<Map<String, dynamic>> events() => _captureService.events();

  void selectCaptureApp(CapturableApp? app) {
    if (app == null) {
      selectedCaptureApp = null;
      return;
    }

    if (!isValidPackageName(app.packageName)) {
      debugPrint(
        '[CaptureController] Ignoring app with invalid package '
        'name: ${app.packageName}',
      );
      return;
    }

    selectedCaptureApp = app;
  }

  Future<void> refreshCaptureApps({String? preferredPackage}) async {
    try {
      final CapturableApp? previousSelection = selectedCaptureApp;
      final List<CapturableApp> apps = await _captureService
          .listCapturableApps();

      final List<CapturableApp> validApps = apps.where((CapturableApp app) {
        final bool valid = isValidPackageName(app.packageName);
        if (!valid) {
          debugPrint(
            '[CaptureController] Dropping app with invalid package '
            'name: ${app.packageName}',
          );
        }
        return valid;
      }).toList();

      validApps.sort(
        (CapturableApp a, CapturableApp b) =>
            a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
      );

      captureApps = validApps;

      final String? candidatePackage =
          _normalizePackageName(preferredPackage) ??
          _normalizePackageName(selectedCaptureApp?.packageName);
      if (candidatePackage != null) {
        final CapturableApp? matched = validApps
            .cast<CapturableApp?>()
            .firstWhere(
              (CapturableApp? app) => app?.packageName == candidatePackage,
              orElse: () => null,
            );
        selectedCaptureApp = matched ?? previousSelection;
      } else {
        selectedCaptureApp = previousSelection;
      }

      // Preserve 'running' status if capture is already active — don't
      // overwrite with 'apps_loaded' mid-session.
      if (!captureRunning) {
        captureStatus = 'apps_loaded';
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[CaptureController] Failed to refresh capture apps: '
        '$error\n$stackTrace',
      );
      captureStatus = 'apps_error';
      rethrow;
    }
  }

  Future<bool> requestProjectionConsent() async {
    try {
      final bool granted = await _captureService.requestProjectionConsent();
      projectionGranted = granted;
      captureStatus = granted ? 'projection_granted' : 'projection_denied';
      return granted;
    } catch (error, stackTrace) {
      debugPrint(
        '[CaptureController] Projection consent request failed: '
        '$error\n$stackTrace',
      );
      captureStatus = 'projection_error';
      rethrow;
    }
  }

  Future<void> startAudioCapture({int channels = 2}) async {
    if (captureRunning) {
      return;
    }

    final int safeChannels = channels >= 2 ? 2 : 1;

    final PermissionStatus micPermission = await _requestMicrophonePermission();
    if (!micPermission.isGranted) {
      throw const FocstimApiException(
        'Microphone permission is required for Android playback capture.',
      );
    }

    final PermissionStatus notificationStatus =
        await _getNotificationPermissionStatus();
    if (notificationStatus.isDenied) {
      await _requestNotificationPermission();
    }

    if (!projectionGranted) {
      final bool granted = await requestProjectionConsent();
      if (!granted) {
        throw const FocstimApiException(
          'MediaProjection permission is required for app capture',
        );
      }
    }

    final CapturableApp? app = selectedCaptureApp;
    if (app == null) {
      throw const FocstimApiException('Select an app before starting capture');
    }
    if (!isValidPackageName(app.packageName)) {
      throw const FocstimApiException('Selected app package is invalid');
    }

    await _captureService.startCapture(
      packageName: app.packageName,
      uid: app.uid,
      channels: safeChannels,
    );

    captureRunning = true;
    captureStatus = 'running';
    captureSourceBlocked = false;
    captureSourceMessage = null;
  }

  Future<String?> stopAudioCapture({bool releaseProjection = false}) async {
    if (!captureRunning && !releaseProjection) {
      return null;
    }

    String? stopError;
    try {
      await _captureService.stopCapture(releaseProjection: releaseProjection);
    } catch (error) {
      stopError = error.toString();
    }

    captureRunning = false;
    captureStatus = releaseProjection ? 'projection_released' : 'stopped';
    captureSourceBlocked = false;
    captureSourceMessage = null;
    if (releaseProjection) {
      projectionGranted = false;
    }
    return stopError;
  }

  CaptureEventProcessingResult handlePlatformEvent(
    Map<String, dynamic> rawEvent, {
    required Pcm16EventHandler onPcm16Event,
  }) {
    final _CapturePlatformEvent? event = _parseEvent(rawEvent);
    if (event == null) {
      return const CaptureEventProcessingResult.noNotify();
    }

    if (event is _ProjectionGrantedEvent) {
      projectionGranted = true;
      captureStatus = 'projection_granted';
      return const CaptureEventProcessingResult(shouldNotify: true);
    }

    if (event is _ProjectionDeniedEvent) {
      projectionGranted = false;
      captureStatus = 'projection_denied';
      return const CaptureEventProcessingResult(shouldNotify: true);
    }

    if (event is _CaptureStartRequestedEvent) {
      captureStatus = 'starting';
      return const CaptureEventProcessingResult(shouldNotify: true);
    }

    if (event is _CaptureStartedEvent) {
      captureRunning = true;
      captureStatus = 'running';
      captureSourceBlocked = false;
      captureSourceMessage = null;
      return CaptureEventProcessingResult(
        shouldNotify: true,
        captureStarted: true,
        captureSampleRate: event.sampleRate,
        captureChannels: event.channels,
        resetLiveAudio: true,
      );
    }

    if (event is _CaptureStoppedEvent) {
      captureRunning = false;
      captureStatus = 'stopped';
      captureSourceBlocked = false;
      captureSourceMessage = null;
      if (event.reason == 'projection_revoked' ||
          event.reason == 'projection_invalid' ||
          event.reason == 'projection_unavailable' ||
          event.reason == 'projection_released') {
        projectionGranted = false;
      }
      return const CaptureEventProcessingResult(
        shouldNotify: true,
        resetLiveAudio: true,
        resetMotionDrive: true,
      );
    }

    if (event is _ProjectionRevokedEvent) {
      projectionGranted = false;
      captureRunning = false;
      captureStatus = 'projection_revoked';
      return const CaptureEventProcessingResult(
        shouldNotify: true,
        resetLiveAudio: true,
        resetMotionDrive: true,
      );
    }

    if (event is _CaptureSourceBlockedEvent) {
      captureSourceBlocked = true;
      captureStatus = 'source_blocked';
      captureSourceMessage = event.reason;
      return const CaptureEventProcessingResult(shouldNotify: true);
    }

    if (event is _CaptureSourceActiveEvent) {
      captureSourceBlocked = false;
      captureStatus = captureRunning ? 'running' : captureStatus;
      captureSourceMessage = null;
      return const CaptureEventProcessingResult(shouldNotify: true);
    }

    if (event is _CaptureErrorEvent) {
      captureRunning = false;
      captureStatus = 'capture_error';
      captureSourceBlocked = false;
      captureSourceMessage = event.message;
      if (event.code.startsWith('projection_')) {
        projectionGranted = false;
      }
      return CaptureEventProcessingResult(
        shouldNotify: true,
        resetLiveAudio: true,
        resetMotionDrive: true,
        errorMessage: event.message,
      );
    }

    if (event is _Pcm16PlatformEvent) {
      final bool shouldNotify = onPcm16Event(
        Pcm16CaptureEvent(
          sampleRate: event.sampleRate,
          channels: event.channels,
          frameSamples: event.frameSamples,
          data: event.data,
          rms: event.rms,
          appPackage: event.appPackage,
          appUid: event.appUid,
        ),
      );
      return CaptureEventProcessingResult(shouldNotify: shouldNotify);
    }

    if (event is _UnknownCaptureEvent) {
      if (event.type.isNotEmpty) {
        captureStatus = event.type;
      }
      return const CaptureEventProcessingResult(shouldNotify: true);
    }

    return const CaptureEventProcessingResult.noNotify();
  }

  _CapturePlatformEvent? _parseEvent(Map<String, dynamic> rawEvent) {
    try {
      final String type = (rawEvent['type'] ?? '').toString().trim();
      if (type.isEmpty) {
        throw const _CaptureEventValidationException(
          'missing required String field "type"',
        );
      }

      switch (type) {
        case 'projectionGranted':
          return const _ProjectionGrantedEvent();
        case 'projectionDenied':
          return const _ProjectionDeniedEvent();
        case 'captureStartRequested':
          _requiredValidPackage(
            rawEvent: rawEvent,
            key: 'appPackage',
            type: type,
          );
          _requiredPositiveInt(rawEvent: rawEvent, key: 'appUid', type: type);
          return const _CaptureStartRequestedEvent();
        case 'captureStarted':
          _requiredValidPackage(
            rawEvent: rawEvent,
            key: 'appPackage',
            type: type,
          );
          _requiredPositiveInt(rawEvent: rawEvent, key: 'appUid', type: type);
          return _CaptureStartedEvent(
            sampleRate: _requiredPositiveInt(
              rawEvent: rawEvent,
              key: 'sampleRate',
              type: type,
            ),
            channels: _requiredPositiveInt(
              rawEvent: rawEvent,
              key: 'channels',
              type: type,
            ),
          );
        case 'captureStopped':
          return _CaptureStoppedEvent(
            reason: _requiredString(
              rawEvent: rawEvent,
              key: 'reason',
              type: type,
            ),
          );
        case 'projectionRevoked':
          _optionalValidPackage(
            rawEvent: rawEvent,
            key: 'appPackage',
            type: type,
          );
          return const _ProjectionRevokedEvent();
        case 'captureSourceBlocked':
          _requiredValidPackage(
            rawEvent: rawEvent,
            key: 'appPackage',
            type: type,
          );
          _requiredPositiveInt(rawEvent: rawEvent, key: 'appUid', type: type);
          return _CaptureSourceBlockedEvent(
            reason: _requiredString(
              rawEvent: rawEvent,
              key: 'reason',
              type: type,
            ),
          );
        case 'captureSourceActive':
          _requiredValidPackage(
            rawEvent: rawEvent,
            key: 'appPackage',
            type: type,
          );
          _requiredPositiveInt(rawEvent: rawEvent, key: 'appUid', type: type);
          return const _CaptureSourceActiveEvent();
        case 'captureError':
          _optionalValidPackage(
            rawEvent: rawEvent,
            key: 'appPackage',
            type: type,
          );
          return _CaptureErrorEvent(
            code: _requiredString(rawEvent: rawEvent, key: 'code', type: type),
            message: _requiredString(
              rawEvent: rawEvent,
              key: 'message',
              type: type,
            ),
          );
        case 'pcm16':
          final String? appPackage = _requiredValidPackage(
            rawEvent: rawEvent,
            key: 'appPackage',
            type: type,
          );
          final int appUid = _requiredPositiveInt(
            rawEvent: rawEvent,
            key: 'appUid',
            type: type,
          );
          final Uint8List? data = _optionalBytes(
            rawEvent: rawEvent,
            key: 'data',
            type: type,
          );
          final double? rms = _optionalDouble(
            rawEvent: rawEvent,
            key: 'rms',
            type: type,
          );
          if (data == null && rms == null) {
            throw const _CaptureEventValidationException(
              '"pcm16" requires at least one of ["data", "rms"]',
            );
          }
          return _Pcm16PlatformEvent(
            appPackage: appPackage,
            appUid: appUid,
            sampleRate: _requiredPositiveInt(
              rawEvent: rawEvent,
              key: 'sampleRate',
              type: type,
            ),
            channels: _requiredPositiveInt(
              rawEvent: rawEvent,
              key: 'channels',
              type: type,
            ),
            frameSamples: _requiredPositiveInt(
              rawEvent: rawEvent,
              key: 'frameSamples',
              type: type,
            ),
            data: data,
            rms: rms,
          );
        default:
          return _UnknownCaptureEvent(type: type);
      }
    } on _CaptureEventValidationException catch (error) {
      debugPrint(
        '[CaptureController] Rejecting capture event: ${error.message}',
      );
      return null;
    }
  }

  String? _normalizePackageName(String? packageName) {
    if (packageName == null) {
      return null;
    }
    final String normalized = packageName.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (!isValidPackageName(normalized)) {
      debugPrint(
        '[CaptureController] Ignoring invalid package name: $normalized',
      );
      return null;
    }
    return normalized;
  }

  String _requiredString({
    required Map<String, dynamic> rawEvent,
    required String key,
    required String type,
  }) {
    final dynamic value = rawEvent[key];
    final String normalized = (value ?? '').toString().trim();
    if (normalized.isEmpty) {
      throw _CaptureEventValidationException(
        '"$type" missing required String field "$key"',
      );
    }
    return normalized;
  }

  int _requiredPositiveInt({
    required Map<String, dynamic> rawEvent,
    required String key,
    required String type,
  }) {
    final dynamic value = rawEvent[key];
    final int? parsed = _parseInt(value);
    if (parsed == null || parsed <= 0) {
      throw _CaptureEventValidationException(
        '"$type" missing required positive integer field "$key"',
      );
    }
    return parsed;
  }

  String? _requiredValidPackage({
    required Map<String, dynamic> rawEvent,
    required String key,
    required String type,
  }) {
    final String value = _requiredString(
      rawEvent: rawEvent,
      key: key,
      type: type,
    );
    if (!isValidPackageName(value)) {
      throw _CaptureEventValidationException(
        '"$type" has invalid package name in "$key": $value',
      );
    }
    return value;
  }

  String? _optionalValidPackage({
    required Map<String, dynamic> rawEvent,
    required String key,
    required String type,
  }) {
    if (!rawEvent.containsKey(key)) {
      return null;
    }

    final dynamic value = rawEvent[key];
    final String normalized = (value ?? '').toString().trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (!isValidPackageName(normalized)) {
      throw _CaptureEventValidationException(
        '"$type" has invalid package name in "$key": $normalized',
      );
    }
    return normalized;
  }

  Uint8List? _optionalBytes({
    required Map<String, dynamic> rawEvent,
    required String key,
    required String type,
  }) {
    if (!rawEvent.containsKey(key)) {
      return null;
    }

    final dynamic value = rawEvent[key];
    if (value == null) {
      return null;
    }
    if (value is Uint8List) {
      return value;
    }
    if (value is List<int>) {
      return Uint8List.fromList(value);
    }
    if (value is List<dynamic>) {
      final List<int> converted = <int>[];
      for (final dynamic item in value) {
        final int? parsed = _parseInt(item);
        if (parsed == null || parsed < 0 || parsed > 255) {
          throw _CaptureEventValidationException(
            '"$type" has non-byte value in "$key"',
          );
        }
        converted.add(parsed);
      }
      return Uint8List.fromList(converted);
    }

    throw _CaptureEventValidationException(
      '"$type" has invalid byte payload in "$key"',
    );
  }

  double? _optionalDouble({
    required Map<String, dynamic> rawEvent,
    required String key,
    required String type,
  }) {
    if (!rawEvent.containsKey(key)) {
      return null;
    }

    final dynamic value = rawEvent[key];
    if (value == null) {
      return null;
    }

    final double? parsed = _parseDouble(value);
    if (parsed == null || !parsed.isFinite) {
      throw _CaptureEventValidationException(
        '"$type" has invalid numeric field "$key"',
      );
    }
    return parsed;
  }

  int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class _CaptureEventValidationException implements Exception {
  const _CaptureEventValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class _CapturePlatformEvent {
  const _CapturePlatformEvent();
}

class _ProjectionGrantedEvent extends _CapturePlatformEvent {
  const _ProjectionGrantedEvent();
}

class _ProjectionDeniedEvent extends _CapturePlatformEvent {
  const _ProjectionDeniedEvent();
}

class _CaptureStartRequestedEvent extends _CapturePlatformEvent {
  const _CaptureStartRequestedEvent();
}

class _CaptureStartedEvent extends _CapturePlatformEvent {
  const _CaptureStartedEvent({
    required this.sampleRate,
    required this.channels,
  });

  final int sampleRate;
  final int channels;
}

class _CaptureStoppedEvent extends _CapturePlatformEvent {
  const _CaptureStoppedEvent({required this.reason});

  final String reason;
}

class _ProjectionRevokedEvent extends _CapturePlatformEvent {
  const _ProjectionRevokedEvent();
}

class _CaptureSourceBlockedEvent extends _CapturePlatformEvent {
  const _CaptureSourceBlockedEvent({required this.reason});

  final String reason;
}

class _CaptureSourceActiveEvent extends _CapturePlatformEvent {
  const _CaptureSourceActiveEvent();
}

class _CaptureErrorEvent extends _CapturePlatformEvent {
  const _CaptureErrorEvent({required this.code, required this.message});

  final String code;
  final String message;
}

class _Pcm16PlatformEvent extends _CapturePlatformEvent {
  const _Pcm16PlatformEvent({
    required this.appPackage,
    required this.appUid,
    required this.sampleRate,
    required this.channels,
    required this.frameSamples,
    this.data,
    this.rms,
  });

  final String? appPackage;
  final int appUid;
  final int sampleRate;
  final int channels;
  final int frameSamples;
  final Uint8List? data;
  final double? rms;
}

class _UnknownCaptureEvent extends _CapturePlatformEvent {
  const _UnknownCaptureEvent({required this.type});

  final String type;
}
