import 'dart:async';

import 'package:breadbeats_mobile/audio/capture/audio_capture_platform_service.dart';
import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/generated/protobuf/focstim_rpc.pb.dart'
    as rpc;
import 'package:breadbeats_mobile/generated/protobuf/messages.pb.dart' as msg;
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/providers/connection_provider.dart';
import 'package:breadbeats_mobile/providers/user_settings.dart';
import 'package:breadbeats_mobile/services/focstim_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFocstimApiService extends FocstimApiService {
  final StreamController<rpc.Notification> _notificationController =
      StreamController<rpc.Notification>.broadcast();
  final StreamController<FocstimConnectionState> _stateController =
      StreamController<FocstimConnectionState>.broadcast();

  FocstimConnectionState _state = FocstimConnectionState.disconnected;
  bool _connected = false;
  int _lastResponseMs = 0;

  int connectCalls = 0;
  int disconnectCalls = 0;
  int startSignalCalls = 0;
  int stopSignalCalls = 0;

  @override
  Stream<rpc.Notification> get notifications => _notificationController.stream;

  @override
  Stream<FocstimConnectionState> get stateStream => _stateController.stream;

  @override
  FocstimConnectionState get state => _state;

  @override
  bool get isConnected => _connected;

  @override
  int get lastResponseMs => _lastResponseMs;

  void _emitState(FocstimConnectionState next) {
    _state = next;
    _stateController.add(next);
  }

  @override
  Future<void> connectTcp(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    connectCalls += 1;
    _connected = true;
    _lastResponseMs = DateTime.now().millisecondsSinceEpoch;
    _emitState(FocstimConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _connected = false;
    _emitState(FocstimConnectionState.disconnected);
  }

  @override
  Future<msg.ResponseFirmwareVersion> getFirmwareVersion() async {
    return msg.ResponseFirmwareVersion(
      board: enums.BoardIdentifier.BOARD_UNKNOWN,
      stm32FirmwareVersion2: msg.FirmwareVersion(
        major: 1,
        minor: 1,
        revision: 0,
        branch: 'main',
        comment: 'test',
      ),
    );
  }

  @override
  Future<msg.ResponseCapabilitiesGet> getCapabilities() async {
    return msg.ResponseCapabilitiesGet(
      threephase: true,
      fourphase: true,
      battery: true,
      deviceVolume: true,
      maximumWaveformAmplitudeAmps: 0.03,
      lsm6dsox: true,
    );
  }

  @override
  Future<void> startSignal(enums.OutputMode mode) async {
    startSignalCalls += 1;
  }

  @override
  Future<void> stopSignal() async {
    stopSignalCalls += 1;
  }

  @override
  Future<void> moveAxis(
    enums.AxisType axis,
    double value,
    int intervalMs, {
    int? timeoutMs,
  }) async {
    _lastResponseMs = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Future<void> zeroAllAxes() async {}

  @override
  Future<void> lockDeviceVolume(bool lock) async {}

  @override
  Future<void> dispose() async {
    await _notificationController.close();
    await _stateController.close();
  }
}

class _FakeCaptureService extends AudioCapturePlatformService {
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> events() => _eventController.stream;

  @override
  Future<List<CapturableApp>> listCapturableApps() async {
    return const <CapturableApp>[
      CapturableApp(
        packageName: 'com.test.music',
        appName: 'Test Music',
        uid: 42,
      ),
    ];
  }

  @override
  Future<bool> requestProjectionConsent() async => true;

  @override
  Future<void> startCapture({
    required String packageName,
    required int uid,
    int channels = 2,
  }) async {}

  @override
  Future<void> stopCapture({bool releaseProjection = false}) async {}

  Future<void> disposeFake() async {
    await _eventController.close();
  }
}

class _TestConnectionProvider extends ConnectionProvider {
  _TestConnectionProvider({required super.api, required super.captureService});

  @override
  Future<void> startAudioCapture({bool emitHaptic = true}) async {
    projectionGranted = true;
    captureRunning = true;
    captureStatus = 'running';
  }

  @override
  Future<void> stopAudioCapture({
    bool releaseProjection = false,
    bool emitHaptic = true,
  }) async {
    captureRunning = false;
    captureStatus = 'stopped';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ConnectionProvider smoke', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test(
      'startSession and stopSession transition cleanly with fakes',
      () async {
        final _FakeFocstimApiService api = _FakeFocstimApiService();
        final _FakeCaptureService capture = _FakeCaptureService();
        final _TestConnectionProvider provider = _TestConnectionProvider(
          api: api,
          captureService: capture,
        );

        provider.selectCaptureApp(
          const CapturableApp(
            packageName: 'com.test.music',
            appName: 'Test Music',
            uid: 42,
          ),
        );

        await provider.startSession();
        expect(provider.sessionRunning, isTrue);
        expect(api.connectCalls, 1);
        expect(api.startSignalCalls, 1);

        await provider.stopSession();
        expect(provider.sessionRunning, isFalse);
        expect(api.stopSignalCalls, 1);
        expect(api.disconnectCalls, greaterThanOrEqualTo(1));

        provider.dispose();
        await capture.disposeFake();
      },
    );

    test('settings persist and reload across provider instances', () async {
      final _FakeFocstimApiService api1 = _FakeFocstimApiService();
      final _FakeCaptureService capture1 = _FakeCaptureService();
      final _TestConnectionProvider provider1 = _TestConnectionProvider(
        api: api1,
        captureService: capture1,
      );

      await Future<void>.delayed(const Duration(milliseconds: 350));

      provider1.setSensitivity(0.73);
      provider1.setIntensityCap(31.0);
      provider1.setCarrierRange(650.0, 1300.0);
      provider1.setCarrierHz(1000.0);
      provider1.setManualPulseMode(true);
      provider1.setManualPulseHz(33.0);
      provider1.setOnsetSensitivityWindow(0.2, 0.9);
      provider1.setOnsetSmoothing(42.0);
      provider1.setImuStreamingEnabled(true);

      await Future<void>.delayed(const Duration(milliseconds: 700));
      provider1.dispose();
      await capture1.disposeFake();

      final _FakeFocstimApiService api2 = _FakeFocstimApiService();
      final _FakeCaptureService capture2 = _FakeCaptureService();
      final _TestConnectionProvider provider2 = _TestConnectionProvider(
        api: api2,
        captureService: capture2,
      );

      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(provider2.sensitivity, closeTo(0.73, 1e-9));
      expect(provider2.intensityCap, closeTo(31.0, 1e-9));
      expect(provider2.carrierMinHz, closeTo(650.0, 1e-9));
      expect(provider2.carrierMaxHz, closeTo(1300.0, 1e-9));
      expect(provider2.carrierHz, closeTo(1000.0, 1e-9));
      expect(provider2.manualPulseMode, isTrue);
      expect(provider2.manualPulseHz, closeTo(33.0, 1e-9));
      expect(provider2.onsetSensitivityMin, closeTo(0.2, 1e-9));
      expect(provider2.onsetSensitivityMax, closeTo(0.9, 1e-9));
      expect(provider2.onsetSmoothing, closeTo(42.0, 1e-9));
      expect(provider2.imuStreamingEnabled, isTrue);

      provider2.dispose();
      await capture2.disposeFake();
    });

    test(
      'capture app selection persists across provider teardown and reload',
      () async {
        final _FakeFocstimApiService api1 = _FakeFocstimApiService();
        final _FakeCaptureService capture1 = _FakeCaptureService();
        final _TestConnectionProvider provider1 = _TestConnectionProvider(
          api: api1,
          captureService: capture1,
        );

        await Future<void>.delayed(const Duration(milliseconds: 350));

        provider1.selectCaptureApp(
          const CapturableApp(
            packageName: 'com.test.music',
            appName: 'Test Music',
            uid: 42,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 120));
        provider1.dispose();
        await capture1.disposeFake();

        final _FakeFocstimApiService api2 = _FakeFocstimApiService();
        final _FakeCaptureService capture2 = _FakeCaptureService();
        final _TestConnectionProvider provider2 = _TestConnectionProvider(
          api: api2,
          captureService: capture2,
        );

        await Future<void>.delayed(const Duration(milliseconds: 350));

        expect(provider2.selectedCaptureApp, isNotNull);
        expect(provider2.selectedCaptureApp!.packageName, 'com.test.music');
        expect(provider2.selectedCaptureApp!.appName, 'Test Music');
        expect(provider2.selectedCaptureApp!.uid, 42);

        provider2.dispose();
        await capture2.disposeFake();
      },
    );

    test('legacy saved capture package restores without saved uid', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        UserSettings.prefsCapturePackageKey: 'com.test.music',
        UserSettings.prefsCaptureAppNameKey: 'Legacy Music',
      });

      final _FakeFocstimApiService api = _FakeFocstimApiService();
      final _FakeCaptureService capture = _FakeCaptureService();
      final _TestConnectionProvider provider = _TestConnectionProvider(
        api: api,
        captureService: capture,
      );

      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(provider.selectedCaptureApp, isNotNull);
      expect(provider.selectedCaptureApp!.packageName, 'com.test.music');
      expect(provider.selectedCaptureApp!.appName, 'Legacy Music');
      expect(provider.selectedCaptureApp!.uid, -1);

      await provider.refreshCaptureApps();
      expect(provider.selectedCaptureApp, isNotNull);
      expect(provider.selectedCaptureApp!.packageName, 'com.test.music');
      expect(provider.selectedCaptureApp!.appName, 'Test Music');
      expect(provider.selectedCaptureApp!.uid, 42);

      provider.dispose();
      await capture.disposeFake();
    });
  });
}
