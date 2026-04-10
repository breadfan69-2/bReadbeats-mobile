import '../audio/motion/beat_motion_engine.dart';
import '../audio/motion/onset_motion_engine.dart';
import '../audio/processing/audio_signal_processor.dart';
import '../models/device_models.dart';
import '../models/enums.dart';
import 'calibration_controller.dart';
import 'heartbeat_axis_dispatch_controller.dart';
import 'heartbeat_base_and_calibration_controller.dart';
import 'heartbeat_calibration_override_controller.dart';
import 'heartbeat_mode_output_controller.dart';
import 'heartbeat_tick_finalize_controller.dart';

class HeartbeatCommandPipelineRequest {
  const HeartbeatCommandPipelineRequest({
    required this.amplitudeToSend,
    required this.carrierToSend,
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
    required this.forceSync,
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
    required this.dtSec,
    required this.nowSec,
    required this.markFullSync,
    required this.updateFourPhaseElectrodeLevels,
    required this.updateThreePhaseElectrodeLevels,
    required this.recordCalibrationOutput,
    required this.nowMs,
    required this.stimMode,
    required this.beatMotion,
    required this.onsetMotion,
    required this.features,
    required this.blendedAngle,
    required this.base,
    required this.silenceFade,
    required this.fillAngle,
    required this.pulseIntervalRandomPercent,
    required this.beatRadiusAwareContrastStrength,
    required this.beatSpeedThresholdSpreadStrength,
    required this.beatResponseCurves,
    required this.onsetBandMapping,
    required this.blendX,
    required this.blendY,
    required this.fillCenterY,
    required this.fillRadius,
    required this.fillHhImpulse,
    required this.outputDrive,
    required this.recordMotionOutput,
    required this.amplitudeAmps,
  });

  final double amplitudeToSend;
  final double carrierToSend;
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
  final bool forceSync;
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
  final double dtSec;
  final double nowSec;
  final void Function(double nowSec) markFullSync;
  final FourPhaseCalibrationLevelUpdater updateFourPhaseElectrodeLevels;
  final ThreePhaseCalibrationLevelUpdater updateThreePhaseElectrodeLevels;
  final CalibrationOutputRecorder recordCalibrationOutput;
  final int nowMs;
  final StimMode stimMode;
  final BeatMotionEngine beatMotion;
  final OnsetMotionEngine onsetMotion;
  final AudioFeatures features;
  final double blendedAngle;
  final double base;
  final double silenceFade;
  final double fillAngle;
  final double pulseIntervalRandomPercent;
  final double beatRadiusAwareContrastStrength;
  final double beatSpeedThresholdSpreadStrength;
  final List<BeatResponseCurve> beatResponseCurves;
  final List<List<AudioBand>> onsetBandMapping;
  final double blendX;
  final double blendY;
  final double fillCenterY;
  final double fillRadius;
  final double fillHhImpulse;
  final double outputDrive;
  final MotionOutputRecorder recordMotionOutput;
  final double amplitudeAmps;
}

class HeartbeatCommandPipelineController {
  const HeartbeatCommandPipelineController({
    this.heartbeatBaseAndCalibrationController =
        const HeartbeatBaseAndCalibrationController(),
    this.heartbeatModeOutputController = const HeartbeatModeOutputController(),
    this.heartbeatTickFinalizeController =
        const HeartbeatTickFinalizeController(),
  });

  final HeartbeatBaseAndCalibrationController
  heartbeatBaseAndCalibrationController;
  final HeartbeatModeOutputController heartbeatModeOutputController;
  final HeartbeatTickFinalizeController heartbeatTickFinalizeController;

  Future<bool> execute({
    required HeartbeatCommandPipelineRequest request,
  }) async {
    final List<Future<void>> operations = <Future<void>>[];

    final bool handledCalibrationOverride =
        await heartbeatBaseAndCalibrationController
            .queueBaseAndHandleCalibrationOverride(
              amplitudeToSend: request.amplitudeToSend,
              carrierToSend: request.carrierToSend,
              effectivePulseHz: request.effectivePulseHz,
              pulseWidthCycles: request.pulseWidthCycles,
              pulseRiseTimeCycles: request.pulseRiseTimeCycles,
              normalizedPulseIntervalRandom:
                  request.normalizedPulseIntervalRandom,
              outputMode: request.outputMode,
              cal3Neutral: request.cal3Neutral,
              cal3Right: request.cal3Right,
              cal3Center: request.cal3Center,
              cal4A: request.cal4A,
              cal4B: request.cal4B,
              cal4C: request.cal4C,
              cal4D: request.cal4D,
              operations: operations,
              forceSync: request.forceSync,
              shouldSendAxis: request.shouldSendAxis,
              moveAxis: request.moveAxis,
              calibrationPattern: request.calibrationPattern,
              calibrationController: request.calibrationController,
              manualAlpha: request.manualAlpha,
              manualBeta: request.manualBeta,
              manualE1: request.manualE1,
              manualE2: request.manualE2,
              manualE3: request.manualE3,
              manualE4: request.manualE4,
              dtSec: request.dtSec,
              nowSec: request.nowSec,
              markFullSync: request.markFullSync,
              updateFourPhaseElectrodeLevels:
                  request.updateFourPhaseElectrodeLevels,
              updateThreePhaseElectrodeLevels:
                  request.updateThreePhaseElectrodeLevels,
              recordCalibrationOutput: request.recordCalibrationOutput,
              nowMs: request.nowMs,
            );

    if (handledCalibrationOverride) {
      return true;
    }

    heartbeatModeOutputController.apply(
      outputMode: request.outputMode,
      stimMode: request.stimMode,
      beatMotion: request.beatMotion,
      onsetMotion: request.onsetMotion,
      features: request.features,
      blendedAngle: request.blendedAngle,
      base: request.base,
      silenceFade: request.silenceFade,
      fillAngle: request.fillAngle,
      pulseIntervalRandomPercent: request.pulseIntervalRandomPercent,
      beatRadiusAwareContrastStrength: request.beatRadiusAwareContrastStrength,
      beatSpeedThresholdSpreadStrength:
          request.beatSpeedThresholdSpreadStrength,
      beatResponseCurves: request.beatResponseCurves,
      bandMapping: request.onsetBandMapping,
      blendX: request.blendX,
      blendY: request.blendY,
      fillCenterY: request.fillCenterY,
      fillRadius: request.fillRadius,
      fillHhImpulse: request.fillHhImpulse,
      outputDrive: request.outputDrive,
      operations: operations,
      forceSync: request.forceSync,
      shouldSendAxis: request.shouldSendAxis,
      moveAxis: request.moveAxis,
      updateFourPhaseElectrodeLevels: request.updateFourPhaseElectrodeLevels,
      updateThreePhaseElectrodeLevels: request.updateThreePhaseElectrodeLevels,
    );

    await heartbeatTickFinalizeController.finalize(
      operations: operations,
      forceSync: request.forceSync,
      nowSec: request.nowSec,
      markFullSync: request.markFullSync,
      recordMotionOutput: request.recordMotionOutput,
      amplitudeToSend: request.amplitudeToSend,
      base: request.base,
      amplitudeAmps: request.amplitudeAmps,
      nowMs: request.nowMs,
    );

    return false;
  }
}
