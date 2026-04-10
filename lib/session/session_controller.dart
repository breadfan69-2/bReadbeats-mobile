import 'dart:async';

import 'package:flutter/foundation.dart';

import '../generated/protobuf/constants.pbenum.dart' as enums;
import '../models/device_models.dart';
import '../services/focstim_api_service.dart';
import 'device_transport.dart';

class SessionController {
  SessionController({required DeviceTransport transport}) : _transport = transport;

  final DeviceTransport _transport;

  Timer? _watchdogTimer;
  bool _imuStreamingRequested = false;
  String _imuStreamingStatus = 'not_requested';
  FocstimConnectionState _connectionState = FocstimConnectionState.disconnected;
  bool _sessionRunning = false;
  FocstimFirmwareVersion? _firmware;
  FocstimCapabilities? _capabilities;

  static const int _watchdogStaleMs =
      4000; // 4 s — matches FOC-Stim keepalive timeout

  static const int _requiredFirmwareMajor = 1;
  static const int _requiredFirmwareMinor = 1;
  static const String _requiredFirmwareBranch = 'main';
  static const double _imuSampleRateHz = 104.0;
  static const double _imuAccFullscaleG = 4.0;
  static const double _imuGyrFullscaleDps = 500.0;

  String get imuStreamingStatus => _imuStreamingStatus;
  FocstimConnectionState get connectionState => _connectionState;
  bool get sessionRunning => _sessionRunning;
  FocstimFirmwareVersion? get firmware => _firmware;
  FocstimCapabilities? get capabilities => _capabilities;

  void markConnectionState(FocstimConnectionState state) {
    _connectionState = state;
  }

  void markSessionRunning(bool running) {
    _sessionRunning = running;
  }

