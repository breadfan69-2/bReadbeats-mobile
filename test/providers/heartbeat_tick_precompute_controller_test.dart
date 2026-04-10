import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/fill_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/gate_chain.dart';
import 'package:breadbeats_mobile/audio/motion/heartbeat_motion_state_controller.dart';
import 'package:breadbeats_mobile/audio/motion/heartbeat_orchestrator.dart';
import 'package:breadbeats_mobile/audio/motion/onset_motion_engine.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/heartbeat_orchestrator_input_mapper.dart';
import 'package:breadbeats_mobile/providers/heartbeat_tick_precompute_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_tick_prelude_mapper.dart';
import 'package:breadbeats_mobile/providers/heartbeat_waveform_output_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compute wires prelude, orchestrator input, and waveform mapping', () {
    final HeartbeatMotionStateController motionState =
        HeartbeatMotionStateController(fillBaseRadius: 0.52);
    motionState.applyOrchestratorOutput(
      const HeartbeatOrchestratorOutput(
        motionDriveLevel: 0.5,
        effectivePulseHz: 13.0,
        triggerKind: TriggerKind.downbeat,
        estimatedBpm: 124.0,
        silenceFade: 0.8,
        beatRisingEdge: true,
        fluxEmaPhrase: 0.31,
        tempoLocked: true,
        effectiveBpm: 123.0,
        phraseCommitted: true,
        phraseBeatCount: 4,
        phraseFluxAtStart: 0.27,
        lastBeatTriggerMs: 9876,
        fillSilenceStartMs: 9500,
        fillTransition: 0.44,
        fillCenterY: -0.19,
        fillRadius: 0.66,
        fillAngle: 1.82,
        fillHhImpulse: 0.21,
        blendX: 0.0,
        blendY: 0.0,
        blendedAngle: 0.0,
        buttonHoldRamp: 0.75,
        outputDrive: 0.61,
        base: 0.32,
        amplitudeAmps: 0.28,
        smoothedDominantBassHz: 71.0,
        tempoUnlockHoldActive: false,
        tempoUnlockHoldBpm: 0.0,
      ),
    );

    const HeartbeatTickPrelude prelude = HeartbeatTickPrelude(
      nowSec: 45.6,
      nowMs: 45600,
      hdlcDroppedFrames: 9,
      hasRecentPcm: true,
      dtSec: 0.025,
      forceSync: true,
      features: AudioFeatures.zero,
    );

    const HeartbeatOrchestratorOutput heartbeatPrelude =
        HeartbeatOrchestratorOutput(
          motionDriveLevel: 0.67,
          effectivePulseHz: 17.0,
          triggerKind: TriggerKind.beat,
          estimatedBpm: 126.0,
          silenceFade: 0.9,
          beatRisingEdge: true,
          fluxEmaPhrase: 0.4,
          tempoLocked: true,
          effectiveBpm: 125.0,
          phraseCommitted: true,
          phraseBeatCount: 5,
          phraseFluxAtStart: 0.29,
          lastBeatTriggerMs: 46000,
          fillSilenceStartMs: 45900,
          fillTransition: 0.5,
          fillCenterY: -0.1,
          fillRadius: 0.72,
          fillAngle: 2.4,
          fillHhImpulse: 0.3,
          blendX: -0.2,
          blendY: 0.2,
          blendedAngle: 2.1,
          buttonHoldRamp: 0.81,
          outputDrive: 0.74,
          base: 0.41,
          amplitudeAmps: 0.52,
          smoothedDominantBassHz: 76.0,
          tempoUnlockHoldActive: false,
          tempoUnlockHoldBpm: 0.0,
        );

    final _FakeHeartbeatTickPreludeMapper tickPreludeMapper =
        _FakeHeartbeatTickPreludeMapper(prelude: prelude);
    final _FakeHeartbeatOrchestrator heartbeatOrchestrator =
        _FakeHeartbeatOrchestrator(output: heartbeatPrelude);
    final _FakeHeartbeatWaveformOutputMapper waveformOutputMapper =
        _FakeHeartbeatWaveformOutputMapper(
          output: const HeartbeatWaveformOutput(
            carrierToSend: 555.0,
            tauDerating: 0.9,
            amplitudeToSend: 0.37,
          ),
        );

    final HeartbeatTickPrecomputeController controller =
        HeartbeatTickPrecomputeController(
          heartbeatTickPreludeMapper: tickPreludeMapper,
          heartbeatOrchestratorInputMapper:
              const HeartbeatOrchestratorInputMapper(),
          heartbeatOrchestrator: heartbeatOrchestrator,
          heartbeatWaveformOutputMapper: waveformOutputMapper,
        );

    final HeartbeatTickPrecomputeRequest request =
        HeartbeatTickPrecomputeRequest(
          nowMs: 111,
          hdlcDroppedFrames: 7,
          lastPcmTimestampMs: 110,
          features: AudioFeatures.zero,
          consumeDtSec: (_) => 0.04,
          shouldForceSync: (_) => false,
          mode: StimMode.onset,
          outputMode: OutputModeSelection.fourPhase,
          sensitivity: 0.7,
          intensityCap: 4.5,
          onsetSensitivityMin: 0.11,
          onsetSensitivityMax: 0.88,
          onsetSmoothing: 32.0,
          motionState: motionState,
          fillBaseRadius: 0.43,
          fillHhImpulseSize: 0.16,
          fillHhDecayRate: 2.2,
          fillRotOmega: 1.4,
          buttonHoldMuted: true,
          buttonHoldRamp: 0.62,
          buttonResumeRampSec: 0.5,
          calibrationPattern: CalibrationPattern.sequential1234,
          manualPulseMode: true,
          manualPulseHz: 21.0,
          pulseMinHz: 9.0,
          pulseMaxHz: 51.0,
          bassMonitorLowHz: 35.0,
          bassMonitorHighHz: 160.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.2,
          latencyCompensationMs: -12.0,
          adaptiveLeadMs: 14.0,
          learningEnabled: true,
          committedCadenceHint: 4,
          hardFillGateEnabled: true,
          beatMotion: BeatMotionEngine(),
          fillMotion: FillMotionEngine(),
          gateChain: GateChain(),
          onsetMotion: OnsetMotionEngine(),
          previousMotionDriveLevel: 0.58,
          startupRampAt: (double nowSec) =>
              nowSec == prelude.nowSec ? 0.73 : 0.1,
          carrierHz: 600.0,
          carrierMinHz: 100.0,
          carrierMaxHz: 700.0,
          tauMicros: 330.0,
        );

    final HeartbeatTickPrecompute result = controller.compute(request: request);

    expect(tickPreludeMapper.observedNowMs, 111);
    expect(tickPreludeMapper.observedDroppedFrames, 7);
    expect(tickPreludeMapper.observedLastPcmTimestampMs, 110);

    final HeartbeatOrchestratorInput observedInput =
        heartbeatOrchestrator.observedInput!;
    expect(observedInput.mode, StimMode.onset);
    expect(observedInput.outputMode, OutputModeSelection.fourPhase);
    expect(observedInput.sensitivity, closeTo(0.7, 1e-12));
    expect(observedInput.intensityCap, closeTo(4.5, 1e-12));
    expect(observedInput.dtSec, closeTo(0.025, 1e-12));
    expect(observedInput.nowMs, 45600);
    expect(observedInput.hasRecentPcm, isTrue);
    expect(observedInput.buttonHoldMuted, isTrue);
    expect(observedInput.buttonHoldRamp, closeTo(0.62, 1e-12));
    expect(observedInput.phraseCommitted, isTrue);
    expect(observedInput.phraseBeatCount, 4);
    expect(observedInput.fillAngle, closeTo(1.82, 1e-12));
    expect(observedInput.fillHhImpulse, closeTo(0.21, 1e-12));
    expect(observedInput.adaptiveLeadMs, closeTo(14.0, 1e-12));
    expect(observedInput.learningEnabled, isTrue);
    expect(observedInput.committedCadenceHint, 4);

    expect(
      heartbeatOrchestrator.observedPreviousMotionDriveLevel,
      closeTo(0.58, 1e-12),
    );

    expect(waveformOutputMapper.observedAmplitudeAmps, closeTo(0.52, 1e-12));
    expect(waveformOutputMapper.observedStartupRamp, closeTo(0.73, 1e-12));
    expect(waveformOutputMapper.observedCarrierHz, closeTo(600.0, 1e-12));
    expect(waveformOutputMapper.observedCarrierMinHz, closeTo(100.0, 1e-12));
    expect(waveformOutputMapper.observedCarrierMaxHz, closeTo(700.0, 1e-12));
    expect(waveformOutputMapper.observedTauMicros, closeTo(330.0, 1e-12));

    expect(result.hdlcDroppedFrames, 9);
    expect(result.nowSec, closeTo(45.6, 1e-12));
    expect(result.nowMs, 45600);
    expect(result.dtSec, closeTo(0.025, 1e-12));
    expect(result.forceSync, isTrue);
    expect(result.features, same(prelude.features));
    expect(result.heartbeatPrelude, same(heartbeatPrelude));
    expect(result.carrierToSend, closeTo(555.0, 1e-12));
    expect(result.amplitudeToSend, closeTo(0.37, 1e-12));
  });
}

