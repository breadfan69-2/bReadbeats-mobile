import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/onset_motion_engine.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/calibration_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_axis_dispatch_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_base_and_calibration_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_calibration_override_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_command_pipeline_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_mode_axis_apply_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_mode_output_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_tick_finalize_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('execute short-circuits when calibration override is handled', () async {
    final _FakeHeartbeatBaseAndCalibrationController baseController =
        _FakeHeartbeatBaseAndCalibrationController(result: true);
    final _FakeHeartbeatModeOutputController modeController =
        _FakeHeartbeatModeOutputController();
    final _FakeHeartbeatTickFinalizeController finalizeController =
        _FakeHeartbeatTickFinalizeController();

    final HeartbeatCommandPipelineController controller =
        HeartbeatCommandPipelineController(
          heartbeatBaseAndCalibrationController: baseController,
          heartbeatModeOutputController: modeController,
          heartbeatTickFinalizeController: finalizeController,
        );

    bool markFullSyncCalled = false;
    bool motionRecorded = false;

    final bool handled = await controller.execute(
      request: HeartbeatCommandPipelineRequest(
        amplitudeToSend: 0.6,
        carrierToSend: 480.0,
        effectivePulseHz: 12.0,
        pulseWidthCycles: 9.0,
        pulseRiseTimeCycles: 3.0,
        normalizedPulseIntervalRandom: 0.1,
        outputMode: OutputModeSelection.threePhase,
        cal3Neutral: -1.0,
        cal3Right: 0.2,
        cal3Center: -0.3,
        cal4A: 0.1,
        cal4B: 0.2,
        cal4C: 0.3,
        cal4D: 0.4,
        forceSync: true,
        shouldSendAxis:
            ({
              required int axisKey,
              required double value,
              required bool forceSync,
            }) => true,
        moveAxis: (enums.AxisType axis, double value, int intervalMs) =>
            Future<void>.value(),
        calibrationPattern: CalibrationPattern.circle,
        calibrationController: CalibrationController(),
        manualAlpha: 0.0,
        manualBeta: 0.0,
        manualE1: 0.333,
        manualE2: 0.333,
        manualE3: 0.333,
        manualE4: 0.0,
        dtSec: 1 / 60,
        nowSec: 12.5,
        markFullSync: (_) {
          markFullSyncCalled = true;
        },
        updateFourPhaseElectrodeLevels:
            ({
              required double e1,
              required double e2,
              required double e3,
              required double e4,
            }) {},
        updateThreePhaseElectrodeLevels:
            ({
              required double alpha,
              required double beta,
              required double outputScale,
            }) {},
        recordCalibrationOutput:
            ({required double amplitudeToSend, required int nowMs}) {},
        nowMs: 99,
        stimMode: StimMode.onset,
        beatMotion: BeatMotionEngine(),
        onsetMotion: OnsetMotionEngine(),
        features: AudioFeatures.zero,
        blendedAngle: 1.1,
        base: 0.3,
        silenceFade: 0.2,
        fillAngle: 1.9,
        pulseIntervalRandomPercent: 17.0,
        beatRadiusAwareContrastStrength: 0.35,
        beatSpeedThresholdSpreadStrength: 0.25,
        beatResponseCurves: defaultBeatFourPhaseResponseCurves,
        onsetBandMapping: defaultOnsetBandMapping,
        blendX: -0.1,
        blendY: 0.2,
        fillCenterY: 0.1,
        fillRadius: 0.5,
        fillHhImpulse: 0.4,
        outputDrive: 0.8,
        recordMotionOutput:
            ({
              required double amplitudeToSend,
              required double base,
              required double amplitudeAmps,
              required int nowMs,
            }) {
              motionRecorded = true;
            },
        amplitudeAmps: 0.2,
      ),
    );

    expect(handled, isTrue);
    expect(baseController.callCount, 1);
    expect(modeController.callCount, 0);
    expect(finalizeController.callCount, 0);
    expect(markFullSyncCalled, isFalse);
    expect(motionRecorded, isFalse);
  });

  test(
    'execute applies mode output and finalize when override not handled',
    () async {
      final _FakeHeartbeatBaseAndCalibrationController baseController =
          _FakeHeartbeatBaseAndCalibrationController(result: false);
      final _FakeHeartbeatModeOutputController modeController =
          _FakeHeartbeatModeOutputController();
      final _FakeHeartbeatTickFinalizeController finalizeController =
          _FakeHeartbeatTickFinalizeController();

      final HeartbeatCommandPipelineController controller =
          HeartbeatCommandPipelineController(
            heartbeatBaseAndCalibrationController: baseController,
            heartbeatModeOutputController: modeController,
            heartbeatTickFinalizeController: finalizeController,
          );

      bool markFullSyncCalled = false;
      double? observedAmplitudeToSend;
      double? observedBase;
      double? observedAmplitudeAmps;
      int? observedNowMs;

      final bool handled = await controller.execute(
        request: HeartbeatCommandPipelineRequest(
          amplitudeToSend: 0.72,
          carrierToSend: 501.0,
          effectivePulseHz: 14.0,
          pulseWidthCycles: 10.0,
          pulseRiseTimeCycles: 5.0,
          normalizedPulseIntervalRandom: 0.25,
          outputMode: OutputModeSelection.fourPhase,
          cal3Neutral: 0.0,
          cal3Right: 0.0,
          cal3Center: 0.0,
          cal4A: 0.9,
          cal4B: 0.8,
          cal4C: 0.7,
          cal4D: 0.6,
          forceSync: false,
          shouldSendAxis:
              ({
                required int axisKey,
                required double value,
                required bool forceSync,
              }) => true,
          moveAxis: (enums.AxisType axis, double value, int intervalMs) =>
              Future<void>.value(),
          calibrationPattern: CalibrationPattern.none,
          calibrationController: CalibrationController(),
          manualAlpha: 0.0,
          manualBeta: 0.0,
          manualE1: 0.333,
          manualE2: 0.333,
          manualE3: 0.333,
          manualE4: 0.0,
          dtSec: 1 / 120,
          nowSec: 25.0,
          markFullSync: (_) {
            markFullSyncCalled = true;
          },
          updateFourPhaseElectrodeLevels:
              ({
                required double e1,
                required double e2,
                required double e3,
                required double e4,
              }) {},
          updateThreePhaseElectrodeLevels:
              ({
                required double alpha,
                required double beta,
                required double outputScale,
              }) {},
          recordCalibrationOutput:
              ({required double amplitudeToSend, required int nowMs}) {},
          nowMs: 456,
          stimMode: StimMode.beat,
          beatMotion: BeatMotionEngine(),
          onsetMotion: OnsetMotionEngine(),
          features: AudioFeatures.zero,
          blendedAngle: 0.6,
          base: 0.44,
          silenceFade: 0.3,
          fillAngle: 2.2,
          pulseIntervalRandomPercent: 31.0,
          beatRadiusAwareContrastStrength: 0.4,
          beatSpeedThresholdSpreadStrength: 0.2,
          beatResponseCurves: const <BeatResponseCurve>[
            BeatResponseCurve.bell,
            BeatResponseCurve.ease,
            BeatResponseCurve.linear,
            BeatResponseCurve.linear,
          ],
          onsetBandMapping: defaultOnsetBandMapping,
          blendX: 0.13,
          blendY: -0.27,
          fillCenterY: 0.41,
          fillRadius: 0.55,
          fillHhImpulse: 0.67,
          outputDrive: 0.74,
          recordMotionOutput:
              ({
                required double amplitudeToSend,
                required double base,
                required double amplitudeAmps,
                required int nowMs,
              }) {
                observedAmplitudeToSend = amplitudeToSend;
                observedBase = base;
                observedAmplitudeAmps = amplitudeAmps;
                observedNowMs = nowMs;
              },
          amplitudeAmps: 0.29,
        ),
      );

      expect(handled, isFalse);
      expect(baseController.callCount, 1);
      expect(modeController.callCount, 1);
      expect(finalizeController.callCount, 1);
      expect(modeController.lastOutputMode, OutputModeSelection.fourPhase);
      expect(modeController.lastOutputDrive, closeTo(0.74, 1e-12));
      expect(modeController.lastBandMapping, equals(defaultOnsetBandMapping));
      expect(
        modeController.lastBeatResponseCurves,
        equals(<BeatResponseCurve>[
          BeatResponseCurve.bell,
          BeatResponseCurve.ease,
          BeatResponseCurve.linear,
          BeatResponseCurve.linear,
        ]),
      );
      expect(finalizeController.lastOperationsLength, 2);
      expect(markFullSyncCalled, isTrue);
      expect(observedAmplitudeToSend, closeTo(0.72, 1e-12));
      expect(observedBase, closeTo(0.44, 1e-12));
      expect(observedAmplitudeAmps, closeTo(0.29, 1e-12));
      expect(observedNowMs, 456);
    },
  );
}

