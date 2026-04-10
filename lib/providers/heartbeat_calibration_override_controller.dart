import '../models/device_models.dart';
import '../models/enums.dart';
import 'calibration_controller.dart';
import 'calibration_pattern_tick_mapper.dart';
import 'heartbeat_axis_command_mapper.dart';
import 'heartbeat_axis_dispatch_controller.dart';
import 'heartbeat_axis_flush_controller.dart';

typedef FourPhaseCalibrationLevelUpdater =
    void Function({
      required double e1,
      required double e2,
      required double e3,
      required double e4,
    });

typedef ThreePhaseCalibrationLevelUpdater =
    void Function({
      required double alpha,
      required double beta,
      required double outputScale,
    });

typedef CalibrationOutputRecorder =
    void Function({required double amplitudeToSend, required int nowMs});

class HeartbeatCalibrationOverrideController {
  const HeartbeatCalibrationOverrideController({
    this.calibrationPatternTickMapper = const CalibrationPatternTickMapper(),
    this.heartbeatAxisCommandMapper = const HeartbeatAxisCommandMapper(),
    this.heartbeatAxisDispatchController =
        const HeartbeatAxisDispatchController(),
    this.heartbeatAxisFlushController = const HeartbeatAxisFlushController(),
  });

  final CalibrationPatternTickMapper calibrationPatternTickMapper;
  final HeartbeatAxisCommandMapper heartbeatAxisCommandMapper;
  final HeartbeatAxisDispatchController heartbeatAxisDispatchController;
  final HeartbeatAxisFlushController heartbeatAxisFlushController;

  Future<bool> handleIfActive({
    required CalibrationPattern calibrationPattern,
    required CalibrationController calibrationController,
    required double manualAlpha,
    required double manualBeta,
    required double manualE1,
    required double manualE2,
    required double manualE3,
    required double manualE4,
    required OutputModeSelection outputMode,
    required double dtSec,
    required List<Future<void>> operations,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    required double nowSec,
    required void Function(double nowSec) markFullSync,
    required FourPhaseCalibrationLevelUpdater updateFourPhaseElectrodeLevels,
    required ThreePhaseCalibrationLevelUpdater updateThreePhaseElectrodeLevels,
    required CalibrationOutputRecorder recordCalibrationOutput,
    required double amplitudeToSend,
    required int nowMs,
  }) async {
    if (calibrationPattern == CalibrationPattern.none) {
      return false;
    }

    final CalibrationPatternTickOutput calibrationOutput =
        calibrationPatternTickMapper.map(
          pattern: calibrationPattern,
          controller: calibrationController,
          outputMode: outputMode,
          dtSec: dtSec,
          manualAlpha: manualAlpha,
          manualBeta: manualBeta,
          manualE1: manualE1,
          manualE2: manualE2,
          manualE3: manualE3,
          manualE4: manualE4,
        );

    final List<HeartbeatAxisCommand> calibrationCommands =
        heartbeatAxisCommandMapper.mapCalibrationPatternAxes(calibrationOutput);
    heartbeatAxisDispatchController.queueCommands(
      operations: operations,
      commands: calibrationCommands,
      forceSync: forceSync,
      shouldSendAxis: shouldSendAxis,
      moveAxis: moveAxis,
    );

    if (calibrationOutput.isFourPhase) {
      updateFourPhaseElectrodeLevels(
        e1: calibrationOutput.e1!,
        e2: calibrationOutput.e2!,
        e3: calibrationOutput.e3!,
        e4: calibrationOutput.e4!,
      );
    } else {
      updateThreePhaseElectrodeLevels(
        alpha: calibrationOutput.alpha!,
        beta: calibrationOutput.beta!,
        outputScale: 1.0,
      );
    }

    await heartbeatAxisFlushController.flush(
      operations: operations,
      forceSync: forceSync,
      nowSec: nowSec,
      markFullSync: markFullSync,
    );

    recordCalibrationOutput(amplitudeToSend: amplitudeToSend, nowMs: nowMs);
    return true;
  }
}
