import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/capture/audio_capture_manager.dart';
import '../audio/capture/audio_capture_platform_service.dart';
import '../audio/capture/capture_controller.dart';
import '../audio/motion/adaptive_lead.dart';
import '../audio/motion/beat_motion_engine.dart';
import '../audio/motion/electrode_state_controller.dart';
import '../audio/motion/fill_motion_engine.dart';
import '../audio/motion/electrode_math.dart';
import '../audio/motion/gate_chain.dart';
import '../audio/motion/heartbeat_motion_state_controller.dart';
import '../audio/motion/learning_adapter.dart';
import '../audio/motion/motion_math.dart';
import '../audio/motion/onset_motion_engine.dart';
import '../generated/protobuf/constants.pbenum.dart' as enums;
import '../generated/protobuf/focstim_rpc.pb.dart' as rpc;
import '../models/device_models.dart';
import '../models/enums.dart';
import '../models/motion_constants.dart';
import '../core/haptics.dart';
import '../session/session_controller.dart';
import '../session/session_runtime_controller.dart';
import '../session/session_start_primer.dart';
import 'button_state_machine.dart';
import 'calibration_controller.dart';
import 'heartbeat_command_pipeline_controller.dart';
import 'heartbeat_command_pipeline_request_mapper.dart';
import 'heartbeat_loop_controller.dart';
import 'heartbeat_orchestrator_output_apply_controller.dart';
import 'heartbeat_tick_precompute_controller.dart';
import 'heartbeat_tick_precompute_request_mapper.dart';
import 'telemetry_state.dart';
import 'user_settings.dart';
import '../services/focstim_api_service.dart';

