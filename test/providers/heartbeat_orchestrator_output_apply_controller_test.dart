import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/heartbeat_motion_state_controller.dart';
import 'package:breadbeats_mobile/audio/motion/heartbeat_orchestrator.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/button_state_machine.dart';
import 'package:breadbeats_mobile/providers/heartbeat_orchestrator_output_apply_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('apply updates motion/button state and returns projection values', () {
    const HeartbeatOrchestratorOutputApplyController controller =
        HeartbeatOrchestratorOutputApplyController();
    final HeartbeatMotionStateController motionState =
        HeartbeatMotionStateController(fillBaseRadius: 0.7);
    final BeatMotionEngine beatMotion = BeatMotionEngine();
    final ButtonStateMachine buttonStateMachine = ButtonStateMachine();

    beatMotion.triggerKind = TriggerKind.fill;

    const HeartbeatOrchestratorOutput heartbeatPrelude =
        HeartbeatOrchestratorOutput(
          motionDriveLevel: 0.64,
          effectivePulseHz: 18.5,
          triggerKind: TriggerKind.downbeat,
          estimatedBpm: 126.0,
          silenceFade: 0.81,
          beatRisingEdge: true,
          fluxEmaPhrase: 0.32,
          tempoLocked: true,
          effectiveBpm: 125.0,
          phraseCommitted: true,
          phraseBeatCount: 3,
          phraseFluxAtStart: 0.27,
          lastBeatTriggerMs: 12345,
          fillSilenceStartMs: 12340,
          fillTransition: 0.44,
          fillCenterY: -0.21,
          fillRadius: 0.66,
          fillAngle: 1.23,
          fillHhImpulse: 0.19,
          blendX: -0.37,
          blendY: 0.28,
          blendedAngle: 2.14,
          buttonHoldRamp: 0.59,
          outputDrive: 0.73,
          base: 0.31,
          amplitudeAmps: 0.42,
          smoothedDominantBassHz: 63.0,
          tempoUnlockHoldActive: false,
          tempoUnlockHoldBpm: 0.0,
        );

    final HeartbeatOrchestratorOutputApply result = controller.apply(
      heartbeatPrelude: heartbeatPrelude,
      heartbeatMotionState: motionState,
      beatMotion: beatMotion,
      buttonStateMachine: buttonStateMachine,
    );

    expect(motionState.motionDriveLevel, closeTo(0.64, 1e-12));
    expect(motionState.effectivePulseHz, closeTo(18.5, 1e-12));
    expect(motionState.liveEffectivePulseHz, closeTo(18.5, 1e-12));
    expect(motionState.phraseCommitted, isTrue);
    expect(motionState.phraseBeatCount, 3);
    expect(motionState.fillCenterY, closeTo(-0.21, 1e-12));
    expect(motionState.fillRadius, closeTo(0.66, 1e-12));
    expect(motionState.fillAngle, closeTo(1.23, 1e-12));
    expect(motionState.fillHhImpulse, closeTo(0.19, 1e-12));
    expect(motionState.smoothedDominantBassHz, closeTo(63.0, 1e-12));

    expect(beatMotion.triggerKind, TriggerKind.downbeat);
    expect(buttonStateMachine.buttonHoldRamp, closeTo(0.59, 1e-12));

    expect(result.blendX, closeTo(-0.37, 1e-12));
    expect(result.blendY, closeTo(0.28, 1e-12));
    expect(result.blendedAngle, closeTo(2.14, 1e-12));
    expect(result.outputDrive, closeTo(0.73, 1e-12));
    expect(result.base, closeTo(0.31, 1e-12));
    expect(result.amplitudeAmps, closeTo(0.42, 1e-12));
  });
}
