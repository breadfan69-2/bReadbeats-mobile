import '../audio/motion/four_phase_electrode_mapper.dart';
import 'heartbeat_axis_command_mapper.dart';
import 'heartbeat_axis_dispatch_controller.dart';

typedef FourPhaseElectrodeLevelUpdater =
    void Function({
      required double e1,
      required double e2,
      required double e3,
      required double e4,
    });

typedef ThreePhaseElectrodeLevelUpdater =
    void Function({
      required double alpha,
      required double beta,
      required double outputScale,
    });

class HeartbeatModeAxisApplyController {
  const HeartbeatModeAxisApplyController({
    this.heartbeatAxisCommandMapper = const HeartbeatAxisCommandMapper(),
    this.heartbeatAxisDispatchController =
        const HeartbeatAxisDispatchController(),
  });

  final HeartbeatAxisCommandMapper heartbeatAxisCommandMapper;
  final HeartbeatAxisDispatchController heartbeatAxisDispatchController;

  void applyFourPhase({
    required FourPhaseElectrodeOutput fourPhaseOutput,
    required List<Future<void>> operations,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    required FourPhaseElectrodeLevelUpdater updateFourPhaseElectrodeLevels,
  }) {
    final List<HeartbeatAxisCommand> fourPhaseCommands =
        heartbeatAxisCommandMapper.mapFourPhaseOutputAxes(fourPhaseOutput);

    heartbeatAxisDispatchController.queueCommands(
      operations: operations,
      commands: fourPhaseCommands,
      forceSync: forceSync,
      shouldSendAxis: shouldSendAxis,
      moveAxis: moveAxis,
    );

    updateFourPhaseElectrodeLevels(
      e1: fourPhaseOutput.e1,
      e2: fourPhaseOutput.e2,
      e3: fourPhaseOutput.e3,
      e4: fourPhaseOutput.e4,
    );
  }

  void applyThreePhase({
    required double alpha,
    required double beta,
    required double outputDrive,
    required List<Future<void>> operations,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    required ThreePhaseElectrodeLevelUpdater updateThreePhaseElectrodeLevels,
  }) {
    final List<HeartbeatAxisCommand> threePhaseCommands =
        heartbeatAxisCommandMapper.mapThreePhaseOutputAxes(
          alpha: alpha,
          beta: beta,
        );

    heartbeatAxisDispatchController.queueCommands(
      operations: operations,
      commands: threePhaseCommands,
      forceSync: forceSync,
      shouldSendAxis: shouldSendAxis,
      moveAxis: moveAxis,
    );

    updateThreePhaseElectrodeLevels(
      alpha: alpha,
      beta: beta,
      outputScale: outputDrive,
    );
  }
}