  Future<void> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _transport.connect(host, port, timeout: timeout);
  }

  /// Connect, read firmware/capabilities, and validate — without starting
  /// signal generation. Used by the "Test Connection" button on DeviceScreen.
  Future<void> connectOnly(String host, int port) async {
    await _transport.disconnect();
    await _transport.connect(host, port);
    final FocstimFirmwareVersion firmware = await _readFirmwareVersion();
    _validateFirmwareCompatibility(firmware);
    final FocstimCapabilities capabilities = await _readCapabilities();
    _firmware = firmware;
    _capabilities = capabilities;
  }

  Future<void> disconnect() => _transport.disconnect();

  Future<void> prepareAndStartSignal({
    required String host,
    required int port,
    required OutputModeSelection outputMode,
    bool enableImuStreaming = false,
    required Future<void> Function() beforeStartSignal,
    required void Function() onConnectionLost,
  }) async {
    await _transport.disconnect();
    await _transport.connect(host, port);

    final FocstimFirmwareVersion firmware = await _readFirmwareVersion();
    _validateFirmwareCompatibility(firmware);

    final FocstimCapabilities capabilities = await _readCapabilities();
    _validateModeSupport(caps: capabilities, outputMode: outputMode);
    if (enableImuStreaming) {
      await _startImuStreamingIfSupported(capabilities: capabilities);
    } else {
      _imuStreamingRequested = false;
      _imuStreamingStatus = capabilities.lsm6dsox
          ? 'skipped_disabled'
          : 'skipped_not_supported';
    }

    await beforeStartSignal();

    final enums.OutputMode mode = outputMode == OutputModeSelection.fourPhase
        ? enums.OutputMode.OUTPUT_FOURPHASE_INDIVIDUAL_ELECTRODES
        : enums.OutputMode.OUTPUT_THREEPHASE;
    await _transport.startSignal(mode);
    _sessionRunning = true;

    _startWatchdog(onConnectionLost: onConnectionLost);
    _firmware = firmware;
    _capabilities = capabilities;
  }

  Future<void> stopSignalSession() async {
    stopWatchdog();
    _sessionRunning = false;

    try {
      if (_connectionState == FocstimConnectionState.connected) {
        await _transport.zeroAllAxes();
        await _transport.stopSignal();
        await _stopImuStreamingIfRequested();
      } else {
        _imuStreamingRequested = false;
      }
    } finally {
      await _transport.disconnect();
    }
  }

  void stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void handleConnectionLost() {
    stopWatchdog();
    _sessionRunning = false;
    _imuStreamingRequested = false;
    _imuStreamingStatus = 'connection_lost';
  }

  void resetImuState({String status = 'not_requested'}) {
    _imuStreamingRequested = false;
    _imuStreamingStatus = status;
  }

  Future<FocstimFirmwareVersion> _readFirmwareVersion() async {
    final fw = await _transport.getFirmwareVersion();
    final fwVersion = fw.hasStm32FirmwareVersion2()
        ? fw.stm32FirmwareVersion2
        : null;
    return FocstimFirmwareVersion(
      major: fwVersion?.major ?? 0,
      minor: fwVersion?.minor ?? 0,
      revision: fwVersion?.revision ?? 0,
      branch: fwVersion?.branch ?? 'unknown',
      comment: fwVersion?.comment ?? '',
      board: fw.board.name,
    );
  }

  Future<FocstimCapabilities> _readCapabilities() async {
    final caps = await _transport.getCapabilities();
    return FocstimCapabilities(
      threephase: caps.threephase,
      fourphase: caps.fourphase,
      battery: caps.battery,
      deviceVolume: caps.deviceVolume,
      lsm6dsox: caps.lsm6dsox,
      maximumWaveformAmplitudeAmps: caps.maximumWaveformAmplitudeAmps,
    );
  }

  void _validateFirmwareCompatibility(FocstimFirmwareVersion version) {
    if (version.branch != _requiredFirmwareBranch) {
      throw FocstimApiException(
        'Incompatible firmware branch: ${version.branch} (expected $_requiredFirmwareBranch)',
      );
    }

    if (version.major != _requiredFirmwareMajor ||
        version.minor < _requiredFirmwareMinor) {
      throw FocstimApiException(
        'Incompatible firmware version: v${version.major}.${version.minor}.${version.revision} '
        '(requires >= $_requiredFirmwareMajor.$_requiredFirmwareMinor.0 on branch $_requiredFirmwareBranch)',
      );
    }
  }

  void _validateModeSupport({
    required FocstimCapabilities caps,
    required OutputModeSelection outputMode,
  }) {
    final bool modeSupported = outputMode == OutputModeSelection.fourPhase
        ? caps.fourphase
        : caps.threephase;
    if (!modeSupported) {
      final String modeName = outputMode == OutputModeSelection.fourPhase
          ? '4-phase'
          : '3-phase';
      throw FocstimApiException(
        'Connected device does not support $modeName output mode',
      );
    }
  }

  void _startWatchdog({required void Function() onConnectionLost}) {
    stopWatchdog();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectionState != FocstimConnectionState.connected) {
        return;
      }
      if (!_sessionRunning) {
        return;
      }
      final int elapsed =
          DateTime.now().millisecondsSinceEpoch - _transport.lastResponseMs;
      if (elapsed > _watchdogStaleMs) {
        stopWatchdog();
        onConnectionLost();
      }
    });
  }

  Future<void> _startImuStreamingIfSupported({
    required FocstimCapabilities capabilities,
  }) async {
    _imuStreamingRequested = false;
    if (!capabilities.lsm6dsox) {
      _imuStreamingStatus = 'skipped_not_supported';
      return;
    }

    _imuStreamingStatus = 'requesting';
    try {
      await _transport.startLsm6dsox(
        imuSamplerateHz: _imuSampleRateHz,
        accFullscaleG: _imuAccFullscaleG,
        gyrFullscaleDps: _imuGyrFullscaleDps,
      );
      _imuStreamingRequested = true;
      _imuStreamingStatus = 'requested';
    } catch (error) {
      _imuStreamingStatus = 'start_failed';
      if (kDebugMode) {
        debugPrint('[IMU] Unable to start LSM6DSOX stream: $error');
      }
    }
  }

  Future<void> _stopImuStreamingIfRequested() async {
    if (!_imuStreamingRequested) {
      return;
    }

    try {
      await _transport.stopLsm6dsox();
      _imuStreamingStatus = 'stopped';
    } catch (error) {
      _imuStreamingStatus = 'stop_failed';
      if (kDebugMode) {
        debugPrint('[IMU] Unable to stop LSM6DSOX stream: $error');
      }
    } finally {
      _imuStreamingRequested = false;
    }
  }
}