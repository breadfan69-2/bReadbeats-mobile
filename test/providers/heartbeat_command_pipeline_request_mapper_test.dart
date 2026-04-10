import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/heartbeat_motion_state_controller.dart';
import 'package:breadbeats_mobile/audio/motion/heartbeat_orchestrator.dart';
import 'package:breadbeats_mobile/audio/motion/onset_motion_engine.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/calibration_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_command_pipeline_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_command_pipeline_request_mapper.dart';
import 'package:breadbeats_mobile/providers/heartbeat_orchestrator_output_apply_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_tick_precompute_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatCommandPipelineRequestMapper mapper =
      HeartbeatCommandPipelineRequestMapper();

  test(
    'maps precompute and output-apply state into pipeline request',
    () async {
      final HeartbeatMotionStateController motionState =
          HeartbeatMotionStateController(fillBaseRadius: 0.5);

      const HeartbeatOrchestratorOutput heartbeatPrelude =
          HeartbeatOrchestratorOutput(
            motionDriveLevel: 0.51,
            effectivePulseHz: 22.0,
            triggerKind: TriggerKind.beat,
            estimatedBpm: 121.0,
            silenceFade: 0.76,
            beatRisingEdge: true,
            fluxEmaPhrase: 0.33,
            tempoLocked: true,
            effectiveBpm: 120.0,
            phraseCommitted: true,
            phraseBeatCount: 2,
            phraseFluxAtStart: 0.24,
            lastBeatTriggerMs: 1000,
            fillSilenceStartMs: 900,
            fillTransition: 0.4,
            fillCenterY: -0.14,
            fillRadius: 0.67,
            fillAngle: 1.7,
            fillHhImpulse: 0.28,
            blendX: 0.11,
            blendY: -0.22,
            blendedAngle: 2.2,
            buttonHoldRamp: 0.66,
            outputDrive: 0.71,
            base: 0.37,
            amplitudeAmps: 0.45,
            smoothedDominantBassHz: 72.0,
            tempoUnlockHoldActive: false,
            tempoUnlockHoldBpm: 0.0,
          );

      motionState.applyOrchestratorOutput(heartbeatPrelude);

      final AudioFeatures features = AudioFeatures.zero;
      final HeartbeatTickPrecompute precompute = HeartbeatTickPrecompute(
        hdlcDroppedFrames: 4,
        nowSec: 123.456,
        nowMs: 123456,
        dtSec: 1 / 60,
        forceSync: true,
        features: features,
        heartbeatPrelude: heartbeatPrelude,
        carrierToSend: 480.0,
        amplitudeToSend: 0.62,
      );

      const HeartbeatOrchestratorOutputApply outputApplyResult =
          HeartbeatOrchestratorOutputApply(
            blendX: 0.19,
            blendY: -0.31,
            blendedAngle: 1.91,
            outputDrive: 0.83,
            base: 0.42,
            amplitudeAmps: 0.58,
          );

      double? markedNowSec;
      bool shouldSendAxisCalled = false;
      int? axisKeyCaptured;
      double? axisValueCaptured;
      bool? forceSyncCaptured;

      bool moveAxisCalled = false;
      enums.AxisType? movedAxis;
      double? movedValue;
      int? movedInterval;

      double? calibrationAmplitude;
      int? calibrationNowMs;

      double? motionAmplitudeToSend;
      double? motionBase;
      double? motionAmplitudeAmps;
      int? motionNowMs;
      const List<List<AudioBand>> onsetBandMapping = <List<AudioBand>>[
        <AudioBand>[AudioBand.bass],
        <AudioBand>[AudioBand.lowMid],
        <AudioBand>[AudioBand.mid],
        <AudioBand>[AudioBand.subBass],
      ];
      const List<BeatResponseCurve> beatResponseCurves = <BeatResponseCurve>[
        BeatResponseCurve.linear,
        BeatResponseCurve.bell,
        BeatResponseCurve.ease,
        BeatResponseCurve.linear,
      ];

      final HeartbeatCommandPipelineRequest request = mapper.map(
        input: HeartbeatCommandPipelineRequestMapperInput(
          precompute: precompute,
          carrierToSend: precompute.carrierToSend,
          amplitudeToSend: precompute.amplitudeToSend,
          outputApplyResult: outputApplyResult,
          heartbeatMotionState: motionState,
          effectivePulseHz: 19.0,
          pulseWidthCycles: 8.0,
          pulseRiseTimeCycles: 3.0,
          normalizedPulseIntervalRandom: 0.27,
          outputMode: OutputModeSelection.fourPhase,
          cal3Neutral: -0.1,
          cal3Right: 0.2,
          cal3Center: -0.3,
          cal4A: 0.4,
          cal4B: 0.5,
          cal4C: 0.6,
          cal4D: 0.7,
          shouldSendAxis:
              ({
                required int axisKey,
                required double value,
                required bool forceSync,
              }) {
                shouldSendAxisCalled = true;
                axisKeyCaptured = axisKey;
                axisValueCaptured = value;
                forceSyncCaptured = forceSync;
                return true;
              },
          moveAxis: (enums.AxisType axis, double value, int intervalMs) {
            moveAxisCalled = true;
            movedAxis = axis;
            movedValue = value;
            movedInterval = intervalMs;
            return Future<void>.value();
          },
          calibrationPattern: CalibrationPattern.circle,
          calibrationController: CalibrationController(),
          manualAlpha: 0.0,
          manualBeta: 0.0,
          manualE1: 0.333,
          manualE2: 0.333,
          manualE3: 0.333,
          manualE4: 0.0,
          markFullSync: (double nowSec) {
            markedNowSec = nowSec;
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
              ({required double amplitudeToSend, required int nowMs}) {
                calibrationAmplitude = amplitudeToSend;
                calibrationNowMs = nowMs;
              },
          stimMode: StimMode.onset,
          beatMotion: BeatMotionEngine(),
          onsetMotion: OnsetMotionEngine(),
          silenceFade: 0.55,
          pulseIntervalRandomPercent: 14.0,
          beatRadiusAwareContrastStrength: 0.38,
          beatSpeedThresholdSpreadStrength: 0.21,
          beatResponseCurves: beatResponseCurves,
          onsetBandMapping: onsetBandMapping,
          recordMotionOutput:
              ({
                required double amplitudeToSend,
                required double base,
                required double amplitudeAmps,
                required int nowMs,
              }) {
                motionAmplitudeToSend = amplitudeToSend;
                motionBase = base;
                motionAmplitudeAmps = amplitudeAmps;
                motionNowMs = nowMs;
              },
        ),
      );

      expect(request.amplitudeToSend, closeTo(0.62, 1e-12));
      expect(request.carrierToSend, closeTo(480.0, 1e-12));
      expect(request.forceSync, isTrue);
      expect(request.dtSec, closeTo(1 / 60, 1e-12));
      expect(request.nowSec, closeTo(123.456, 1e-12));
      expect(request.nowMs, 123456);
      expect(request.features, same(features));

      expect(request.blendX, closeTo(0.19, 1e-12));
      expect(request.blendY, closeTo(-0.31, 1e-12));
      expect(request.blendedAngle, closeTo(1.91, 1e-12));
      expect(request.outputDrive, closeTo(0.83, 1e-12));
      expect(request.base, closeTo(0.42, 1e-12));
      expect(request.amplitudeAmps, closeTo(0.58, 1e-12));

      expect(request.fillAngle, closeTo(1.7, 1e-12));
      expect(request.fillCenterY, closeTo(-0.14, 1e-12));
      expect(request.fillRadius, closeTo(0.67, 1e-12));
      expect(request.fillHhImpulse, closeTo(0.28, 1e-12));
      expect(request.beatRadiusAwareContrastStrength, closeTo(0.38, 1e-12));
      expect(request.beatSpeedThresholdSpreadStrength, closeTo(0.21, 1e-12));
      expect(request.beatResponseCurves, equals(beatResponseCurves));
      expect(request.onsetBandMapping, equals(onsetBandMapping));

      request.markFullSync(9.87);
      expect(markedNowSec, closeTo(9.87, 1e-12));

      final bool shouldSend = request.shouldSendAxis(
        axisKey: 24,
        value: 0.45,
        forceSync: false,
      );
      expect(shouldSend, isTrue);
      expect(shouldSendAxisCalled, isTrue);
      expect(axisKeyCaptured, 24);
      expect(axisValueCaptured, closeTo(0.45, 1e-12));
      expect(forceSyncCaptured, isFalse);

      await request.moveAxis(enums.AxisType.AXIS_POSITION_ALPHA, 0.22, 33);
      expect(moveAxisCalled, isTrue);
      expect(movedAxis, enums.AxisType.AXIS_POSITION_ALPHA);
      expect(movedValue, closeTo(0.22, 1e-12));
      expect(movedInterval, 33);

      request.recordCalibrationOutput(amplitudeToSend: 0.3, nowMs: 44);
      expect(calibrationAmplitude, closeTo(0.3, 1e-12));
      expect(calibrationNowMs, 44);

      request.recordMotionOutput(
        amplitudeToSend: 0.41,
        base: 0.52,
        amplitudeAmps: 0.63,
        nowMs: 55,
      );
      expect(motionAmplitudeToSend, closeTo(0.41, 1e-12));
      expect(motionBase, closeTo(0.52, 1e-12));
      expect(motionAmplitudeAmps, closeTo(0.63, 1e-12));
      expect(motionNowMs, 55);
    },
  );
}
