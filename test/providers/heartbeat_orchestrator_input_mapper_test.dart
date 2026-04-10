import 'package:breadbeats_mobile/audio/motion/heartbeat_motion_state_controller.dart';
import 'package:breadbeats_mobile/audio/motion/heartbeat_orchestrator.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/heartbeat_orchestrator_input_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatOrchestratorInputMapper mapper =
      HeartbeatOrchestratorInputMapper();

  test('maps runtime and motion state into orchestrator input', () {
    final HeartbeatMotionStateController motionState =
        HeartbeatMotionStateController(fillBaseRadius: 0.6);
    motionState.applyOrchestratorOutput(
      const HeartbeatOrchestratorOutput(
        motionDriveLevel: 0.5,
        effectivePulseHz: 12.0,
        triggerKind: TriggerKind.downbeat,
        estimatedBpm: 122.0,
        silenceFade: 0.8,
        beatRisingEdge: true,
        fluxEmaPhrase: 0.34,
        tempoLocked: true,
        effectiveBpm: 121.0,
        phraseCommitted: true,
        phraseBeatCount: 4,
        phraseFluxAtStart: 0.28,
        lastBeatTriggerMs: 12345,
        fillSilenceStartMs: 12000,
        fillTransition: 0.22,
        fillCenterY: -0.1,
        fillRadius: 0.67,
        fillAngle: 1.25,
        fillHhImpulse: 0.19,
        blendX: 0.0,
        blendY: 0.0,
        blendedAngle: 0.0,
        buttonHoldRamp: 0.9,
        outputDrive: 0.6,
        base: 0.35,
        amplitudeAmps: 0.45,
        smoothedDominantBassHz: 77.5,
        tempoUnlockHoldActive: false,
        tempoUnlockHoldBpm: 0.0,
      ),
    );

    final AudioFeatures features = AudioFeatures.zero;
    final HeartbeatOrchestratorInput input = mapper.map(
      features: features,
      mode: StimMode.onset,
      outputMode: OutputModeSelection.fourPhase,
      sensitivity: 0.7,
      intensityCap: 4.2,
      dtSec: 0.033,
      nowMs: 456789,
      hasRecentPcm: true,
      onsetSensitivityMin: 0.15,
      onsetSensitivityMax: 0.75,
      onsetSmoothing: 48.0,
      motionState: motionState,
      fillBaseRadius: 0.4,
      fillHhImpulseSize: 0.11,
      fillHhDecayRate: 3.5,
      fillRotOmega: 0.9,
      buttonHoldMuted: false,
      buttonHoldRamp: 0.42,
      buttonResumeRampSec: 0.7,
      calibrationPattern: CalibrationPattern.circle,
      manualPulseMode: true,
      manualPulseHz: 27.0,
      pulseMinHz: 8.0,
      pulseMaxHz: 44.0,
      bassMonitorLowHz: 40.0,
      bassMonitorHighHz: 130.0,
      tempoUnlockHoldEnabled: true,
      energyResponseStrength: 1.3,
      latencyCompensationMs: -25.0,
      adaptiveLeadMs: 42.0,
      learningEnabled: true,
      committedCadenceHint: 4,
      hardFillGateEnabled: true,
    );

    expect(input.features, same(features));
    expect(input.mode, StimMode.onset);
    expect(input.outputMode, OutputModeSelection.fourPhase);
    expect(input.sensitivity, closeTo(0.7, 1e-12));
    expect(input.intensityCap, closeTo(4.2, 1e-12));
    expect(input.dtSec, closeTo(0.033, 1e-12));
    expect(input.nowMs, 456789);
    expect(input.hasRecentPcm, isTrue);
    expect(input.onsetSensitivityMin, closeTo(0.15, 1e-12));
    expect(input.onsetSensitivityMax, closeTo(0.75, 1e-12));
    expect(input.onsetSmoothing, closeTo(48.0, 1e-12));

    expect(input.fluxEmaPhrase, closeTo(0.34, 1e-12));
    expect(input.phraseCommitted, isTrue);
    expect(input.phraseBeatCount, 4);
    expect(input.phraseFluxAtStart, closeTo(0.28, 1e-12));
    expect(input.lastBeatTriggerMs, 12345);
    expect(input.fillSilenceStartMs, 12000);
    expect(input.fillTransition, closeTo(0.22, 1e-12));
    expect(input.fillAngle, closeTo(1.25, 1e-12));
    expect(input.fillHhImpulse, closeTo(0.19, 1e-12));
    expect(input.smoothedDominantBassHz, closeTo(77.5, 1e-12));

    expect(input.fillBaseRadius, closeTo(0.4, 1e-12));
    expect(input.fillHhImpulseSize, closeTo(0.11, 1e-12));
    expect(input.fillHhDecayRate, closeTo(3.5, 1e-12));
    expect(input.fillRotOmega, closeTo(0.9, 1e-12));
    expect(input.buttonHoldMuted, isFalse);
    expect(input.buttonHoldRamp, closeTo(0.42, 1e-12));
    expect(input.buttonResumeRampSec, closeTo(0.7, 1e-12));
    expect(input.calibrationPattern, CalibrationPattern.circle);
    expect(input.manualPulseMode, isTrue);
    expect(input.manualPulseHz, closeTo(27.0, 1e-12));
    expect(input.pulseMinHz, closeTo(8.0, 1e-12));
    expect(input.pulseMaxHz, closeTo(44.0, 1e-12));
    expect(input.bassMonitorLowHz, closeTo(40.0, 1e-12));
    expect(input.bassMonitorHighHz, closeTo(130.0, 1e-12));
    expect(input.tempoUnlockHoldEnabled, isTrue);
    expect(input.energyResponseStrength, closeTo(1.3, 1e-12));
    expect(input.latencyCompensationMs, closeTo(-25.0, 1e-12));
    expect(input.adaptiveLeadMs, closeTo(42.0, 1e-12));
    expect(input.learningEnabled, isTrue);
    expect(input.committedCadenceHint, 4);
  });
}
