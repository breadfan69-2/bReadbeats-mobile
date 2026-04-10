import '../audio/motion/beat_motion_engine.dart';
import '../audio/motion/four_phase_electrode_mapper.dart';
import '../audio/motion/onset_motion_engine.dart';
import '../audio/motion/three_phase_position_mapper.dart';
import '../audio/processing/audio_signal_processor.dart';
import '../models/device_models.dart';
import '../models/enums.dart';
import 'heartbeat_axis_dispatch_controller.dart';
import 'heartbeat_mode_axis_apply_controller.dart';

class HeartbeatModeOutputController {
  const HeartbeatModeOutputController({
    this.fourPhaseElectrodeMapper = const FourPhaseElectrodeMapper(),
    this.threePhasePositionMapper = const ThreePhasePositionMapper(),
    this.heartbeatModeAxisApplyController =
        const HeartbeatModeAxisApplyController(),
  });

  final FourPhaseElectrodeMapper fourPhaseElectrodeMapper;
  final ThreePhasePositionMapper threePhasePositionMapper;
  final HeartbeatModeAxisApplyController heartbeatModeAxisApplyController;

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
    if (outputMode == OutputModeSelection.fourPhase) {
      final FourPhaseElectrodeOutput fourPhaseOutput = fourPhaseElectrodeMapper
          .map(
            stimMode: stimMode,
            beatMotion: beatMotion,
            features: features,
            blendedAngle: blendedAngle,
            blendX: blendX,
            blendY: blendY,
            base: base,
            silenceFade: silenceFade,
            fillAngle: fillAngle,
            pulseIntervalRandomPercent: pulseIntervalRandomPercent,
            beatRadiusAwareContrastStrength: beatRadiusAwareContrastStrength,
            beatSpeedThresholdSpreadStrength: beatSpeedThresholdSpreadStrength,
            beatResponseCurves: beatResponseCurves,
            bandMapping: bandMapping,
          );

      heartbeatModeAxisApplyController.applyFourPhase(
        fourPhaseOutput: fourPhaseOutput,
        operations: operations,
        forceSync: forceSync,
        shouldSendAxis: shouldSendAxis,
        moveAxis: moveAxis,
        updateFourPhaseElectrodeLevels: updateFourPhaseElectrodeLevels,
      );
      return;
    }

    final (double alpha, double beta) = threePhasePositionMapper.map(
      stimMode: stimMode,
      beatMotion: beatMotion,
      onsetMotion: onsetMotion,
      blendX: blendX,
      blendY: blendY,
      fillCenterY: fillCenterY,
      fillRadius: fillRadius,
      fillAngle: fillAngle,
      fillHhImpulse: fillHhImpulse,
      silenceFade: silenceFade,
    );

    heartbeatModeAxisApplyController.applyThreePhase(
      alpha: alpha,
      beta: beta,
      outputDrive: outputDrive,
      operations: operations,
      forceSync: forceSync,
      shouldSendAxis: shouldSendAxis,
      moveAxis: moveAxis,
      updateThreePhaseElectrodeLevels: updateThreePhaseElectrodeLevels,
    );
  }
}