class _FakeHeartbeatBaseAndCalibrationController
    extends HeartbeatBaseAndCalibrationController {
  _FakeHeartbeatBaseAndCalibrationController({required this.result});

  final bool result;
  int callCount = 0;

  @override
  Future<bool> queueBaseAndHandleCalibrationOverride({
    required double amplitudeToSend,
    required double carrierToSend,
    required double effectivePulseHz,
    required double pulseWidthCycles,
    required double pulseRiseTimeCycles,
    required double normalizedPulseIntervalRandom,
    required OutputModeSelection outputMode,
    required double cal3Neutral,
    required double cal3Right,
    required double cal3Center,
    required double cal4A,
    required double cal4B,
    required double cal4C,
    required double cal4D,
    required List<Future<void>> operations,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    required CalibrationPattern calibrationPattern,
    required CalibrationController calibrationController,
    required double manualAlpha,
    required double manualBeta,
    required double manualE1,
    required double manualE2,
    required double manualE3,
    required double manualE4,
    required double dtSec,
    required double nowSec,
    required void Function(double nowSec) markFullSync,
    required FourPhaseCalibrationLevelUpdater updateFourPhaseElectrodeLevels,
    required ThreePhaseCalibrationLevelUpdater updateThreePhaseElectrodeLevels,
    required CalibrationOutputRecorder recordCalibrationOutput,
    required int nowMs,
  }) async {
    callCount++;
    operations.add(Future<void>.value());
    return result;
  }
}

