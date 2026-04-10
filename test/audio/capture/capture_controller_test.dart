import 'dart:typed_data';

import 'package:breadbeats_mobile/audio/capture/audio_capture_platform_service.dart';
import 'package:breadbeats_mobile/audio/capture/capture_controller.dart';
import 'package:breadbeats_mobile/services/focstim_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakeCaptureService extends AudioCapturePlatformService {
  List<CapturableApp> apps = <CapturableApp>[];
  bool projectionResult = true;
  int requestProjectionCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  String? lastStartedPackage;
  int? lastStartedUid;

  @override
  Stream<Map<String, dynamic>> events() =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Future<List<CapturableApp>> listCapturableApps() async {
    return List<CapturableApp>.from(apps);
  }

  @override
  Future<bool> requestProjectionConsent() async {
    requestProjectionCalls += 1;
    return projectionResult;
  }

  @override
  Future<void> startCapture({
    required String packageName,
    required int uid,
    int channels = 2,
  }) async {
    startCalls += 1;
    lastStartedPackage = packageName;
    lastStartedUid = uid;
  }

  @override
  Future<void> stopCapture({bool releaseProjection = false}) async {
    stopCalls += 1;
  }
}

CaptureController _createController(_FakeCaptureService service) {
  return CaptureController(
    captureService: service,
    requestMicrophonePermission: () async => PermissionStatus.granted,
    getNotificationPermissionStatus: () async => PermissionStatus.granted,
    requestNotificationPermission: () async => PermissionStatus.granted,
  );
}

void main() {
  test(
    'refreshCaptureApps filters invalid package names and restores preferred selection',
    () async {
      final _FakeCaptureService service = _FakeCaptureService()
        ..apps = <CapturableApp>[
          const CapturableApp(
            packageName: 'bad package name',
            appName: 'Bad App',
            uid: 1,
          ),
          const CapturableApp(
            packageName: 'com.valid.beta',
            appName: 'Beta Player',
            uid: 22,
          ),
          const CapturableApp(
            packageName: 'com.valid.alpha',
            appName: 'Alpha Player',
            uid: 11,
          ),
        ];
      final CaptureController controller = _createController(service);

      await controller.refreshCaptureApps(preferredPackage: 'com.valid.beta');

      expect(controller.captureStatus, 'apps_loaded');
      expect(controller.captureApps, hasLength(2));
      expect(controller.captureApps.first.packageName, 'com.valid.alpha');
      expect(controller.captureApps.last.packageName, 'com.valid.beta');
      expect(controller.selectedCaptureApp?.packageName, 'com.valid.beta');
    },
  );

  test(
    'startAudioCapture requests projection and starts selected app',
    () async {
      final _FakeCaptureService service = _FakeCaptureService();
      final CaptureController controller = _createController(service);
      controller.selectCaptureApp(
        const CapturableApp(
          packageName: 'com.valid.player',
          appName: 'Player',
          uid: 42,
        ),
      );

      await controller.startAudioCapture();

      expect(service.requestProjectionCalls, 1);
      expect(service.startCalls, 1);
      expect(service.lastStartedPackage, 'com.valid.player');
      expect(service.lastStartedUid, 42);
      expect(controller.captureRunning, isTrue);
      expect(controller.captureStatus, 'running');
    },
  );

  test('startAudioCapture rejects invalid selected package name', () async {
    final _FakeCaptureService service = _FakeCaptureService();
    final CaptureController controller = _createController(service)
      ..projectionGranted = true
      ..selectedCaptureApp = const CapturableApp(
        packageName: 'invalid package',
        appName: 'Bad',
        uid: 4,
      );

    await expectLater(
      controller.startAudioCapture(),
      throwsA(isA<FocstimApiException>()),
    );
    expect(service.startCalls, 0);
  });

  test('handlePlatformEvent rejects malformed typed events', () {
    final CaptureController controller = _createController(
      _FakeCaptureService(),
    );

    final CaptureEventProcessingResult missingSampleRate = controller
        .handlePlatformEvent(<String, dynamic>{
          'type': 'captureStarted',
          'appPackage': 'com.valid.app',
          'appUid': 99,
          'channels': 2,
        }, onPcm16Event: (_) => true);

    bool pcmCallbackCalled = false;
    final CaptureEventProcessingResult malformedPcm = controller
        .handlePlatformEvent(
          <String, dynamic>{
            'type': 'pcm16',
            'appPackage': 'com.valid.app',
            'appUid': 99,
            'sampleRate': 48000,
            'channels': 2,
          },
          onPcm16Event: (_) {
            pcmCallbackCalled = true;
            return true;
          },
        );

    expect(missingSampleRate.shouldNotify, isFalse);
    expect(malformedPcm.shouldNotify, isFalse);
    expect(pcmCallbackCalled, isFalse);
    expect(controller.captureRunning, isFalse);
    expect(controller.captureStatus, 'idle');
  });

  test('handlePlatformEvent parses captureStarted and pcm16 payloads', () {
    final CaptureController controller = _createController(
      _FakeCaptureService(),
    );

    final CaptureEventProcessingResult started = controller
        .handlePlatformEvent(<String, dynamic>{
          'type': 'captureStarted',
          'appPackage': 'com.valid.app',
          'appUid': 321,
          'sampleRate': 44100,
          'channels': 2,
        }, onPcm16Event: (_) => true);

    Pcm16CaptureEvent? frame;
    final CaptureEventProcessingResult pcm = controller.handlePlatformEvent(
      <String, dynamic>{
        'type': 'pcm16',
        'appPackage': 'com.valid.app',
        'appUid': 321,
        'sampleRate': 44100,
        'channels': 2,
        'frameSamples': 256,
        'rms': 0.42,
        'data': Uint8List.fromList(<int>[1, 2, 3, 4]),
      },
      onPcm16Event: (Pcm16CaptureEvent event) {
        frame = event;
        return true;
      },
    );

    expect(started.shouldNotify, isTrue);
    expect(started.captureStarted, isTrue);
    expect(started.captureSampleRate, 44100);
    expect(started.captureChannels, 2);
    expect(controller.captureRunning, isTrue);
    expect(controller.captureStatus, 'running');

    expect(pcm.shouldNotify, isTrue);
    expect(frame, isNotNull);
    expect(frame!.sampleRate, 44100);
    expect(frame!.channels, 2);
    expect(frame!.frameSamples, 256);
    expect(frame!.rms, closeTo(0.42, 1e-12));
    expect(frame!.data, isNotNull);
  });

  test(
    'handlePlatformEvent captureError sets safe state and surfaces error',
    () {
      final CaptureController controller =
          _createController(_FakeCaptureService())
            ..projectionGranted = true
            ..captureRunning = true;

      final CaptureEventProcessingResult result = controller
          .handlePlatformEvent(<String, dynamic>{
            'type': 'captureError',
            'code': 'projection_invalid',
            'message': 'Projection is invalid',
          }, onPcm16Event: (_) => true);

      expect(result.shouldNotify, isTrue);
      expect(result.resetLiveAudio, isTrue);
      expect(result.resetMotionDrive, isTrue);
      expect(result.errorMessage, 'Projection is invalid');
      expect(controller.captureRunning, isFalse);
      expect(controller.captureStatus, 'capture_error');
      expect(controller.projectionGranted, isFalse);
    },
  );
}
