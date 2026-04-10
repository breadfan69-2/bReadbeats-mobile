import '../audio/motion/beat_motion_engine.dart';
import '../audio/motion/heartbeat_motion_state_controller.dart';
import '../audio/motion/onset_motion_engine.dart';
import '../models/device_models.dart';
import '../models/enums.dart';
import 'calibration_controller.dart';
import 'heartbeat_axis_dispatch_controller.dart';
import 'heartbeat_calibration_override_controller.dart';
import 'heartbeat_command_pipeline_controller.dart';
import 'heartbeat_orchestrator_output_apply_controller.dart';
import 'heartbeat_tick_finalize_controller.dart';
import 'heartbeat_tick_precompute_controller.dart';

class HeartbeatCommandPipelineRequestMapperInput {
  const HeartbeatCommandPipelineRequestMapperInput({
    required this.precompute,
    required this.carrierToSend,
    required this.amplitudeToSend,
    required this.outputApplyResult,
    required this.heartbeatMotionState,
    required this.effectivePulseHz,
    required this.pulseWidthCycles,
    required this.pulseRiseTimeCycles,
    required this.normalizedPulseIntervalRandom,
    required this.outputMode,
    required this.cal3Neutral,
    required this.cal3Right,
    required this.cal3Center,
    required this.cal4A,
    required this.cal4B,
    required this.cal4C,
    required this.cal4D,
    required this.shouldSendAxis,
    required this.moveAxis,
    required this.calibrationPattern,
    required this.calibrationController,
    required this.manualAlpha,
    required this.manualBeta,
    required this.manualE1,
    required this.manualE2,
    required this.manualE3,
    required this.manualE4,
    required this.markFullSync,
    required this.updateFourPhaseElectrodeLevels,
    required this.updateThreePhaseElectrodeLevels,
    required this.recordCalibrationOutput,
    required this.stimMode,
    required this.beatMotion,
    required this.onsetMotion,
    required this.silenceFade,
    required this.pulseIntervalRandomPercent,
    required this.beatRadiusAwareContrastStrength,
    required this.beatSpeedThresholdSpreadStrength,
    required this.beatResponseCurves,
    required this.onsetBandMapping,
    required this.recordMotionOutput,
  });

  final HeartbeatTickPrecompute precompute;
  final double carrierToSend;
  final double amplitudeToSend;
  final HeartbeatOrchestratorOutputApply outputApplyResult;
  final HeartbeatMotionStateController heartbeatMotionState;
  final double effectivePulseHz;
  final double pulseWidthCycles;
  final double pulseRiseTimeCycles;
  final double normalizedPulseIntervalRandom;
  final OutputModeSelection outputMode;
  final double cal3Neutral;
  final double cal3Right;
  final double cal3Center;
  final double cal4A;
  final double cal4B;
  final double cal4C;
  final double cal4D;
  final AxisSendPredicate shouldSendAxis;
  final AxisMoveSender moveAxis;
  final CalibrationPattern calibrationPattern;
  final CalibrationController calibrationController;
  final double manualAlpha;
  final double manualBeta;
  final double manualE1;
  final double manualE2;
  final double manualE3;
  final double manualE4;
  final void Function(double nowSec) markFullSync;
  final FourPhaseCalibrationLevelUpdater updateFourPhaseElectrodeLevels;
  final ThreePhaseCalibrationLevelUpdater updateThreePhaseElectrodeLevels;
  final CalibrationOutputRecorder recordCalibrationOutput;
  final StimMode stimMode;
  final BeatMotionEngine beatMotion;
  final OnsetMotionEngine onsetMotion;
  final double silenceFade;
  final double pulseIntervalRandomPercent;
  final double beatRadiusAwareContrastStrength;
  final double beatSpeedThresholdSpreadStrength;
  final List<BeatResponseCurve> beatResponseCurves;
  final List<List<AudioBand>> onsetBandMapping;
  final MotionOutputRecorder recordMotionOutput;
}

class HeartbeatCommandPipelineRequestMapper {
  const HeartbeatCommandPipelineRequestMapper();

  HeartbeatCommandPipelineRequest map({
    required HeartbeatCommandPipelineRequestMapperInput input,
  }) {
    return HeartbeatCommandPipelineRequest(
      amplitudeToSend: input.amplitudeToSend,
      carrierToSend: input.carrierToSend,
      effectivePulseHz: input.effectivePulseHz,
      pulseWidthCycles: input.pulseWidthCycles,
      pulseRiseTimeCycles: input.pulseRiseTimeCycles,
      normalizedPulseIntervalRandom: input.normalizedPulseIntervalRandom,
      outputMode: input.outputMode,
      cal3Neutral: input.cal3Neutral,
      cal3Right: input.cal3Right,
      cal3Center: input.cal3Center,
      cal4A: input.cal4A,
      cal4B: input.cal4B,
      cal4C: input.cal4C,
      cal4D: input.cal4D,
      forceSync: input.precompute.forceSync,
      shouldSendAxis: input.shouldSendAxis,
      moveAxis: input.moveAxis,
      calibrationPattern: input.calibrationPattern,
      calibrationController: input.calibrationController,
      manualAlpha: input.manualAlpha,
      manualBeta: input.manualBeta,
      manualE1: input.manualE1,
      manualE2: input.manualE2,
      manualE3: input.manualE3,
      manualE4: input.manualE4,
      dtSec: input.precompute.dtSec,
      nowSec: input.precompute.nowSec,
      markFullSync: input.markFullSync,
      updateFourPhaseElectrodeLevels: input.updateFourPhaseElectrodeLevels,
      updateThreePhaseElectrodeLevels: input.updateThreePhaseElectrodeLevels,
      recordCalibrationOutput: input.recordCalibrationOutput,
      nowMs: input.precompute.nowMs,
      stimMode: input.stimMode,
      beatMotion: input.beatMotion,
      onsetMotion: input.onsetMotion,
      features: input.precompute.features,
      blendedAngle: input.outputApplyResult.blendedAngle,
      base: input.outputApplyResult.base,
      silenceFade: input.silenceFade,
      fillAngle: input.heartbeatMotionState.fillAngle,
      pulseIntervalRandomPercent: input.pulseIntervalRandomPercent,
      beatRadiusAwareContrastStrength: input.beatRadiusAwareContrastStrength,
      beatSpeedThresholdSpreadStrength: input.beatSpeedThresholdSpreadStrength,
      beatResponseCurves: input.beatResponseCurves,
      onsetBandMapping: input.onsetBandMapping,
      blendX: input.outputApplyResult.blendX,
      blendY: input.outputApplyResult.blendY,
      fillCenterY: input.heartbeatMotionState.fillCenterY,
      fillRadius: input.heartbeatMotionState.fillRadius,
      fillHhImpulse: input.heartbeatMotionState.fillHhImpulse,
      outputDrive: input.outputApplyResult.outputDrive,
      recordMotionOutput: input.recordMotionOutput,
      amplitudeAmps: input.outputApplyResult.amplitudeAmps,
    );
  }
}