class _FakeHeartbeatModeOutputController extends HeartbeatModeOutputController {
  int callCount = 0;
  OutputModeSelection? lastOutputMode;
  double? lastOutputDrive;
  List<BeatResponseCurve>? lastBeatResponseCurves;
  List<List<AudioBand>>? lastBandMapping;

  @override
  void apply({
    required OutputModeSelection outputMode,
    required StimMode stimMode,
    required BeatMotionEngine beatMotion,
    required OnsetMotionEngine onsetMotion,
    required AudioFeatures features,
    required double blendedAngle,
    required double base,
    required double silenceFade,
    required double fillAngle,
    required double pulseIntervalRandomPercent,
    required double beatRadiusAwareContrastStrength,
    required double beatSpeedThresholdSpreadStrength,
    required List<BeatResponseCurve> beatResponseCurves,
    required List<List<AudioBand>> bandMapping,
    required double blendX,
    required double blendY,
    required double fillCenterY,
    required double fillRadius,
    required double fillHhImpulse,
    required double outputDrive,
    required List<Future<void>> operations,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    required FourPhaseElectrodeLevelUpdater updateFourPhaseElectrodeLevels,
    required ThreePhaseElectrodeLevelUpdater updateThreePhaseElectrodeLevels,
  }) {
    callCount++;
    lastOutputMode = outputMode;
    lastOutputDrive = outputDrive;
    lastBeatResponseCurves = beatResponseCurves;
    lastBandMapping = bandMapping;
    operations.add(Future<void>.value());
  }
}

class _FakeHeartbeatTickFinalizeController
    extends HeartbeatTickFinalizeController {
  int callCount = 0;
  int? lastOperationsLength;

  @override
  Future<void> finalize({
    required List<Future<void>> operations,
    required bool forceSync,
    required double nowSec,
    required void Function(double nowSec) markFullSync,
    required MotionOutputRecorder recordMotionOutput,
    required double amplitudeToSend,
    required double base,
    required double amplitudeAmps,
    required int nowMs,
  }) async {
    callCount++;
    lastOperationsLength = operations.length;
    markFullSync(nowSec);
    recordMotionOutput(
      amplitudeToSend: amplitudeToSend,
      base: base,
      amplitudeAmps: amplitudeAmps,
      nowMs: nowMs,
    );
  }
}