class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider({
    FocstimApiService? api,
    AudioCapturePlatformService? captureService,
  }) : _api = api ?? FocstimApiService(),
       _captureController = CaptureController(captureService: captureService) {
    _sessionController = SessionController(transport: _api);

    _stateSubscription = _api.stateStream.listen((
      FocstimConnectionState state,
    ) {
      final FocstimConnectionState previous = connectionState;
      _sessionController.markConnectionState(state);
      notifyListeners();

      // Detect unexpected disconnect (socket error/close) while we thought
      // we were still connected or actively running a session.
      if ((state == FocstimConnectionState.disconnected ||
              state == FocstimConnectionState.error) &&
          previous == FocstimConnectionState.connected &&
          sessionRunning) {
        _handleConnectionLost();
      }
    });

    _notificationSubscription = _api.notifications.listen(
      _handleDeviceNotification,
    );

    _captureSubscription = _captureController.events().listen(
      _handleCaptureEvent,
    );
    _deferStartupHydration();
  }

  final FocstimApiService _api;
  late final SessionController _sessionController;
  final CaptureController _captureController;
  final AudioCaptureManager _audioCaptureManager = AudioCaptureManager();
  final ElectrodeStateController _electrodeStateController =
      ElectrodeStateController();
  final SessionRuntimeController _sessionRuntimeController =
      SessionRuntimeController();
  final SessionStartPrimer _sessionStartPrimer = const SessionStartPrimer();

  StreamSubscription<FocstimConnectionState>? _stateSubscription;
  StreamSubscription<rpc.Notification>? _notificationSubscription;
  StreamSubscription<Map<String, dynamic>>? _captureSubscription;
  final HeartbeatLoopController _heartbeatLoop = HeartbeatLoopController();
  Timer? _calibrationPreviewTimer;
  double _lastCalibrationPreviewSec = 0.0;
  bool _isDisposed = false;

  final HeartbeatMotionStateController _heartbeatMotionState =
      HeartbeatMotionStateController(fillBaseRadius: fillBaseRadius);
  static const double _startupRampDurationSec = 1.8;
  static const double _manualVelocityMaxUnitsPerSec = 2.0 / 0.30;
  static const double _manualIntensityReleaseSec = 0.15;
  static const String _learningModelAssetPath =
      'assets/learning/rule_fit.release.json';

  // ── Manual mode target/smoothed state ──
  double _manualTargetAlpha = 0.0;
  double _manualTargetBeta = 0.0;
  double _manualTargetE1 = 0.333;
  double _manualTargetE2 = 0.333;
  double _manualTargetE3 = 0.333;
  double _manualTargetE4 = 0.0;
  double _manualUserE4 = 0.0;

  // Raw barycentric proportions from the triangle pad (always sum to 1.0,
  // never budget-reduced). Used to recompute targets when D slider moves.
  double _manualTouchRatioE1 = 0.333;
  double _manualTouchRatioE2 = 0.333;
  double _manualTouchRatioE3 = 0.333;

  double _manualSmoothedAlpha = 0.0;
  double _manualSmoothedBeta = 0.0;
  double _manualSmoothedE1 = 0.333;
  double _manualSmoothedE2 = 0.333;
  double _manualSmoothedE3 = 0.333;
  double _manualSmoothedE4 = 0.0;

  double _carrierLfoPhase = 0.0;
  double _pulseLfoPhase = 0.0;
  double _manualIntensityRamp = 0.0;
  bool _manualPaused = true;
  double _manualEffectiveCarrierHz = 0.0;
  double _manualEffectivePulseHz = 0.0;

  FocstimConnectionState get connectionState =>
      _sessionController.connectionState;
  final UserSettings settings = UserSettings();

  String host = '192.168.1.50';
  int port = 55533;

  final HeartbeatCommandPipelineController _heartbeatCommandPipelineController =
      const HeartbeatCommandPipelineController();
  final HeartbeatCommandPipelineRequestMapper
  _heartbeatCommandPipelineRequestMapper =
      const HeartbeatCommandPipelineRequestMapper();
  final HeartbeatTickPrecomputeRequestMapper
  _heartbeatTickPrecomputeRequestMapper =
      const HeartbeatTickPrecomputeRequestMapper();
  final HeartbeatOrchestratorOutputApplyController
  _heartbeatOrchestratorOutputApplyController =
      const HeartbeatOrchestratorOutputApplyController();
  final CalibrationController _calibrationController = CalibrationController();
  final HeartbeatTickPrecomputeController _heartbeatTickPrecomputeController =
      const HeartbeatTickPrecomputeController();

  CalibrationPattern get calibrationPattern => _calibrationController.pattern;
  double get calibrationPatternSpeed => _calibrationController.patternSpeedRps;

  bool get sessionRunning => _sessionController.sessionRunning;
  double get liveAudioLevel => _audioCaptureManager.liveAudioLevel;
  int get pcmFrameCount => _audioCaptureManager.pcmFrameCount;
  int get pcmSampleRate => _audioCaptureManager.pcmSampleRate;
  int get pcmChannels => _audioCaptureManager.pcmChannels;
  double get liveLowBand => _audioCaptureManager.liveLowBand;
  double get liveMidBand => _audioCaptureManager.liveMidBand;
  double get liveHighBand => _audioCaptureManager.liveHighBand;
  double get liveDominantBassHz => _audioCaptureManager.liveDominantBassHz;
  double get liveEffectivePulseHz => _heartbeatMotionState.liveEffectivePulseHz;
  double get liveFlux => _audioCaptureManager.liveFlux;
  double get liveOnset => _audioCaptureManager.liveOnset;
  double get liveBeat => _audioCaptureManager.liveBeat;
  double get liveDb => _audioCaptureManager.liveDb;
  bool get liveGateOpen => _audioCaptureManager.liveGateOpen;
  int get motionCommandTicks => _sessionRuntimeController.motionCommandTicks;
  double get lastAmplitudeAmps => _sessionRuntimeController.lastAmplitudeAmps;
  double get electrode1Level => _electrodeStateController.electrode1Level;
  double get electrode2Level => _electrodeStateController.electrode2Level;
  double get electrode3Level => _electrodeStateController.electrode3Level;
  double get electrode4Level => _electrodeStateController.electrode4Level;
  bool showElectrodeBars = true;
  double get positionAlpha => _electrodeStateController.positionAlpha;
  double get positionBeta => _electrodeStateController.positionBeta;
  double get positionGamma => _electrodeStateController.positionGamma;

  // Device-side telemetry snapshot decoded from RPC notifications.
  static const int totalTelemetryCategories =
      TelemetryState.totalTelemetryCategories;
  final TelemetryState telemetryState = TelemetryState();

  String? lastError;
  FocstimFirmwareVersion? get firmware => _sessionController.firmware;
  FocstimCapabilities? get capabilities => _sessionController.capabilities;

  SharedPreferences? _prefs;
  String? _savedCapturePackage;
  String? _savedCaptureAppName;
  int? _savedCaptureUid;
  bool _savedPreferencesLoaded = false;
  Future<void>? _savedPreferencesLoadFuture;

  final OnsetMotionEngine _onsetMotion = OnsetMotionEngine();
  final FillMotionEngine _fillMotion = FillMotionEngine();

  // ── Beat‑mode circle orbit state ──
  final BeatMotionEngine _beatMotion = BeatMotionEngine();

  AdaptiveLead _adaptiveLead = AdaptiveLead(baseLead: 0.0);
  bool _adaptiveLeadLastGateOpen = false;
  final LearningAdapter _learningAdapter = LearningAdapter();
  int _committedCadenceHint = 2;
  bool _learningLastGateOpen = false;

  // ── Gate chain (desktop beat_intelligence port) ──
  final GateChain _gateChain = GateChain();

  // Hardware button long-press soft stop (keep session running).
  final ButtonStateMachine _buttonStateMachine = ButtonStateMachine();

  List<String> hostHistory = <String>[];
  // Canonical 3-phase electrode naming:
  // A = N (neutral/up), B = L (left), C = R (right).
  // Legacy internal calibration fields (cal3Neutral/cal3Right/cal3Center)
  // are retained for persisted settings compatibility.
  static const List<String> _threePhaseElectrodeLabels = <String>[
    'A',
    'B',
    'C',
  ];
  static const List<String> _fourPhaseElectrodeLabels = <String>[
    'A',
    'B',
    'C',
    'D',
  ];

  bool get projectionGranted => _captureController.projectionGranted;
  set projectionGranted(bool value) =>
      _captureController.projectionGranted = value;

  bool get captureRunning => _captureController.captureRunning;
  set captureRunning(bool value) => _captureController.captureRunning = value;

  String get captureStatus => _captureController.captureStatus;
  set captureStatus(String value) => _captureController.captureStatus = value;

  List<CapturableApp> get captureApps => _captureController.captureApps;
  set captureApps(List<CapturableApp> value) =>
      _captureController.captureApps = value;

  CapturableApp? get selectedCaptureApp =>
      _captureController.selectedCaptureApp;
  set selectedCaptureApp(CapturableApp? value) =>
      _captureController.selectCaptureApp(value);

  bool get captureSourceBlocked => _captureController.captureSourceBlocked;
  set captureSourceBlocked(bool value) =>
      _captureController.captureSourceBlocked = value;

  String? get captureSourceMessage => _captureController.captureSourceMessage;
  set captureSourceMessage(String? value) =>
      _captureController.captureSourceMessage = value;

  int get notificationCount => telemetryState.notificationCount;
  set notificationCount(int value) => telemetryState.notificationCount = value;

  double get telemetryRateHz => telemetryState.rateHz;
  set telemetryRateHz(double value) => telemetryState.rateHz = value;

  String get telemetryLastCategory => telemetryState.lastCategory;
  set telemetryLastCategory(String value) =>
      telemetryState.lastCategory = value;

  int get telemetryLastDeviceTimestamp => telemetryState.lastDeviceTimestamp;
  set telemetryLastDeviceTimestamp(int value) =>
      telemetryState.lastDeviceTimestamp = value;

  int get telemetryLastWallClockMs => telemetryState.lastWallClockMs;
  set telemetryLastWallClockMs(int value) =>
      telemetryState.lastWallClockMs = value;

  int get telemetryHdlcDroppedFrames => telemetryState.hdlcDroppedFrames;
  set telemetryHdlcDroppedFrames(int value) =>
      telemetryState.hdlcDroppedFrames = value;

  Map<String, int> get telemetryCategoryCounts => telemetryState.categoryCounts;
  int get telemetrySeenCategories => telemetryState.seenCategories;
  int get teleplotChannelCount => telemetryState.teleplotChannelCount;
  List<MapEntry<String, int>> get telemetryCategoryCountEntries =>
      telemetryState.categoryCountEntries;
  int get telemetryImuNotificationCount =>
      telemetryState.categoryCounts['lsm6dsox'] ?? 0;
  String get telemetryImuStreamingStatus =>
      _sessionController.imuStreamingStatus;
  String get telemetryImuCapabilityStatus {
    final FocstimCapabilities? caps = capabilities;
    if (caps == null) {
      return 'unknown';
    }
    return caps.lsm6dsox ? 'yes' : 'no';
  }

  List<MapEntry<String, double>> get teleplotEntries =>
      telemetryState.teleplotEntries;

  double get telemetryDeviceVolume => telemetryState.deviceVolume;
  set telemetryDeviceVolume(double value) =>
      telemetryState.deviceVolume = value;

  bool get telemetryDeviceVolumeLocked => telemetryState.deviceVolumeLocked;
  set telemetryDeviceVolumeLocked(bool value) =>
      telemetryState.deviceVolumeLocked = value;

  double get telemetryRmsA => telemetryState.rmsA;
  set telemetryRmsA(double value) => telemetryState.rmsA = value;

  double get telemetryRmsB => telemetryState.rmsB;
  set telemetryRmsB(double value) => telemetryState.rmsB = value;

  double get telemetryRmsC => telemetryState.rmsC;
  set telemetryRmsC(double value) => telemetryState.rmsC = value;

  double get telemetryRmsD => telemetryState.rmsD;
  set telemetryRmsD(double value) => telemetryState.rmsD = value;

  double get telemetryPeakA => telemetryState.peakA;
  set telemetryPeakA(double value) => telemetryState.peakA = value;

  double get telemetryPeakB => telemetryState.peakB;
  set telemetryPeakB(double value) => telemetryState.peakB = value;

  double get telemetryPeakC => telemetryState.peakC;
  set telemetryPeakC(double value) => telemetryState.peakC = value;

  double get telemetryPeakD => telemetryState.peakD;
  set telemetryPeakD(double value) => telemetryState.peakD = value;

  double get telemetryOutputPowerW => telemetryState.outputPowerW;
  set telemetryOutputPowerW(double value) =>
      telemetryState.outputPowerW = value;

  double get telemetryOutputPowerSkinW => telemetryState.outputPowerSkinW;
  set telemetryOutputPowerSkinW(double value) =>
      telemetryState.outputPowerSkinW = value;

  double get telemetryPeakCmd => telemetryState.peakCmd;
  set telemetryPeakCmd(double value) => telemetryState.peakCmd = value;

  double get telemetryOutputResistanceA => telemetryState.outputResistanceA;
  set telemetryOutputResistanceA(double value) =>
      telemetryState.outputResistanceA = value;

  double get telemetryOutputResistanceB => telemetryState.outputResistanceB;
  set telemetryOutputResistanceB(double value) =>
      telemetryState.outputResistanceB = value;

  double get telemetryOutputResistanceC => telemetryState.outputResistanceC;
  set telemetryOutputResistanceC(double value) =>
      telemetryState.outputResistanceC = value;

  double get telemetryOutputResistanceD => telemetryState.outputResistanceD;
  set telemetryOutputResistanceD(double value) =>
      telemetryState.outputResistanceD = value;

  double get telemetryOutputResistanceConstant =>
      telemetryState.outputResistanceConstant;
  set telemetryOutputResistanceConstant(double value) =>
      telemetryState.outputResistanceConstant = value;

  double get telemetryOutputReluctanceA => telemetryState.outputReluctanceA;
  set telemetryOutputReluctanceA(double value) =>
      telemetryState.outputReluctanceA = value;

  double get telemetryOutputReluctanceB => telemetryState.outputReluctanceB;
  set telemetryOutputReluctanceB(double value) =>
      telemetryState.outputReluctanceB = value;

  double get telemetryOutputReluctanceC => telemetryState.outputReluctanceC;
  set telemetryOutputReluctanceC(double value) =>
      telemetryState.outputReluctanceC = value;

  double get telemetryOutputReluctanceD => telemetryState.outputReluctanceD;
  set telemetryOutputReluctanceD(double value) =>
      telemetryState.outputReluctanceD = value;

  double get telemetrySkinResistanceA => telemetryState.skinResistanceA;
  set telemetrySkinResistanceA(double value) =>
      telemetryState.skinResistanceA = value;

  double get telemetrySkinResistanceB => telemetryState.skinResistanceB;
  set telemetrySkinResistanceB(double value) =>
      telemetryState.skinResistanceB = value;

  double get telemetrySkinResistanceC => telemetryState.skinResistanceC;
  set telemetrySkinResistanceC(double value) =>
      telemetryState.skinResistanceC = value;

  double get telemetrySkinResistanceD => telemetryState.skinResistanceD;
  set telemetrySkinResistanceD(double value) =>
      telemetryState.skinResistanceD = value;

  double get telemetrySkinReluctanceA => telemetryState.skinReluctanceA;
  set telemetrySkinReluctanceA(double value) =>
      telemetryState.skinReluctanceA = value;

  double get telemetrySkinReluctanceB => telemetryState.skinReluctanceB;
  set telemetrySkinReluctanceB(double value) =>
      telemetryState.skinReluctanceB = value;

  double get telemetrySkinReluctanceC => telemetryState.skinReluctanceC;
  set telemetrySkinReluctanceC(double value) =>
      telemetryState.skinReluctanceC = value;

  double get telemetrySkinReluctanceD => telemetryState.skinReluctanceD;
  set telemetrySkinReluctanceD(double value) =>
      telemetryState.skinReluctanceD = value;

  double get telemetryResistanceA => telemetryState.resistanceA;
  set telemetryResistanceA(double value) => telemetryState.resistanceA = value;

  double get telemetryResistanceB => telemetryState.resistanceB;
  set telemetryResistanceB(double value) => telemetryState.resistanceB = value;

  double get telemetryResistanceC => telemetryState.resistanceC;
  set telemetryResistanceC(double value) => telemetryState.resistanceC = value;

  double get telemetryResistanceD => telemetryState.resistanceD;
  set telemetryResistanceD(double value) => telemetryState.resistanceD = value;

  double get telemetryReluctanceA => telemetryState.reluctanceA;
  set telemetryReluctanceA(double value) => telemetryState.reluctanceA = value;

  double get telemetryReluctanceB => telemetryState.reluctanceB;
  set telemetryReluctanceB(double value) => telemetryState.reluctanceB = value;

  double get telemetryReluctanceC => telemetryState.reluctanceC;
  set telemetryReluctanceC(double value) => telemetryState.reluctanceC = value;

  double get telemetryReluctanceD => telemetryState.reluctanceD;
  set telemetryReluctanceD(double value) => telemetryState.reluctanceD = value;

  String get telemetrySystemVariant => telemetryState.systemVariant;
  set telemetrySystemVariant(String value) =>
      telemetryState.systemVariant = value;

  double get telemetrySystemTempStm32 => telemetryState.systemTempStm32;
  set telemetrySystemTempStm32(double value) =>
      telemetryState.systemTempStm32 = value;

  double get telemetrySystemTempBoard => telemetryState.systemTempBoard;
  set telemetrySystemTempBoard(double value) =>
      telemetryState.systemTempBoard = value;

  double get telemetrySystemVBus => telemetryState.systemVBus;
  set telemetrySystemVBus(double value) => telemetryState.systemVBus = value;

  double get telemetrySystemVRef => telemetryState.systemVRef;
  set telemetrySystemVRef(double value) => telemetryState.systemVRef = value;

  double get telemetrySystemVSysMin => telemetryState.systemVSysMin;
  set telemetrySystemVSysMin(double value) =>
      telemetryState.systemVSysMin = value;

  double get telemetrySystemVSysMax => telemetryState.systemVSysMax;
  set telemetrySystemVSysMax(double value) =>
      telemetryState.systemVSysMax = value;

  double get telemetrySystemVBoostMin => telemetryState.systemVBoostMin;
  set telemetrySystemVBoostMin(double value) =>
      telemetryState.systemVBoostMin = value;

  double get telemetrySystemVBoostMax => telemetryState.systemVBoostMax;
  set telemetrySystemVBoostMax(double value) =>
      telemetryState.systemVBoostMax = value;

  double get telemetrySystemBoostDutyCycle =>
      telemetryState.systemBoostDutyCycle;
  set telemetrySystemBoostDutyCycle(double value) =>
      telemetryState.systemBoostDutyCycle = value;

  double get telemetryActualPulseFrequency =>
      telemetryState.actualPulseFrequency;
  set telemetryActualPulseFrequency(double value) =>
      telemetryState.actualPulseFrequency = value;

  double get telemetryVDrive => telemetryState.vDrive;
  set telemetryVDrive(double value) => telemetryState.vDrive = value;

  double get telemetryTransformerUtilization =>
      telemetryState.transformerUtilization;
  set telemetryTransformerUtilization(double value) =>
      telemetryState.transformerUtilization = value;

  double get telemetryVoltageUtilization => telemetryState.voltageUtilization;
  set telemetryVoltageUtilization(double value) =>
      telemetryState.voltageUtilization = value;

  double get telemetryBatteryVoltage => telemetryState.batteryVoltage;
  set telemetryBatteryVoltage(double value) =>
      telemetryState.batteryVoltage = value;

  double get telemetryBatteryChargeRateWatt =>
      telemetryState.batteryChargeRateWatt;
  set telemetryBatteryChargeRateWatt(double value) =>
      telemetryState.batteryChargeRateWatt = value;

  double get telemetryBatterySoc => telemetryState.batterySoc;
  set telemetryBatterySoc(double value) => telemetryState.batterySoc = value;

  bool get telemetryWallPowerPresent => telemetryState.wallPowerPresent;
  set telemetryWallPowerPresent(bool value) =>
      telemetryState.wallPowerPresent = value;

  double get telemetryBatteryChipTemperature =>
      telemetryState.batteryChipTemperature;
  set telemetryBatteryChipTemperature(double value) =>
      telemetryState.batteryChipTemperature = value;

  int get telemetryAccX => telemetryState.accX;
  set telemetryAccX(int value) => telemetryState.accX = value;

  int get telemetryAccY => telemetryState.accY;
  set telemetryAccY(int value) => telemetryState.accY = value;

  int get telemetryAccZ => telemetryState.accZ;
  set telemetryAccZ(int value) => telemetryState.accZ = value;

  int get telemetryGyrX => telemetryState.gyrX;
  set telemetryGyrX(int value) => telemetryState.gyrX = value;

  int get telemetryGyrY => telemetryState.gyrY;
  set telemetryGyrY(int value) => telemetryState.gyrY = value;

  int get telemetryGyrZ => telemetryState.gyrZ;
  set telemetryGyrZ(int value) => telemetryState.gyrZ = value;

  double get telemetryPressurePa => telemetryState.pressurePa;
  set telemetryPressurePa(double value) => telemetryState.pressurePa = value;

  String get telemetryButtonState => telemetryState.buttonState;
  set telemetryButtonState(String value) => telemetryState.buttonState = value;

  int get telemetryButtonTimestampMs => telemetryState.buttonTimestampMs;
  set telemetryButtonTimestampMs(int value) =>
      telemetryState.buttonTimestampMs = value;

  String get telemetryDebugString => telemetryState.debugString;
  set telemetryDebugString(String value) => telemetryState.debugString = value;

  int get telemetryDebugAs5311Raw => telemetryState.debugAs5311Raw;
  set telemetryDebugAs5311Raw(int value) =>
      telemetryState.debugAs5311Raw = value;

  int get telemetryDebugAs5311Tracked => telemetryState.debugAs5311Tracked;
  set telemetryDebugAs5311Tracked(int value) =>
      telemetryState.debugAs5311Tracked = value;

  int get telemetryDebugAs5311Flags => telemetryState.debugAs5311Flags;
  set telemetryDebugAs5311Flags(int value) =>
      telemetryState.debugAs5311Flags = value;

  double get telemetryDebugEdgingFullPowerThreshold =>
      telemetryState.debugEdgingFullPowerThreshold;
  set telemetryDebugEdgingFullPowerThreshold(double value) =>
      telemetryState.debugEdgingFullPowerThreshold = value;

  double get telemetryDebugEdgingReducedPowerThreshold =>
      telemetryState.debugEdgingReducedPowerThreshold;
  set telemetryDebugEdgingReducedPowerThreshold(double value) =>
      telemetryState.debugEdgingReducedPowerThreshold = value;

  double get telemetryDebugEdgingReduction =>
      telemetryState.debugEdgingReduction;
  set telemetryDebugEdgingReduction(double value) =>
      telemetryState.debugEdgingReduction = value;

  double get _estimatedBpm => _beatMotion.estimatedBpm;

  double get _silenceFade => _beatMotion.silenceFade;

  OutputModeSelection get outputMode => settings.outputMode;
  set outputMode(OutputModeSelection value) => settings.outputMode = value;

  StimMode get stimMode => settings.stimMode;
  set stimMode(StimMode value) => settings.stimMode = value;

  double get sensitivity => settings.sensitivity;
  set sensitivity(double value) => settings.sensitivity = value;

  double get intensityCap => settings.intensityCap;
  set intensityCap(double value) => settings.intensityCap = value;

  double get carrierHz => settings.carrierHz;
  set carrierHz(double value) => settings.carrierHz = value;

  double get carrierMinHz => settings.carrierMinHz;
  set carrierMinHz(double value) => settings.carrierMinHz = value;

  double get carrierMaxHz => settings.carrierMaxHz;
  set carrierMaxHz(double value) => settings.carrierMaxHz = value;

  double get tauMicros => settings.tauMicros;
  set tauMicros(double value) => settings.tauMicros = value;

  bool get calibrationLocked => settings.calibrationLocked;
  set calibrationLocked(bool value) => settings.calibrationLocked = value;

  double get pulseWidthCycles => settings.pulseWidthCycles;
  set pulseWidthCycles(double value) => settings.pulseWidthCycles = value;

  double get pulseRiseTimeCycles => settings.pulseRiseTimeCycles;
  set pulseRiseTimeCycles(double value) => settings.pulseRiseTimeCycles = value;

  double get pulseIntervalRandomPercent => settings.pulseIntervalRandomPercent;
  set pulseIntervalRandomPercent(double value) =>
      settings.pulseIntervalRandomPercent = value;

  double get cal3Neutral => settings.cal3Neutral;
  set cal3Neutral(double value) => settings.cal3Neutral = value;

  double get cal3Right => settings.cal3Right;
  set cal3Right(double value) => settings.cal3Right = value;

  double get cal3Center => settings.cal3Center;
  set cal3Center(double value) => settings.cal3Center = value;

  // Canonical aliases for 3-phase calibration knobs:
  // A = neutral/up, B = left, C = right.
  double get cal3A => cal3Neutral;
  double get cal3B => cal3Right;
  double get cal3C => cal3Center;

  double get cal4A => settings.cal4A;
  set cal4A(double value) => settings.cal4A = value;

  double get cal4B => settings.cal4B;
  set cal4B(double value) => settings.cal4B = value;

  double get cal4C => settings.cal4C;
  set cal4C(double value) => settings.cal4C = value;

  double get cal4D => settings.cal4D;
  set cal4D(double value) => settings.cal4D = value;

  double get pulseMinHz => settings.pulseMinHz;
  set pulseMinHz(double value) => settings.pulseMinHz = value;

  double get pulseMaxHz => settings.pulseMaxHz;
  set pulseMaxHz(double value) => settings.pulseMaxHz = value;

  bool get manualPulseMode => settings.manualPulseMode;
  set manualPulseMode(bool value) => settings.manualPulseMode = value;

  double get manualPulseHz => settings.manualPulseHz;
  set manualPulseHz(double value) => settings.manualPulseHz = value;

  double get manualSmoothedAlpha => _manualSmoothedAlpha;
  double get manualSmoothedBeta => _manualSmoothedBeta;
  double get manualTargetAlpha => _manualTargetAlpha;
  double get manualTargetBeta => _manualTargetBeta;
  double get manualSmoothedE1 => _manualSmoothedE1;
  double get manualSmoothedE2 => _manualSmoothedE2;
  double get manualSmoothedE3 => _manualSmoothedE3;
  double get manualSmoothedE4 => _manualSmoothedE4;
  double get manualTargetE1 => _manualTargetE1;
  double get manualTargetE2 => _manualTargetE2;
  double get manualTargetE3 => _manualTargetE3;
  double get manualTargetE4 => _manualTargetE4;
  double get manualUserE4 => _manualUserE4;

  bool get carrierLfoEnabled => settings.carrierLfoEnabled;
  double get carrierLfoRateHz => settings.carrierLfoRateHz;
  double get carrierLfoDepth => settings.carrierLfoDepth;
  bool get pulseLfoEnabled => settings.pulseLfoEnabled;
  double get pulseLfoRateHz => settings.pulseLfoRateHz;
  double get pulseLfoDepth => settings.pulseLfoDepth;
  bool get carrierLocked => settings.carrierLocked;
  bool get pulseLocked => settings.pulseLocked;
  double get manualIntensity => settings.manualIntensity;
  bool get manualPaused => _manualPaused;
  double get manualIntensityRamp => _manualIntensityRamp;
  double get manualEffectiveCarrierHz =>
      _manualEffectiveCarrierHz > 0.0 ? _manualEffectiveCarrierHz : carrierHz;
  double get manualEffectivePulseHz =>
      _manualEffectivePulseHz > 0.0 ? _manualEffectivePulseHz : manualPulseHz;

  double get bassMonitorLowHz => settings.bassMonitorLowHz;
  set bassMonitorLowHz(double value) => settings.bassMonitorLowHz = value;

  double get bassMonitorHighHz => settings.bassMonitorHighHz;
  set bassMonitorHighHz(double value) => settings.bassMonitorHighHz = value;

  double get onsetSensitivityMin => settings.onsetSensitivityMin;
  set onsetSensitivityMin(double value) => settings.onsetSensitivityMin = value;

  double get onsetSensitivityMax => settings.onsetSensitivityMax;
  set onsetSensitivityMax(double value) => settings.onsetSensitivityMax = value;

  double get onsetSmoothing => settings.onsetSmoothing;
  set onsetSmoothing(double value) => settings.onsetSmoothing = value;

  List<List<AudioBand>> get onsetBandMapping => settings.onsetBandMapping;
  set onsetBandMapping(List<List<AudioBand>> value) =>
      settings.onsetBandMapping = value;

  bool get imuStreamingEnabled => settings.imuStreamingEnabled;
  set imuStreamingEnabled(bool value) => settings.imuStreamingEnabled = value;

  bool get tempoUnlockHoldEnabled => settings.tempoUnlockHoldEnabled;
  set tempoUnlockHoldEnabled(bool value) =>
      settings.tempoUnlockHoldEnabled = value;

  double get energyResponseStrength => settings.energyResponseStrength;
  set energyResponseStrength(double value) =>
      settings.energyResponseStrength = value;

  double get latencyCompensationMs => settings.latencyCompensationMs;
  set latencyCompensationMs(double value) =>
      settings.latencyCompensationMs = value;

  bool get adaptiveLeadEnabled => settings.adaptiveLeadEnabled;
  set adaptiveLeadEnabled(bool value) => settings.adaptiveLeadEnabled = value;

  double get adaptiveLeadCorrectionGain => settings.adaptiveLeadCorrectionGain;
  set adaptiveLeadCorrectionGain(double value) =>
      settings.adaptiveLeadCorrectionGain = value;

  bool get learningEnabled => settings.learningEnabled;
  set learningEnabled(bool value) => settings.learningEnabled = value;

  double get learningStrength => settings.learningStrength;
  set learningStrength(double value) => settings.learningStrength = value;

  double get beatRadiusAwareContrastStrength =>
      settings.beatRadiusAwareContrastStrength;
  set beatRadiusAwareContrastStrength(double value) =>
      settings.beatRadiusAwareContrastStrength = value;

  double get beatSpeedThresholdSpreadStrength =>
      settings.beatSpeedThresholdSpreadStrength;
  set beatSpeedThresholdSpreadStrength(double value) =>
      settings.beatSpeedThresholdSpreadStrength = value;

  List<BeatResponseCurve> get beatFourPhaseResponseCurves =>
      settings.beatFourPhaseResponseCurves;
  set beatFourPhaseResponseCurves(List<BeatResponseCurve> value) =>
      settings.beatFourPhaseResponseCurves = value;

  bool get hardFillGateEnabled => settings.hardFillGateEnabled;
  set hardFillGateEnabled(bool value) => settings.hardFillGateEnabled = value;

  double get motionDriveLevel => _heartbeatMotionState.motionDriveLevel;
  bool get buttonHoldMuted => _buttonStateMachine.buttonHoldMuted;
  double get estimatedBpm => _estimatedBpm;
  double get silenceFade => _silenceFade;
  List<String> get visibleElectrodeLabels =>
      outputMode == OutputModeSelection.fourPhase
      ? _fourPhaseElectrodeLabels
      : _threePhaseElectrodeLabels;
  List<double> get visibleElectrodeLevels =>
      outputMode == OutputModeSelection.fourPhase
      ? _electrodeStateController.fourPhaseElectrodeLevels
      : _electrodeStateController.threePhaseElectrodeLevels;

  bool get audioMotionActive {
    return _sessionRuntimeController.isAudioMotionActive(
      nowMs: DateTime.now().millisecondsSinceEpoch,
      sessionRunning: sessionRunning,
      captureRunning: captureRunning,
      liveGateOpen: liveGateOpen,
      motionDriveLevel: _heartbeatMotionState.motionDriveLevel,
    );
  }

  void toggleShowElectrodeBars() {
    showElectrodeBars = !showElectrodeBars;
    Haptics.selection();
    notifyListeners();
  }

  void setHost(String value) {
    host = value.trim();
  }

  void setPort(String value) {
    final int? parsed = int.tryParse(value.trim());
    if (parsed != null && parsed > 0 && parsed <= 65535) {
      port = parsed;
    }
  }

  Future<void> setOutputMode(OutputModeSelection mode) async {
    if (mode == outputMode) return;
    // Mode change — stop any running session to avoid mismatched output.
    if (sessionRunning) {
      await stopSession(emitHaptic: false);
    }
    outputMode = mode;
    Haptics.selection();
    _resetOrbitState();
    _resetElectrodeLevels();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  Future<void> setStimMode(StimMode mode) async {
    if (mode == stimMode) return;
    // Mode change — stop any running session to avoid mismatched stim.
    if (sessionRunning) {
      await stopSession(emitHaptic: false);
    }
    stimMode = mode;
    Haptics.selection();
    _resetOrbitState();
    _resetElectrodeLevels();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setOnsetBandMapping(List<List<AudioBand>> mapping) {
    if (mapping.length != 4) {
      return;
    }
    onsetBandMapping = mapping
        .map((List<AudioBand> bands) => List<AudioBand>.from(bands))
        .toList();
    Haptics.selection();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void selectCaptureApp(CapturableApp? app) {
    if (selectedCaptureApp?.packageName == app?.packageName) {
      return;
    }
    selectedCaptureApp = app;
    Haptics.selection();
    _savedCapturePackage = app?.packageName;
    _savedCaptureAppName = app?.appName;
    _savedCaptureUid = app?.uid;
    unawaited(_persistCaptureSelection());
    notifyListeners();
  }

  void setSensitivity(double value) {
    sensitivity = value;
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setIntensityCap(double value) {
    intensityCap = value;
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  /// Sets 3-phase manual target position from the touch pad.
  void setManualPosition(double alpha, double beta) {
    _manualTargetAlpha = alpha.clamp(-1.0, 1.0);
    _manualTargetBeta = beta.clamp(-1.0, 1.0);
    _syncManualDisplayWhenDriversStopped();
    settings.manualAlpha = _manualTargetAlpha;
    settings.manualBeta = _manualTargetBeta;
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  /// Sets 4-phase manual target electrode powers from a triangle-pad touch.
  /// [e1], [e2], [e3] are raw barycentric proportions (sum to 1.0). [e4] is
  /// the current D-electrode slider value (0–1). The touch ratios are stored
  /// so that moving the D slider later can recompute targets without compounding
  /// the budget reduction on already-reduced values.
  void setManualElectrodes(double e1, double e2, double e3, double e4) {
    final double sum = e1 + e2 + e3;
    if (sum > 1e-9) {
      _manualTouchRatioE1 = e1 / sum;
      _manualTouchRatioE2 = e2 / sum;
      _manualTouchRatioE3 = e3 / sum;
    }
    _applyDAxisBudget(e4);
  }

  /// Moves the D-electrode slider without changing the triangle-pad position.
  /// Updates both the user intent and the effective D target.
  void setManualDAxis(double e4) {
    _manualUserE4 = e4.clamp(0.0, 1.0);
    _applyDAxisBudget(e4);
  }

  void _applyDAxisBudget(double e4) {
    final double d = e4.clamp(0.0, 1.0);
    final double budget = 1.0 - d;
    _manualTargetE1 = (_manualTouchRatioE1 * budget).clamp(0.0, 1.0);
    _manualTargetE2 = (_manualTouchRatioE2 * budget).clamp(0.0, 1.0);
    _manualTargetE3 = (_manualTouchRatioE3 * budget).clamp(0.0, 1.0);
    _manualTargetE4 = d;
    _syncManualDisplayWhenDriversStopped();
    settings.manualE1 = _manualTargetE1;
    settings.manualE2 = _manualTargetE2;
    settings.manualE3 = _manualTargetE3;
    settings.manualE4 = _manualTargetE4;
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void _syncManualDisplayWhenDriversStopped() {
    if (_heartbeatLoop.running || _calibrationPreviewTimer != null) {
      return;
    }

    _manualSmoothedAlpha = _manualTargetAlpha;
    _manualSmoothedBeta = _manualTargetBeta;
    _manualSmoothedE1 = _manualTargetE1;
    _manualSmoothedE2 = _manualTargetE2;
    _manualSmoothedE3 = _manualTargetE3;
    _manualSmoothedE4 = _manualTargetE4;

    if (outputMode == OutputModeSelection.fourPhase) {
      _updateFourPhaseElectrodeLevels(
        e1: _manualSmoothedE1,
        e2: _manualSmoothedE2,
        e3: _manualSmoothedE3,
        e4: _manualSmoothedE4,
      );
      return;
    }

    _updateThreePhaseElectrodeLevels(
      alpha: _manualSmoothedAlpha,
      beta: _manualSmoothedBeta,
      outputScale: 1.0,
    );
  }

  void setManualIntensity(double value) {
    settings.manualIntensity = value.clamp(0.0, 100.0);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setManualPaused(bool paused) {
    if (_manualPaused == paused) {
      return;
    }
    _manualPaused = paused;
    notifyListeners();
  }

  void setCarrierLocked(bool locked) {
    settings.carrierLocked = locked;
    if (locked) {
      Haptics.medium();
    } else {
      Haptics.light();
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setPulseLocked(bool locked) {
    settings.pulseLocked = locked;
    if (locked) {
      Haptics.medium();
    } else {
      Haptics.light();
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCarrierLfo({
    required bool enabled,
    required double rateHz,
    required double depth,
  }) {
    settings.carrierLfoEnabled = enabled;
    settings.carrierLfoRateHz = rateHz.clamp(0.05, 10.0);
    settings.carrierLfoDepth = depth.clamp(0.0, 1.0);
    if (!enabled) {
      _carrierLfoPhase = 0.0;
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setPulseLfo({
    required bool enabled,
    required double rateHz,
    required double depth,
  }) {
    settings.pulseLfoEnabled = enabled;
    settings.pulseLfoRateHz = rateHz.clamp(0.05, 10.0);
    settings.pulseLfoDepth = depth.clamp(0.0, 1.0);
    if (!enabled) {
      _pulseLfoPhase = 0.0;
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCarrierHz(double value) {
    if (carrierLocked) {
      return;
    }
    carrierHz = value.clamp(carrierMinHz, carrierMaxHz);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCarrierRange(double minHz, double maxHz) {
    carrierMinHz = minHz.clamp(300.0, 2000.0);
    carrierMaxHz = maxHz.clamp(300.0, 2000.0);
    if (carrierMinHz > carrierMaxHz) {
      carrierMinHz = carrierMaxHz;
    }
    // Re-clamp the user's current pick to stay within the new range.
    carrierHz = carrierHz.clamp(carrierMinHz, carrierMaxHz);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setTauMicros(double value) {
    tauMicros = value.clamp(0.0, 1000.0);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCalibrationLocked(bool locked) {
    calibrationLocked = locked;
    if (locked) {
      Haptics.medium();
    } else {
      Haptics.light();
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCalibrationPattern(CalibrationPattern pattern) {
    // Block calibration patterns while music capture is actively running.
    if (pattern != CalibrationPattern.none &&
        captureRunning &&
        sessionRunning) {
      lastError =
          'Calibration pattern unavailable while music capture is active';
      notifyListeners();
      return;
    }
    final CalibrationPattern previous = calibrationPattern;
    if (previous != pattern) {
      Haptics.selection();
    }
    _calibrationController.setPattern(pattern);
    if (pattern != CalibrationPattern.none) {
      if (pattern == CalibrationPattern.manual) {
        _initializeManualStateFromSettings();
      } else {
        _calibrationController.resetAngle();
      }
      // Start local preview for responsive UI while connecting.
      _startCalibrationPreview();
      // Auto-start a calibration session (connect + startSignal, no audio).
      if (!sessionRunning) {
        startCalibrationSession().catchError((Object e) {
          // startCalibrationSession already sets lastError and resets state.
        });
      }
    } else {
      _stopCalibrationPreview();
      _resetElectrodeLevels();
      _manualPaused = true;
      _manualIntensityRamp = 0.0;
      _manualEffectiveCarrierHz = carrierHz;
      _manualEffectivePulseHz = manualPulseHz;
      // Stop the session only if we were previously running a calibration
      // pattern (i.e. a mode change triggered this, not just leaving screen).
      if (previous != CalibrationPattern.none && sessionRunning) {
        stopSession();
      }
    }
    notifyListeners();
  }

  void setCalibrationPatternSpeed(double rps) {
    _calibrationController.setPatternSpeed(rps);
    notifyListeners();
  }

  void setPulseWidthCycles(double value) {
    pulseWidthCycles = value.clamp(4.0, 100.0);
    _enforcePulseGeometryConstraint();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setPulseRiseTimeCycles(double value) {
    pulseRiseTimeCycles = value.clamp(2.0, 100.0);
    _enforcePulseGeometryConstraint();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  bool _enforcePulseGeometryConstraint() {
    final double previousWidth = pulseWidthCycles;
    final double previousRise = pulseRiseTimeCycles;

    pulseWidthCycles = pulseWidthCycles.clamp(4.0, 100.0);
    final double maxRiseCycles = pulseWidthCycles * 0.9;
    pulseRiseTimeCycles = pulseRiseTimeCycles.clamp(2.0, maxRiseCycles);

    return pulseWidthCycles != previousWidth ||
        pulseRiseTimeCycles != previousRise;
  }

  void setPulseIntervalRandomPercent(double value) {
    pulseIntervalRandomPercent = value.clamp(0.0, 100.0);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCal3Neutral(double value) {
    cal3Neutral = value.clamp(-6.0, 6.0);
    _sendCalibrationAxes();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCal3Right(double value) {
    cal3Right = value.clamp(-6.0, 6.0);
    _sendCalibrationAxes();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCal3Center(double value) {
    cal3Center = value.clamp(-6.0, 0.0);
    _sendCalibrationAxes();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCal3A(double value) => setCal3Neutral(value);

  void setCal3B(double value) => setCal3Right(value);

  void setCal3C(double value) => setCal3Center(value);

  void setCal4A(double value) {
    cal4A = value.clamp(-6.0, 6.0);
    _sendCalibrationAxes();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCal4B(double value) {
    cal4B = value.clamp(-6.0, 6.0);
    _sendCalibrationAxes();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCal4C(double value) {
    cal4C = value.clamp(-6.0, 6.0);
    _sendCalibrationAxes();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setCal4D(double value) {
    cal4D = value.clamp(-6.0, 6.0);
    _sendCalibrationAxes();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void _sendCalibrationAxes() {
    if (!_api.isConnected || !sessionRunning) return;
    if (outputMode == OutputModeSelection.threePhase) {
      // Canonical mapping: A=N (UP), B=L (LEFT), C=R (firmware CENTER axis).
      _api.moveAxis(enums.AxisType.AXIS_CALIBRATION_3_UP, cal3Neutral, 40);
      _api.moveAxis(enums.AxisType.AXIS_CALIBRATION_3_LEFT, cal3Right, 40);
      _api.moveAxis(enums.AxisType.AXIS_CALIBRATION_3_CENTER, cal3Center, 40);
    } else {
      _api.moveAxis(enums.AxisType.AXIS_CALIBRATION_4_A, cal4A, 40);
      _api.moveAxis(enums.AxisType.AXIS_CALIBRATION_4_B, cal4B, 40);
      _api.moveAxis(enums.AxisType.AXIS_CALIBRATION_4_C, cal4C, 40);
      _api.moveAxis(enums.AxisType.AXIS_CALIBRATION_4_D, cal4D, 40);
    }
  }

  void setPulseRange(double minHz, double maxHz) {
    pulseMinHz = minHz.clamp(5.0, 100.0);
    pulseMaxHz = maxHz.clamp(5.0, 100.0);
    if (pulseMinHz > pulseMaxHz) {
      pulseMinHz = pulseMaxHz;
    }
    if (manualPulseMode) {
      manualPulseHz = manualPulseHz.clamp(pulseMinHz, pulseMaxHz);
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setManualPulseMode(bool manual) {
    if (manualPulseMode != manual) {
      Haptics.selection();
    }
    manualPulseMode = manual;
    if (manual) {
      manualPulseHz = manualPulseHz.clamp(pulseMinHz, pulseMaxHz);
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setManualPulseHz(double value) {
    if (pulseLocked) {
      return;
    }
    manualPulseHz = value.clamp(pulseMinHz, pulseMaxHz);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setBassMonitorRange(double lowHz, double highHz) {
    bassMonitorLowHz = lowHz.clamp(20.0, 500.0);
    bassMonitorHighHz = highHz.clamp(20.0, 500.0);
    if (bassMonitorLowHz > bassMonitorHighHz) {
      bassMonitorLowHz = bassMonitorHighHz;
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setOnsetSensitivityWindow(double minValue, double maxValue) {
    onsetSensitivityMin = minValue.clamp(0.0, 1.0);
    onsetSensitivityMax = maxValue.clamp(0.0, 1.0);
    if (onsetSensitivityMin > onsetSensitivityMax) {
      onsetSensitivityMin = onsetSensitivityMax;
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setOnsetSmoothing(double value) {
    onsetSmoothing = value.clamp(0.0, 100.0);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setImuStreamingEnabled(bool enabled) {
    if (enabled == imuStreamingEnabled) {
      return;
    }
    imuStreamingEnabled = enabled;
    Haptics.selection();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setTempoUnlockHoldEnabled(bool enabled) {
    if (enabled == tempoUnlockHoldEnabled) {
      return;
    }
    tempoUnlockHoldEnabled = enabled;
    Haptics.selection();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setEnergyResponseStrength(double value) {
    energyResponseStrength = value.clamp(0.0, 2.0);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setLatencyCompensationMs(double value) {
    latencyCompensationMs = value.clamp(-100.0, 100.0);
    if (!sessionRunning || !adaptiveLeadEnabled) {
      _adaptiveLead = AdaptiveLead(
        baseLead: latencyCompensationMs,
        correctionGain: adaptiveLeadCorrectionGain,
      );
      _adaptiveLeadLastGateOpen = false;
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setAdaptiveLeadCorrectionGain(double value) {
    adaptiveLeadCorrectionGain = value.clamp(0.05, 1.0);
    _adaptiveLead.correctionGain = adaptiveLeadCorrectionGain;
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setAdaptiveLeadEnabled(bool enabled) {
    if (enabled == adaptiveLeadEnabled) {
      return;
    }
    adaptiveLeadEnabled = enabled;
    Haptics.selection();
    _adaptiveLead = AdaptiveLead(
      baseLead: latencyCompensationMs,
      correctionGain: adaptiveLeadCorrectionGain,
    );
    _adaptiveLeadLastGateOpen = false;
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setLearningEnabled(bool enabled) {
    if (enabled == learningEnabled) {
      return;
    }
    learningEnabled = enabled;
    Haptics.selection();
    if (!enabled) {
      _committedCadenceHint = 2;
      if (!sessionRunning) {
        _learningAdapter.fullReset();
        _learningLastGateOpen = false;
      }
    }
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setLearningStrength(double value) {
    learningStrength = value.clamp(0.0, 1.0);
    _learningAdapter.learningStrength = learningStrength;
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setBeatRadiusAwareContrastStrength(double value) {
    beatRadiusAwareContrastStrength = value.clamp(0.0, 1.0);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setBeatSpeedThresholdSpreadStrength(double value) {
    beatSpeedThresholdSpreadStrength = value.clamp(0.0, 1.0);
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setBeatFourPhaseResponseCurve(
    int electrodeIndex,
    BeatResponseCurve curve,
  ) {
    if (electrodeIndex < 0 || electrodeIndex > 3) {
      return;
    }
    final List<BeatResponseCurve> next = beatFourPhaseResponseCurves
        .map((BeatResponseCurve item) => item)
        .toList();
    if (next.length < 4) {
      next
        ..clear()
        ..addAll(defaultBeatFourPhaseResponseCurves);
    }
    if (next[electrodeIndex] == curve) {
      return;
    }
    next[electrodeIndex] = curve;
    beatFourPhaseResponseCurves = next;
    Haptics.selection();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  void setHardFillGateEnabled(bool enabled) {
    if (enabled == hardFillGateEnabled) {
      return;
    }
    hardFillGateEnabled = enabled;
    Haptics.selection();
    unawaited(_persistUserSettings());
    notifyListeners();
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final SharedPreferences prefs = await _getPrefs();

      bool shouldNotify = false;

      final String? savedHost = prefs.getString(UserSettings.prefsHostKey);
      if (savedHost != null && savedHost.trim().isNotEmpty) {
        final String normalizedHost = savedHost.trim();
        if (normalizedHost != host) {
          host = normalizedHost;
          shouldNotify = true;
        }
      }

      final int? savedPort = prefs.getInt(UserSettings.prefsPortKey);
      if (savedPort != null &&
          savedPort > 0 &&
          savedPort <= 65535 &&
          savedPort != port) {
        port = savedPort;
        shouldNotify = true;
      }

      final List<String>? savedHistory = prefs.getStringList(
        UserSettings.prefsHostHistoryKey,
      );
      if (savedHistory != null && savedHistory.isNotEmpty) {
        hostHistory = savedHistory;
        shouldNotify = true;
      }

      final String? saved = prefs.getString(
        UserSettings.prefsCapturePackageKey,
      );
      if (saved != null && saved.isNotEmpty) {
        _savedCapturePackage = saved;
        _savedCaptureAppName = prefs.getString(
          UserSettings.prefsCaptureAppNameKey,
        );
        _savedCaptureUid = prefs.getInt(UserSettings.prefsCaptureUidKey);
        final CapturableApp? restored = captureApps
            .cast<CapturableApp?>()
            .firstWhere(
              (CapturableApp? app) => app?.packageName == saved,
              orElse: () => null,
            );
        if (restored != null) {
          selectedCaptureApp = restored;
          _savedCaptureAppName = restored.appName;
          _savedCaptureUid = restored.uid;
          shouldNotify = true;
        } else {
          final String fallbackName =
              (_savedCaptureAppName == null || _savedCaptureAppName!.isEmpty)
              ? saved
              : _savedCaptureAppName!;
          selectedCaptureApp = CapturableApp(
            packageName: saved,
            appName: fallbackName,
            uid: _savedCaptureUid ?? -1,
          );
          shouldNotify = true;
        }
      }

      if (settings.restoreFromPreferences(prefs)) {
        shouldNotify = true;
      }

      if (_enforcePulseGeometryConstraint()) {
        shouldNotify = true;
        unawaited(_persistUserSettings());
      }

      if (shouldNotify) {
        notifyListeners();
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[ConnectionProvider] Failed to load saved preferences: '
        '$error\n$stackTrace',
      );
      // SharedPreferences may be unavailable in test environments.
    }
  }

  void _deferStartupHydration() {
    // Keep first paint lean by deferring preference replay slightly.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 250), () async {
        await _ensureSavedPreferencesLoaded();
      }),
    );
  }

  Future<void> _ensureSavedPreferencesLoaded() async {
    if (_savedPreferencesLoaded) {
      return;
    }

    final Future<void>? inFlight = _savedPreferencesLoadFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final Future<void> loadFuture = _loadSavedPreferences();
    _savedPreferencesLoadFuture = loadFuture;
    try {
      await loadFuture;
    } finally {
      _savedPreferencesLoaded = true;
      _savedPreferencesLoadFuture = null;
    }
  }

  Future<void> _persistConnectionSettings() async {
    try {
      final SharedPreferences prefs = await _getPrefs();
      await prefs.setString(UserSettings.prefsHostKey, host.trim());
      await prefs.setInt(UserSettings.prefsPortKey, port);
    } catch (error, stackTrace) {
      debugPrint(
        '[ConnectionProvider] Failed to persist connection settings: '
        '$error\n$stackTrace',
      );
      // Ignore persistence failures; connection can continue without stored settings.
    }
  }

  Future<void> _addHostToHistory(String newHost) async {
    if (newHost.isEmpty) return;
    // Remove if already present, then insert at front (most recent first)
    hostHistory.remove(newHost);
    hostHistory.insert(0, newHost);
    // Cap at 10 entries
    if (hostHistory.length > 10) {
      hostHistory = hostHistory.sublist(0, 10);
    }
    try {
      final SharedPreferences prefs = await _getPrefs();
      await prefs.setStringList(UserSettings.prefsHostHistoryKey, hostHistory);
    } catch (error, stackTrace) {
      debugPrint(
        '[ConnectionProvider] Failed to persist host history: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _persistCaptureSelection() async {
    try {
      final SharedPreferences prefs = await _getPrefs();

      final String? saved = _savedCapturePackage;
      if (saved == null || saved.isEmpty) {
        await prefs.remove(UserSettings.prefsCapturePackageKey);
        await prefs.remove(UserSettings.prefsCaptureAppNameKey);
        await prefs.remove(UserSettings.prefsCaptureUidKey);
      } else {
        await prefs.setString(UserSettings.prefsCapturePackageKey, saved);

        final String? appName = _savedCaptureAppName;
        if (appName == null || appName.isEmpty) {
          await prefs.remove(UserSettings.prefsCaptureAppNameKey);
        } else {
          await prefs.setString(UserSettings.prefsCaptureAppNameKey, appName);
        }

        final int? uid = _savedCaptureUid;
        if (uid == null) {
          await prefs.remove(UserSettings.prefsCaptureUidKey);
        } else {
          await prefs.setInt(UserSettings.prefsCaptureUidKey, uid);
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[ConnectionProvider] Failed to persist capture selection: '
        '$error\n$stackTrace',
      );
      // Ignore persistence failures; capture still works without stored selection.
    }
  }

  Future<void> _persistUserSettings() async {
    settings.schedulePersist(sharedPreferences: _prefs);
  }

  Future<void> refreshCaptureApps() async {
    await _ensureSavedPreferencesLoaded();

    try {
      await _captureController.refreshCaptureApps(
        preferredPackage:
            selectedCaptureApp?.packageName ?? _savedCapturePackage,
      );

      if (selectedCaptureApp != null) {
        _savedCapturePackage = selectedCaptureApp!.packageName;
        _savedCaptureAppName = selectedCaptureApp!.appName;
        _savedCaptureUid = selectedCaptureApp!.uid;
        unawaited(_persistCaptureSelection());
      }

      lastError = null;
      notifyListeners();
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> requestProjectionConsent() async {
    try {
      final bool granted = await _captureController.requestProjectionConsent();
      if (!granted) {
        lastError = 'Projection permission is required for app audio capture.';
      } else {
        lastError = null;
      }
      notifyListeners();
      return granted;
    } catch (error) {
      lastError = error.toString();
      captureStatus = 'projection_error';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startAudioCapture({bool emitHaptic = true}) async {
    await _ensureSavedPreferencesLoaded();

    if (captureRunning) {
      return;
    }

    final int captureChannels = stimMode == StimMode.onset ? 2 : 1;

    if (selectedCaptureApp == null &&
        _savedCapturePackage != null &&
        _savedCapturePackage!.isNotEmpty) {
      final String savedPackage = _savedCapturePackage!;

      try {
        await _captureController.refreshCaptureApps(
          preferredPackage: savedPackage,
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[ConnectionProvider] refreshCaptureApps fallback failed before '
          'capture start: $error\n$stackTrace',
        );
      }

      if (selectedCaptureApp == null) {
        final String fallbackName =
            (_savedCaptureAppName == null || _savedCaptureAppName!.isEmpty)
            ? savedPackage
            : _savedCaptureAppName!;
        selectedCaptureApp = CapturableApp(
          packageName: savedPackage,
          appName: fallbackName,
          uid: _savedCaptureUid ?? -1,
        );
      } else {
        _savedCapturePackage = selectedCaptureApp!.packageName;
        _savedCaptureAppName = selectedCaptureApp!.appName;
        _savedCaptureUid = selectedCaptureApp!.uid;
        unawaited(_persistCaptureSelection());
      }
    }

    try {
      await _captureController.startAudioCapture(channels: captureChannels);
      _resetLiveAudioState();
      _audioCaptureManager.markCaptureStarted(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        channels: captureChannels,
      );
      if (emitHaptic) {
        Haptics.medium();
      }
      lastError = null;
      notifyListeners();
    } catch (error) {
      lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopAudioCapture({
    bool releaseProjection = false,
    bool emitHaptic = true,
  }) async {
    final bool wasRunning = captureRunning;
    if (!wasRunning && !releaseProjection) {
      return;
    }

    final String? stopError = await _captureController.stopAudioCapture(
      releaseProjection: releaseProjection,
    );
    if (stopError != null) {
      lastError = stopError;
    }

    _resetLiveAudioState();
    if (emitHaptic && wasRunning) {
      Haptics.medium();
    }
    notifyListeners();
  }

  /// Connect to the device without starting signal generation. Used by the
  /// "Test Connection" button on DeviceScreen to verify reachability and read firmware.
  Future<void> testConnect() async {
    if (sessionRunning) return;
    try {
      lastError = null;
      await _persistConnectionSettings();
      await _addHostToHistory(host.trim());
      await _sessionController.connectOnly(host, port);
      Haptics.light();
      notifyListeners();
    } catch (error) {
      lastError = error.toString();
      Haptics.errorDouble();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await stopSession(emitHaptic: false);
    Haptics.disconnectDouble();
  }

  double _normalizedPulseIntervalRandom() {
    return _sessionStartPrimer.normalizePulseIntervalRandomPercent(
      pulseIntervalRandomPercent,
    );
  }

  double _startupRampAt(double nowSec) {
    return _sessionRuntimeController.startupRampAt(
      nowSec: nowSec,
      startupRampDurationSec: _startupRampDurationSec,
    );
  }

  Future<void> _primeSessionParametersForStart() async {
    if (!_api.isConnected) {
      return;
    }

    _enforcePulseGeometryConstraint();

    final double initialPulseHz = _sessionStartPrimer.initialPulseFrequencyHz(
      pulseMinHz: pulseMinHz,
      pulseMaxHz: pulseMaxHz,
    );
    final double initialCarrierHz = carrierHz.clamp(carrierMinHz, carrierMaxHz);
    _heartbeatMotionState.setInitialPulseFrequency(initialPulseHz);

    await _sessionStartPrimer.primeAxes(
      moveAxis: _api.moveAxis,
      outputMode: outputMode,
      initialCarrierHz: initialCarrierHz,
      initialPulseHz: initialPulseHz,
      pulseWidthCycles: pulseWidthCycles,
      pulseRiseTimeCycles: pulseRiseTimeCycles,
      normalizedPulseIntervalRandom: _normalizedPulseIntervalRandom(),
      cal3Neutral: cal3Neutral,
      cal3Right: cal3Right,
      cal3Center: cal3Center,
      cal4A: cal4A,
      cal4B: cal4B,
      cal4C: cal4C,
      cal4D: cal4D,
    );
  }

  Future<void> startSession() {
    return _startSessionInternal(enableAudioCapture: true);
  }

  /// Connect to the FOC-Stim and start signal generation for calibration
  /// only — no audio capture, no media projection, no app picker.
  Future<void> startCalibrationSession() {
    return _startSessionInternal(enableAudioCapture: false);
  }

  Future<void> _startSessionInternal({required bool enableAudioCapture}) async {
    _sessionRuntimeController.beginSession();

    try {
      _resetTelemetry();
      await _sessionController.prepareAndStartSignal(
        host: host,
        port: port,
        outputMode: outputMode,
        enableImuStreaming: imuStreamingEnabled,
        beforeStartSignal: () async {
          await _persistConnectionSettings();
          await _addHostToHistory(host.trim());
          if (enableAudioCapture) {
            await startAudioCapture(emitHaptic: false);
          }

          // Match desktop startup semantics: prime axis/calibration values
          // before enabling signal generation.
          await _primeSessionParametersForStart();
        },
        onConnectionLost: _handleConnectionLost,
      );

      _resetButtonHoldState(resetMute: true);
      _adaptiveLead = AdaptiveLead(
        baseLead: latencyCompensationMs,
        correctionGain: adaptiveLeadCorrectionGain,
      );
      _adaptiveLeadLastGateOpen = false;
      _learningAdapter.learningStrength = learningStrength.clamp(0.0, 1.0);
      _learningAdapter.fullReset();
      _committedCadenceHint = 2;
      _learningLastGateOpen = false;
      await _learningAdapter.loadFromAsset(_learningModelAssetPath);
      _sessionController.markSessionRunning(true);
      Haptics.medium();
      lastError = null;
      _startHeartbeat();
      notifyListeners();
    } catch (error) {
      _sessionRuntimeController.clearSessionClock();
      _resetButtonHoldState(resetMute: true);
      _sessionController.resetImuState();
      _sessionController.markSessionRunning(false);
      _calibrationController.setPattern(CalibrationPattern.none);
      _stopCalibrationPreview();
      if (enableAudioCapture) {
        await stopAudioCapture(emitHaptic: false);
      }
      await _sessionController.disconnect();
      Haptics.errorDouble();
      lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopSession({bool emitHaptic = true}) async {
    final bool wasRunning = sessionRunning;
    _heartbeatLoop.stop();
    _sessionRuntimeController.clearSessionClock();
    _sessionController.stopWatchdog();
    _resetButtonHoldState(resetMute: true);
    await stopAudioCapture(emitHaptic: false);
    _sessionController.markSessionRunning(false);
    _calibrationController.setPattern(CalibrationPattern.none);
    _stopCalibrationPreview();
    _resetElectrodeLevels();
    _sessionRuntimeController.resetMotionActivity();
    notifyListeners();

    try {
      await _sessionController.stopSignalSession();
      lastError = null;
    } catch (error) {
      lastError = error.toString();
    }
    if (emitHaptic && wasRunning) {
      Haptics.medium();
    }
    notifyListeners();
  }

  void _handleConnectionLost() {
    // --- Fail-closed: stop everything locally (no RPCs — device is gone). ---
    _heartbeatLoop.stop();
    _sessionRuntimeController.clearSessionClock();
    _sessionController.handleConnectionLost();
    _resetButtonHoldState(resetMute: true);
    _sessionController.markSessionRunning(false);
    unawaited(stopAudioCapture(emitHaptic: false));
    _sessionRuntimeController.resetMotionActivity();

    // Force the TCP socket closed so the API service resets cleanly.
    unawaited(_sessionController.disconnect());

    // Reset calibration pattern — device is gone.
    _calibrationController.setPattern(CalibrationPattern.none);
    _stopCalibrationPreview();
    _resetElectrodeLevels();

    Haptics.disconnectDouble();
    lastError = 'Connection lost. Press START to reconnect.';
    notifyListeners();
  }

  void _resetButtonHoldState({required bool resetMute}) {
    _buttonStateMachine.reset(resetMute: resetMute);
  }

  void _applyButtonStateMachineAction(ButtonStateMachineAction action) {
    switch (action) {
      case ButtonStateMachineAction.toggleMute:
        if (!sessionRunning ||
            connectionState != FocstimConnectionState.connected) {
          return;
        }
        _buttonStateMachine.toggleMute();
        if (_buttonStateMachine.buttonHoldMuted) {
          Haptics.medium();
        } else {
          Haptics.light();
        }
        if (_buttonStateMachine.buttonHoldMuted) {
          // Hard mute immediately on hold trigger, but keep session alive.
          _heartbeatMotionState.setMotionDriveLevel(0.0);
          _sessionRuntimeController.resetMotionActivity();
          _resetElectrodeLevels();
          unawaited(
            _api
                .moveAxis(enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS, 0.0, 0)
                .catchError((Object error, StackTrace stackTrace) {
                  debugPrint(
                    '[ConnectionProvider] Failed to hard-mute waveform '
                    'amplitude: $error\n$stackTrace',
                  );
                }),
          );
        }
        notifyListeners();
        break;
      case ButtonStateMachineAction.toggleVolumeLock:
        final bool newLocked = !telemetryDeviceVolumeLocked;
        if (newLocked) {
          Haptics.medium();
        } else {
          Haptics.light();
        }
        _api.lockDeviceVolume(newLocked).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint(
            '[ConnectionProvider] Failed to toggle device volume lock: '
            '$error\n$stackTrace',
          );
        });
        break;
      case ButtonStateMachineAction.disconnect:
        unawaited(disconnect());
        break;
    }
  }

  void _handleHardwareButtonState(enums.ButtonState state) {
    _buttonStateMachine.handleHardwareButtonState(
      state: state,
      onAction: _applyButtonStateMachineAction,
    );
  }

  void clearTelemetry() {
    _resetTelemetry();
    Haptics.light();
    notifyListeners();
  }

  void _handleDeviceNotification(rpc.Notification notification) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    telemetryState.recordNotification(
      notification: notification,
      nowMs: nowMs,
      droppedFrames: _api.hdlcDroppedFrameCount,
    );

    final rpc.Notification_Notification kind = notification.whichNotification();

    if (kind == rpc.Notification_Notification.notificationButtonPress) {
      _handleHardwareButtonState(notification.notificationButtonPress.state);
    }

    telemetryState.applyNotificationPayload(notification: notification);

    notifyListeners();
  }

  void _resetTelemetry() {
    _heartbeatLoop.resetDeltaSyncState();
    telemetryState.clear();
  }

  void _startHeartbeat() {
    _stopCalibrationPreview(); // Heartbeat takes over.
    _heartbeatLoop.start(
      interval: const Duration(milliseconds: 33),
      onTick: () {
        unawaited(_sendHeartbeatTick());
      },
    );
  }

  void _initializeManualStateFromSettings() {
    _manualTargetAlpha = settings.manualAlpha.clamp(-1.0, 1.0).toDouble();
    _manualTargetBeta = settings.manualBeta.clamp(-1.0, 1.0).toDouble();
    _manualTargetE1 = settings.manualE1.clamp(0.0, 1.0).toDouble();
    _manualTargetE2 = settings.manualE2.clamp(0.0, 1.0).toDouble();
    _manualTargetE3 = settings.manualE3.clamp(0.0, 1.0).toDouble();
    _manualTargetE4 = settings.manualE4.clamp(0.0, 1.0).toDouble();
    _manualUserE4 = _manualTargetE4;

    // Reconstruct raw touch ratios from persisted budgeted values by
    // un-applying the stored D budget, so the D slider works correctly
    // on the first use after a restart.
    final double budget = 1.0 - _manualTargetE4;
    if (budget > 1e-9) {
      final double sum = _manualTargetE1 + _manualTargetE2 + _manualTargetE3;
      if (sum > 1e-9) {
        _manualTouchRatioE1 = _manualTargetE1 / sum;
        _manualTouchRatioE2 = _manualTargetE2 / sum;
        _manualTouchRatioE3 = _manualTargetE3 / sum;
      }
    }

    _manualSmoothedAlpha = _manualTargetAlpha;
    _manualSmoothedBeta = _manualTargetBeta;
    _manualSmoothedE1 = _manualTargetE1;
    _manualSmoothedE2 = _manualTargetE2;
    _manualSmoothedE3 = _manualTargetE3;
    _manualSmoothedE4 = _manualTargetE4;

    _carrierLfoPhase = 0.0;
    _pulseLfoPhase = 0.0;
    _manualPaused = true;
    _manualIntensityRamp = 0.0;
    _manualEffectiveCarrierHz = carrierHz.clamp(carrierMinHz, carrierMaxHz);
    _manualEffectivePulseHz = manualPulseHz.clamp(pulseMinHz, pulseMaxHz);
  }

  double _stepTowards(double current, double target, double maxStep) {
    final double delta = (target - current).clamp(-maxStep, maxStep);
    return current + delta;
  }

  void _updateManualEffectiveFrequencies(double dtSec) {
    double nextCarrier = carrierHz.clamp(carrierMinHz, carrierMaxHz);
    if (carrierLfoEnabled) {
      _carrierLfoPhase += 2.0 * math.pi * carrierLfoRateHz * dtSec;
      final double amplitude =
          ((carrierMaxHz - carrierMinHz) * 0.5) * carrierLfoDepth;
      nextCarrier = (nextCarrier + math.sin(_carrierLfoPhase) * amplitude)
          .clamp(carrierMinHz, carrierMaxHz);
    }
    _manualEffectiveCarrierHz = nextCarrier;

    double nextPulse = manualPulseHz.clamp(pulseMinHz, pulseMaxHz);
    if (pulseLfoEnabled) {
      _pulseLfoPhase += 2.0 * math.pi * pulseLfoRateHz * dtSec;
      final double amplitude =
          ((pulseMaxHz - pulseMinHz) * 0.5) * pulseLfoDepth;
      nextPulse = (nextPulse + math.sin(_pulseLfoPhase) * amplitude).clamp(
        pulseMinHz,
        pulseMaxHz,
      );
    }
    _manualEffectivePulseHz = nextPulse;
  }

  void _advanceManualState(double dtSec) {
    final double safeDtSec = dtSec.clamp(0.001, 0.5);
    final double maxStep = _manualVelocityMaxUnitsPerSec * safeDtSec;

    _manualSmoothedAlpha = _stepTowards(
      _manualSmoothedAlpha,
      _manualTargetAlpha,
      maxStep,
    ).clamp(-1.0, 1.0);
    _manualSmoothedBeta = _stepTowards(
      _manualSmoothedBeta,
      _manualTargetBeta,
      maxStep,
    ).clamp(-1.0, 1.0);

    _manualSmoothedE1 = _stepTowards(
      _manualSmoothedE1,
      _manualTargetE1,
      maxStep,
    ).clamp(0.0, 1.0);
    _manualSmoothedE2 = _stepTowards(
      _manualSmoothedE2,
      _manualTargetE2,
      maxStep,
    ).clamp(0.0, 1.0);
    _manualSmoothedE3 = _stepTowards(
      _manualSmoothedE3,
      _manualTargetE3,
      maxStep,
    ).clamp(0.0, 1.0);
    _manualSmoothedE4 = _stepTowards(
      _manualSmoothedE4,
      _manualTargetE4,
      maxStep,
    ).clamp(0.0, 1.0);

    final double intensityTarget = _manualPaused ? 0.0 : 1.0;
    _manualIntensityRamp = _smoothValue(
      previous: _manualIntensityRamp,
      target: intensityTarget,
      dtSec: safeDtSec,
      attackSec: buttonResumeRampSec,
      releaseSec: _manualIntensityReleaseSec,
    ).clamp(0.0, 1.0);

    _updateManualEffectiveFrequencies(safeDtSec);
  }

  double _manualIntensityCapFraction() {
    return ((settings.manualIntensity / 100.0).clamp(0.0, 1.0) *
            _manualIntensityRamp)
        .clamp(0.0, 1.0);
  }

  double _carrierTauDerating({
    required double carrierFrequencyHz,
    required double carrierMaxHz,
    required double tauMicros,
  }) {
    final double tauSec = tauMicros.clamp(0.0, 1000.0) * 1e-6;
    if (tauSec <= 0.0) {
      return 1.0;
    }
    final double maxCarrierHz = carrierMaxHz.clamp(1.0, 2000.0);
    final double numerator = carrierFrequencyHz * tauSec + 0.5;
    final double denominator = maxCarrierHz * tauSec + 0.5;
    if (denominator <= 0.0) {
      return 1.0;
    }
    return (numerator / denominator).clamp(0.0, 1.0);
  }

  // ── Standalone calibration preview (no session / connection required) ──

  void _startCalibrationPreview() {
    _calibrationPreviewTimer?.cancel();
    _lastCalibrationPreviewSec = 0.0;
    _calibrationPreviewTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) {
        _calibrationPreviewTick();
      },
    );
  }

  void _stopCalibrationPreview() {
    _calibrationPreviewTimer?.cancel();
    _calibrationPreviewTimer = null;
    _lastCalibrationPreviewSec = 0.0;
  }

  void _calibrationPreviewTick() {
    if (calibrationPattern == CalibrationPattern.none) {
      _stopCalibrationPreview();
      return;
    }

    final double nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final double dtSec = _lastCalibrationPreviewSec > 0.0
        ? (nowSec - _lastCalibrationPreviewSec).clamp(0.001, 0.5)
        : 0.033;
    _lastCalibrationPreviewSec = nowSec;

    if (calibrationPattern == CalibrationPattern.manual) {
      _advanceManualState(dtSec);
      if (outputMode == OutputModeSelection.fourPhase) {
        _updateFourPhaseElectrodeLevels(
          e1: _manualSmoothedE1,
          e2: _manualSmoothedE2,
          e3: _manualSmoothedE3,
          e4: _manualSmoothedE4,
        );
      } else {
        _updateThreePhaseElectrodeLevels(
          alpha: _manualSmoothedAlpha,
          beta: _manualSmoothedBeta,
          outputScale: 1.0,
        );
      }
      notifyListeners();
      return;
    }

    _calibrationController.advance(dtSec);

    if (outputMode == OutputModeSelection.fourPhase) {
      final (double e1, double e2, double e3, double e4) =
          _calibrationController.fourPhasePowers();
      _updateFourPhaseElectrodeLevels(e1: e1, e2: e2, e3: e3, e4: e4);
    } else {
      final (double calAlpha, double calBeta) = _calibrationController
          .threePhasePosition();
      _updateThreePhaseElectrodeLevels(
        alpha: calAlpha,
        beta: calBeta,
        outputScale: 1.0,
      );
    }

    notifyListeners();
  }

  Future<void> _sendHeartbeatTick() async {
    if (!_heartbeatLoop.tryBeginTick(
      sessionRunning: sessionRunning,
      connected: connectionState == FocstimConnectionState.connected,
    )) {
      return;
    }

    try {
      final features = _audioCaptureManager.lastAudioFeatures;
      _learningAdapter.pushFrame(features);

      final HeartbeatTickPrecomputeRequest precomputeRequest =
          _heartbeatTickPrecomputeRequestMapper.map(
            input: HeartbeatTickPrecomputeRequestMapperInput(
              nowMs: DateTime.now().millisecondsSinceEpoch,
              hdlcDroppedFrames: _api.hdlcDroppedFrameCount,
              lastPcmTimestampMs: _audioCaptureManager.lastPcmTimestampMs,
              features: features,
              consumeDtSec: _heartbeatLoop.consumeDtSec,
              shouldForceSync: _heartbeatLoop.shouldForceSync,
              mode: stimMode,
              outputMode: outputMode,
              sensitivity: sensitivity,
              intensityCap: intensityCap,
              onsetSensitivityMin: onsetSensitivityMin,
              onsetSensitivityMax: onsetSensitivityMax,
              onsetSmoothing: onsetSmoothing,
              motionState: _heartbeatMotionState,
              fillBaseRadius: fillBaseRadius,
              fillHhImpulseSize: fillHhImpulseSize,
              fillHhDecayRate: fillHhDecayRate,
              fillRotOmega: fillRotOmega,
              buttonHoldMuted: _buttonStateMachine.buttonHoldMuted,
              buttonHoldRamp: _buttonStateMachine.buttonHoldRamp,
              buttonResumeRampSec: buttonResumeRampSec,
              calibrationPattern: calibrationPattern,
              manualPulseMode: manualPulseMode,
              manualPulseHz: manualPulseHz,
              pulseMinHz: pulseMinHz,
              pulseMaxHz: pulseMaxHz,
              bassMonitorLowHz: bassMonitorLowHz,
              bassMonitorHighHz: bassMonitorHighHz,
              tempoUnlockHoldEnabled: tempoUnlockHoldEnabled,
              energyResponseStrength: energyResponseStrength,
              latencyCompensationMs: latencyCompensationMs,
              adaptiveLeadMs: adaptiveLeadEnabled ? _adaptiveLead.leadMs : 0.0,
              learningEnabled: learningEnabled,
              committedCadenceHint: _committedCadenceHint,
              hardFillGateEnabled: hardFillGateEnabled,
              beatMotion: _beatMotion,
              fillMotion: _fillMotion,
              gateChain: _gateChain,
              onsetMotion: _onsetMotion,
              previousMotionDriveLevel: _heartbeatMotionState.motionDriveLevel,
              startupRampAt: _startupRampAt,
              carrierHz: carrierHz,
              carrierMinHz: carrierMinHz,
              carrierMaxHz: carrierMaxHz,
              tauMicros: tauMicros,
            ),
          );
      final HeartbeatTickPrecompute precompute =
          _heartbeatTickPrecomputeController.compute(
            request: precomputeRequest,
          );
      _updateAdaptiveLead(precompute: precompute);
      _updateLearningAdapter(precompute: precompute);
      telemetryHdlcDroppedFrames = precompute.hdlcDroppedFrames;
      final HeartbeatOrchestratorOutputApply outputApplyResult =
          _heartbeatOrchestratorOutputApplyController.apply(
            heartbeatPrelude: precompute.heartbeatPrelude,
            heartbeatMotionState: _heartbeatMotionState,
            beatMotion: _beatMotion,
            buttonStateMachine: _buttonStateMachine,
          );

      double carrierToSend = precompute.carrierToSend;
      double amplitudeToSend = precompute.amplitudeToSend;
      double effectivePulseHz = _heartbeatMotionState.effectivePulseHz;
      if (calibrationPattern == CalibrationPattern.manual) {
        _advanceManualState(precompute.dtSec);
        effectivePulseHz = _manualEffectivePulseHz;
        carrierToSend = _manualEffectiveCarrierHz;
        final double startupRamp = _startupRampAt(precompute.nowSec);
        final double tauDerating = _carrierTauDerating(
          carrierFrequencyHz: carrierToSend,
          carrierMaxHz: carrierMaxHz,
          tauMicros: tauMicros,
        );
        amplitudeToSend =
            (outputApplyResult.amplitudeAmps *
                    startupRamp *
                    tauDerating *
                    _manualIntensityCapFraction())
                .clamp(0.0, 0.12);
      }

      final HeartbeatCommandPipelineRequest commandPipelineRequest =
          _heartbeatCommandPipelineRequestMapper.map(
            input: HeartbeatCommandPipelineRequestMapperInput(
              precompute: precompute,
              carrierToSend: carrierToSend,
              amplitudeToSend: amplitudeToSend,
              outputApplyResult: outputApplyResult,
              heartbeatMotionState: _heartbeatMotionState,
              effectivePulseHz: effectivePulseHz,
              pulseWidthCycles: pulseWidthCycles,
              pulseRiseTimeCycles: pulseRiseTimeCycles,
              normalizedPulseIntervalRandom: _normalizedPulseIntervalRandom(),
              outputMode: outputMode,
              cal3Neutral: cal3Neutral,
              cal3Right: cal3Right,
              cal3Center: cal3Center,
              cal4A: cal4A,
              cal4B: cal4B,
              cal4C: cal4C,
              cal4D: cal4D,
              shouldSendAxis: _heartbeatLoop.shouldSendAxis,
              moveAxis: _api.moveAxis,
              calibrationPattern: calibrationPattern,
              calibrationController: _calibrationController,
              manualAlpha: _manualSmoothedAlpha,
              manualBeta: _manualSmoothedBeta,
              manualE1: _manualSmoothedE1,
              manualE2: _manualSmoothedE2,
              manualE3: _manualSmoothedE3,
              manualE4: _manualSmoothedE4,
              markFullSync: _heartbeatLoop.markFullSync,
              updateFourPhaseElectrodeLevels: _updateFourPhaseElectrodeLevels,
              updateThreePhaseElectrodeLevels: _updateThreePhaseElectrodeLevels,
              recordCalibrationOutput:
                  _sessionRuntimeController.recordCalibrationOutput,
              stimMode: stimMode,
              beatMotion: _beatMotion,
              onsetMotion: _onsetMotion,
              silenceFade: _silenceFade,
              pulseIntervalRandomPercent: pulseIntervalRandomPercent,
              beatRadiusAwareContrastStrength: beatRadiusAwareContrastStrength,
              beatSpeedThresholdSpreadStrength:
                  beatSpeedThresholdSpreadStrength,
              beatResponseCurves: beatFourPhaseResponseCurves,
              onsetBandMapping: onsetBandMapping,
              recordMotionOutput: _sessionRuntimeController.recordMotionOutput,
            ),
          );

      final bool handledCalibrationOverride =
          await _heartbeatCommandPipelineController.execute(
            request: commandPipelineRequest,
          );

      if (handledCalibrationOverride) {
        return;
      }

      lastError = null;
    } catch (error, stackTrace) {
      debugPrint('[HEARTBEAT] tick failed: $error\n$stackTrace');
      // Heartbeat command failed — connection is likely dead. Let the
      // watchdog / state-listener shut down the session cleanly.
      _heartbeatLoop.stop();
    } finally {
      _heartbeatLoop.endTick();
      notifyListeners();
    }
  }

  void _handleCaptureEvent(Map<String, dynamic> event) {
    final CaptureEventProcessingResult result = _captureController
        .handlePlatformEvent(event, onPcm16Event: _handlePcm16Event);

    if (result.resetLiveAudio) {
      _resetLiveAudioState();
    }

    if (result.captureStarted) {
      _audioCaptureManager.markCaptureStarted(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        sampleRate: result.captureSampleRate,
        channels: result.captureChannels,
      );
    }

    if (result.resetMotionDrive) {
      _heartbeatMotionState.setMotionDriveLevel(0.0);
    }

    if (result.errorMessage != null) {
      lastError = result.errorMessage;
    }

    if (result.shouldNotify) {
      notifyListeners();
    }
  }

  bool _handlePcm16Event(Pcm16CaptureEvent event) {
    final bool shouldNotify = _audioCaptureManager.handlePcm16Event(
      event: event,
      sensitivity: sensitivity,
      bassMonitorLowHz: bassMonitorLowHz,
      bassMonitorHighHz: bassMonitorHighHz,
      estimatedBpm: _estimatedBpm,
    );

    if (captureSourceBlocked && liveGateOpen && liveAudioLevel > 0.03) {
      captureSourceBlocked = false;
      captureSourceMessage = null;
      captureStatus = 'running';
    }
    return shouldNotify;
  }

  void _resetLiveAudioState() {
    _audioCaptureManager.resetLiveState();
    _heartbeatMotionState.setMotionDriveLevel(0.0);
    _sessionRuntimeController.resetMotionActivity();
    _resetElectrodeLevels();
    _heartbeatMotionState.resetPulseTracking(
      pulseMinHz: pulseMinHz,
      pulseMaxHz: pulseMaxHz,
    );
    _resetOrbitState();
  }

  void _resetOrbitState() {
    _beatMotion.reset();
    _adaptiveLead.reset();
    _adaptiveLeadLastGateOpen = false;
    _learningAdapter.fullReset();
    _committedCadenceHint = 2;
    _learningLastGateOpen = false;
    _fillMotion.reset();
    _heartbeatLoop.resetTickClock();
    _heartbeatMotionState.resetOrbitState(fillBaseRadius: fillBaseRadius);
    _onsetMotion.reset();
    _calibrationController.resetAngle();
  }

  void _updateAdaptiveLead({required HeartbeatTickPrecompute precompute}) {
    if (!adaptiveLeadEnabled) {
      return;
    }

    final features = precompute.features;

    if (_adaptiveLeadLastGateOpen && !features.gateOpen) {
      _adaptiveLead.reset();
    }
    _adaptiveLeadLastGateOpen = features.gateOpen;

    if (!precompute.heartbeatPrelude.beatRisingEdge ||
        !features.isDownbeat ||
        features.metronomeBpm <= 0.0) {
      return;
    }

    final double beatPeriodMs = 60000.0 / features.metronomeBpm;
    double phaseErrorMs = features.metronomePhase * beatPeriodMs;
    if (phaseErrorMs > beatPeriodMs * 0.5) {
      phaseErrorMs -= beatPeriodMs;
    }
    _adaptiveLead.observe(phaseErrorMs);
  }

  void _updateLearningAdapter({required HeartbeatTickPrecompute precompute}) {
    final features = precompute.features;

    if (_learningLastGateOpen && !features.gateOpen) {
      _learningAdapter.reset();
      _committedCadenceHint = 2;
    }
    _learningLastGateOpen = features.gateOpen;

    _learningAdapter.learningStrength = learningStrength.clamp(0.0, 1.0);

    if (!precompute.heartbeatPrelude.beatRisingEdge ||
        precompute.heartbeatPrelude.triggerKind == TriggerKind.fill) {
      return;
    }

    _learningAdapter.updateOnBeat(features);
    _committedCadenceHint = _learningAdapter.cadenceHint;
  }

  void _updateFourPhaseElectrodeLevels({
    required double e1,
    required double e2,
    required double e3,
    required double e4,
  }) {
    _electrodeStateController.updateFourPhaseLevels(
      e1: e1,
      e2: e2,
      e3: e3,
      e4: e4,
    );
  }

  /// Restim's constrain_4p_amplitudes: enforce triangle inequality on each
  /// triplet, then normalize so the maximum value is 1.0.
  static List<double> _constrain4pAmplitudes(
    double a,
    double b,
    double c,
    double d,
  ) {
    return constrain4pAmplitudes(a, b, c, d);
  }

  @visibleForTesting
  static List<double> constrain4pAmplitudesForTest(
    double a,
    double b,
    double c,
    double d,
  ) {
    return _constrain4pAmplitudes(a, b, c, d);
  }

  void _updateThreePhaseElectrodeLevels({
    required double alpha,
    required double beta,
    required double outputScale,
  }) {
    _electrodeStateController.updateThreePhaseLevels(
      alpha: alpha,
      beta: beta,
      outputScale: outputScale,
    );
  }

  void _resetElectrodeLevels() {
    _electrodeStateController.reset();
  }

  static double _smoothValue({
    required double previous,
    required double target,
    required double dtSec,
    required double attackSec,
    required double releaseSec,
  }) {
    return smoothValue(
      previous: previous,
      target: target,
      dtSec: dtSec,
      attackSec: attackSec,
      releaseSec: releaseSec,
    );
  }

  @visibleForTesting
  static double smoothValueForTest({
    required double previous,
    required double target,
    required double dtSec,
    required double attackSec,
    required double releaseSec,
  }) {
    return _smoothValue(
      previous: previous,
      target: target,
      dtSec: dtSec,
      attackSec: attackSec,
      releaseSec: releaseSec,
    );
  }

  // ── Shuttle helpers (3-phase onset: L↔R bounce with half-circle arc) ──

  /// Quintic smoothstep: 6t⁵ − 15t⁴ + 10t³  (zero 1st & 2nd derivative at endpoints).
  static double _quinticSmoothstep(double t) {
    return quinticSmoothstep(t);
  }

  @visibleForTesting
  static double quinticSmoothstepForTest(double t) {
    return _quinticSmoothstep(t);
  }

  /// Half-circle arc projection: beta sweeps E2↔E3, alpha bulges toward N.
  /// [position] 0→1, [radius] arc size, [arcDir] +1/-1 for bulge side.
  static (double alpha, double beta) _shuttleArc(
    double position,
    double radius,
    double arcDir,
  ) {
    return shuttleArc(position, radius, arcDir);
  }

  @visibleForTesting
  static (double alpha, double beta) shuttleArcForTest(
    double position,
    double radius,
    double arcDir,
  ) {
    return _shuttleArc(position, radius, arcDir);
  }

  @override
  void notifyListeners() {
    if (_isDisposed) {
      return;
    }
    super.notifyListeners();
  }

  Future<void> _cancelSubscription(
    String label,
    StreamSubscription<dynamic>? subscription,
  ) async {
    if (subscription == null) {
      return;
    }

    try {
      await subscription.cancel();
    } catch (error, stackTrace) {
      debugPrint(
        '[ConnectionProvider] Failed to cancel $label subscription: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _disposeAsyncCleanup({
    required StreamSubscription<FocstimConnectionState>? stateSubscription,
    required StreamSubscription<rpc.Notification>? notificationSubscription,
    required StreamSubscription<Map<String, dynamic>>? captureSubscription,
  }) async {
    await _cancelSubscription('state', stateSubscription);
    await _cancelSubscription('notification', notificationSubscription);
    await _cancelSubscription('capture', captureSubscription);

    try {
      await stopAudioCapture(releaseProjection: true);
    } catch (error, stackTrace) {
      debugPrint(
        '[ConnectionProvider] Failed to stop audio capture during dispose: '
        '$error\n$stackTrace',
      );
    }

    try {
      await _api.dispose();
    } catch (error, stackTrace) {
      debugPrint(
        '[ConnectionProvider] Failed to dispose API transport: '
        '$error\n$stackTrace',
      );
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    _heartbeatLoop.dispose();
    _sessionRuntimeController.clearSessionClock();
    _calibrationPreviewTimer?.cancel();
    _calibrationPreviewTimer = null;
    settings.dispose();
    _sessionController.stopWatchdog();
    _buttonStateMachine.dispose();

    final StreamSubscription<FocstimConnectionState>? stateSubscription =
        _stateSubscription;
    final StreamSubscription<rpc.Notification>? notificationSubscription =
        _notificationSubscription;
    final StreamSubscription<Map<String, dynamic>>? captureSubscription =
        _captureSubscription;

    _stateSubscription = null;
    _notificationSubscription = null;
    _captureSubscription = null;

    unawaited(
      _disposeAsyncCleanup(
        stateSubscription: stateSubscription,
        notificationSubscription: notificationSubscription,
        captureSubscription: captureSubscription,
      ),
    );
    super.dispose();
  }
}
