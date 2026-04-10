import '../models/device_models.dart';
import '../models/enums.dart';
import 'calibration_controller.dart';
import 'heartbeat_axis_command_mapper.dart';
import 'heartbeat_axis_dispatch_controller.dart';
import 'heartbeat_calibration_override_controller.dart';

class HeartbeatBaseAndCalibrationController {
  const HeartbeatBaseAndCalibrationController({
    this.heartbeatAxisCommandMapper = const HeartbeatAxisCommandMapper(),
    this.heartbeatAxisDispatchController =
        const HeartbeatAxisDispatchController(),
    this.heartbeatCalibrationOverrideController =
        const HeartbeatCalibrationOverrideController(),
  });

  final HeartbeatAxisCommandMapper heartbeatAxisCommandMapper;
  final HeartbeatAxisDispatchController heartbeatAxisDispatchController;
  final HeartbeatCalibrationOverrideController
  heartbeatCalibrationOverrideController;

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
  }) {
    final List<HeartbeatAxisCommand> baseAxisCommands =
        heartbeatAxisCommandMapper.mapBaseAndCalibrationAxes(
          amplitudeToSend: amplitudeToSend,
          carrierToSend: carrierToSend,
          effectivePulseHz: effectivePulseHz,
          pulseWidthCycles: pulseWidthCycles,
          pulseRiseTimeCycles: pulseRiseTimeCycles,
          normalizedPulseIntervalRandom: normalizedPulseIntervalRandom,
          outputMode: outputMode,
          cal3Neutral: cal3Neutral,
          cal3Right: cal3Right,
          cal3Center: cal3Center,
          cal4A: cal4A,
          cal4B: cal4B,
          cal4C: cal4C,
          cal4D: cal4D,
        );

    heartbeatAxisDispatchController.queueCommands(
      operations: operations,
      commands: baseAxisCommands,
      forceSync: forceSync,
      shouldSendAxis: shouldSendAxis,
      moveAxis: moveAxis,
    );

    return heartbeatCalibrationOverrideController.handleIfActive(
      calibrationPattern: calibrationPattern,
      calibrationController: calibrationController,
      manualAlpha: manualAlpha,
      manualBeta: manualBeta,
      manualE1: manualE1,
      manualE2: manualE2,
      manualE3: manualE3,
      manualE4: manualE4,
      outputMode: outputMode,
      dtSec: dtSec,
      operations: operations,
      forceSync: forceSync,
      shouldSendAxis: shouldSendAxis,
      moveAxis: moveAxis,
      nowSec: nowSec,
      markFullSync: markFullSync,
      updateFourPhaseElectrodeLevels: updateFourPhaseElectrodeLevels,
      updateThreePhaseElectrodeLevels: updateThreePhaseElectrodeLevels,
      recordCalibrationOutput: recordCalibrationOutput,
      amplitudeToSend: amplitudeToSend,
      nowMs: nowMs,
    );
  }
}
