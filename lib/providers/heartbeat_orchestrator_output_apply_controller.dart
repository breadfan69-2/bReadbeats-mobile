import '../audio/motion/beat_motion_engine.dart';
import '../audio/motion/heartbeat_motion_state_controller.dart';
import '../audio/motion/heartbeat_orchestrator.dart';
import 'button_state_machine.dart';

class HeartbeatOrchestratorOutputApply {
  const HeartbeatOrchestratorOutputApply({
    required this.blendX,
    required this.blendY,
    required this.blendedAngle,
    required this.outputDrive,
    required this.base,
    required this.amplitudeAmps,
  });

  final double blendX;
  final double blendY;
  final double blendedAngle;
  final double outputDrive;
  final double base;
  final double amplitudeAmps;
}

class HeartbeatOrchestratorOutputApplyController {
  const HeartbeatOrchestratorOutputApplyController();

  HeartbeatOrchestratorOutputApply apply({
    required HeartbeatOrchestratorOutput heartbeatPrelude,
    required HeartbeatMotionStateController heartbeatMotionState,
    required BeatMotionEngine beatMotion,
    required ButtonStateMachine buttonStateMachine,
  }) {
    heartbeatMotionState.applyOrchestratorOutput(heartbeatPrelude);
    beatMotion.triggerKind = heartbeatPrelude.triggerKind;
    buttonStateMachine.setButtonHoldRamp(heartbeatPrelude.buttonHoldRamp);

    return HeartbeatOrchestratorOutputApply(
      blendX: heartbeatPrelude.blendX,
      blendY: heartbeatPrelude.blendY,
      blendedAngle: heartbeatPrelude.blendedAngle,
      outputDrive: heartbeatPrelude.outputDrive,
      base: heartbeatPrelude.base,
      amplitudeAmps: heartbeatPrelude.amplitudeAmps,
    );
  }
}