class _FakeHeartbeatTickPreludeMapper extends HeartbeatTickPreludeMapper {
  _FakeHeartbeatTickPreludeMapper({required this.prelude});

  final HeartbeatTickPrelude prelude;
  int? observedNowMs;
  int? observedDroppedFrames;
  int? observedLastPcmTimestampMs;

  @override
  HeartbeatTickPrelude map({
    required int nowMs,
    required int hdlcDroppedFrames,
    required int lastPcmTimestampMs,
    required AudioFeatures features,
    required double Function(double nowSec) consumeDtSec,
    required bool Function(double nowSec) shouldForceSync,
  }) {
    observedNowMs = nowMs;
    observedDroppedFrames = hdlcDroppedFrames;
    observedLastPcmTimestampMs = lastPcmTimestampMs;
    return prelude;
  }
}

class _FakeHeartbeatOrchestrator extends HeartbeatOrchestrator {
  _FakeHeartbeatOrchestrator({required this.output});

  final HeartbeatOrchestratorOutput output;
  HeartbeatOrchestratorInput? observedInput;
  double? observedPreviousMotionDriveLevel;

  @override
  HeartbeatOrchestratorOutput tick({
    required HeartbeatOrchestratorInput input,
    required BeatMotionEngine beatMotion,
    required FillMotionEngine fillMotion,
    required GateChain gateChain,
    required OnsetMotionEngine onsetMotion,
    required double previousMotionDriveLevel,
  }) {
    observedInput = input;
    observedPreviousMotionDriveLevel = previousMotionDriveLevel;
    return output;
  }
}

class _FakeHeartbeatWaveformOutputMapper extends HeartbeatWaveformOutputMapper {
  _FakeHeartbeatWaveformOutputMapper({required this.output});

  final HeartbeatWaveformOutput output;
  double? observedAmplitudeAmps;
  double? observedStartupRamp;
  double? observedCarrierHz;
  double? observedCarrierMinHz;
  double? observedCarrierMaxHz;
  double? observedTauMicros;

  @override
  HeartbeatWaveformOutput map({
    required double amplitudeAmps,
    required double startupRamp,
    required double carrierHz,
    required double carrierMinHz,
    required double carrierMaxHz,
    required double tauMicros,
  }) {
    observedAmplitudeAmps = amplitudeAmps;
    observedStartupRamp = startupRamp;
    observedCarrierHz = carrierHz;
    observedCarrierMinHz = carrierMinHz;
    observedCarrierMaxHz = carrierMaxHz;
    observedTauMicros = tauMicros;
    return output;
  }
}
