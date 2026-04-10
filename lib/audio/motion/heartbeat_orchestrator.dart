import 'package:flutter/foundation.dart';

import '../../models/device_models.dart';
import '../../models/enums.dart';
import 'beat_motion_engine.dart';
import 'fill_motion_engine.dart';
import 'gate_chain.dart';
import 'motion_math.dart';
import 'onset_motion_engine.dart';
import '../processing/audio_signal_processor.dart';

@immutable
class HeartbeatOrchestratorInput {
  const HeartbeatOrchestratorInput({
    required this.features,
    required this.mode,
    required this.outputMode,
    required this.sensitivity,
    required this.intensityCap,
    required this.dtSec,
    required this.nowMs,
    required this.hasRecentPcm,
    required this.onsetSensitivityMin,
    required this.onsetSensitivityMax,
    required this.onsetSmoothing,
    required this.fluxEmaPhrase,
    required this.phraseCommitted,
    required this.phraseBeatCount,
    required this.phraseFluxAtStart,
    required this.lastBeatTriggerMs,
    required this.fillSilenceStartMs,
    required this.fillTransition,
    required this.fillAngle,
    required this.fillHhImpulse,
    required this.fillBaseRadius,
    required this.fillHhImpulseSize,
    required this.fillHhDecayRate,
    required this.fillRotOmega,
    required this.buttonHoldMuted,
    required this.buttonHoldRamp,
    required this.buttonResumeRampSec,
    required this.calibrationPattern,
    required this.smoothedDominantBassHz,
    required this.manualPulseMode,
    required this.manualPulseHz,
    required this.pulseMinHz,
    required this.pulseMaxHz,
    required this.bassMonitorLowHz,
    required this.bassMonitorHighHz,
    required this.tempoUnlockHoldEnabled,
    required this.energyResponseStrength,
    required this.latencyCompensationMs,
    this.adaptiveLeadMs = 0.0,
    this.learningEnabled = false,
    this.committedCadenceHint = 2,
    this.hardFillGateEnabled = false,
  });

  final AudioFeatures features;
  final StimMode mode;
  final OutputModeSelection outputMode;
  final double sensitivity;
  final double intensityCap;
  final double dtSec;
  final int nowMs;
  final bool hasRecentPcm;
  final double onsetSensitivityMin;
  final double onsetSensitivityMax;
  final double onsetSmoothing;
  final double fluxEmaPhrase;
  final bool phraseCommitted;
  final int phraseBeatCount;
  final double phraseFluxAtStart;
  final int lastBeatTriggerMs;
  final int fillSilenceStartMs;
  final double fillTransition;
  final double fillAngle;
  final double fillHhImpulse;
  final double fillBaseRadius;
  final double fillHhImpulseSize;
  final double fillHhDecayRate;
  final double fillRotOmega;
  final bool buttonHoldMuted;
  final double buttonHoldRamp;
  final double buttonResumeRampSec;
  final CalibrationPattern calibrationPattern;
  final double smoothedDominantBassHz;
  final bool manualPulseMode;
  final double manualPulseHz;
  final double pulseMinHz;
  final double pulseMaxHz;
  final double bassMonitorLowHz;
  final double bassMonitorHighHz;
  final bool tempoUnlockHoldEnabled;
  final double energyResponseStrength;
  final double latencyCompensationMs;
  final double adaptiveLeadMs;
  final bool learningEnabled;
  final int committedCadenceHint;
  final bool hardFillGateEnabled;
}

@immutable
class HeartbeatOrchestratorOutput {
  const HeartbeatOrchestratorOutput({
    required this.motionDriveLevel,
    required this.effectivePulseHz,
    required this.triggerKind,
    required this.estimatedBpm,
    required this.silenceFade,
    required this.beatRisingEdge,
    required this.fluxEmaPhrase,
    required this.tempoLocked,
    required this.effectiveBpm,
    required this.phraseCommitted,
    required this.phraseBeatCount,
    required this.phraseFluxAtStart,
    required this.lastBeatTriggerMs,
    required this.fillSilenceStartMs,
    required this.fillTransition,
    required this.fillCenterY,
    required this.fillRadius,
    required this.fillAngle,
    required this.fillHhImpulse,
    required this.blendX,
    required this.blendY,
    required this.blendedAngle,
    required this.buttonHoldRamp,
    required this.outputDrive,
    required this.base,
    required this.amplitudeAmps,
    required this.smoothedDominantBassHz,
    required this.tempoUnlockHoldActive,
    required this.tempoUnlockHoldBpm,
  });

  final double motionDriveLevel;
  final double effectivePulseHz;
  final TriggerKind triggerKind;
  final double estimatedBpm;
  final double silenceFade;
  final bool beatRisingEdge;
  final double fluxEmaPhrase;
  final bool tempoLocked;
  final double effectiveBpm;
  final bool phraseCommitted;
  final int phraseBeatCount;
  final double phraseFluxAtStart;
  final int lastBeatTriggerMs;
  final int fillSilenceStartMs;
  final double fillTransition;
  final double fillCenterY;
  final double fillRadius;
  final double fillAngle;
  final double fillHhImpulse;
  final double blendX;
  final double blendY;
  final double blendedAngle;
  final double buttonHoldRamp;
  final double outputDrive;
  final double base;
  final double amplitudeAmps;
  final double smoothedDominantBassHz;
  final bool tempoUnlockHoldActive;
  final double tempoUnlockHoldBpm;
}

class HeartbeatOrchestrator {
  const HeartbeatOrchestrator();

  HeartbeatOrchestratorOutput tick({
    required HeartbeatOrchestratorInput input,
    required BeatMotionEngine beatMotion,
    required FillMotionEngine fillMotion,
    required GateChain gateChain,
    required OnsetMotionEngine onsetMotion,
    required double previousMotionDriveLevel,
  }) {
    assert(input.dtSec >= 0.0);
    assert(input.nowMs >= 0);
    assert(input.onsetSensitivityMin <= input.onsetSensitivityMax);

    final AudioFeatures features = input.features;
    final double sensitivityGain =
        0.50 + (input.sensitivity.clamp(0.0, 1.0) * 1.45);
    final double baseDrive = (features.mono * sensitivityGain).clamp(0.0, 1.0);
    final double bandLift =
        (features.lowBand * 0.30) +
        (features.midBand * 0.24) +
        (features.highBand * 0.10);
    final double onsetBoost = (features.onset * 0.32).clamp(0.0, 0.32);

    final double targetDrive = (input.hasRecentPcm && features.gateOpen)
        ? (baseDrive + bandLift + onsetBoost).clamp(0.0, 1.0)
        : 0.0;

    final double motionDriveLevel = input.mode == StimMode.onset
        ? onsetMotion.updateOnsetDrive(
            targetDrive: targetDrive,
            dtSec: input.dtSec,
            onsetSmoothing: input.onsetSmoothing,
            onsetSensitivityMin: input.onsetSensitivityMin,
            onsetSensitivityMax: input.onsetSensitivityMax,
          )
        : smoothValue(
            previous: previousMotionDriveLevel,
            target: targetDrive,
            dtSec: input.dtSec,
            attackSec: 0.045,
            releaseSec: 0.16,
          );

    beatMotion.updateSilenceFade(
      gateOpen: features.gateOpen,
      hasRecentPcm: input.hasRecentPcm,
      dtSec: input.dtSec,
    );

    final double effectiveLatencyMs =
        input.latencyCompensationMs + input.adaptiveLeadMs;

    // Latency compensation: shift beat detection timestamp.
    // Positive = audio arrives late → treat beats as earlier.
    final int compensatedNowMs = input.nowMs + effectiveLatencyMs.round();

    final bool beatRisingEdge = beatMotion.updateBeatEdgeAndBpm(
      beatValue: features.beat,
      nowMs: compensatedNowMs,
    );

    final double totalEnergy = features.lowBand + features.midBand * 0.5;
    beatMotion.updateEnergyState(totalEnergy: totalEnergy, dtSec: input.dtSec);
    final double nextFluxEmaPhrase = beatMotion.updatePhraseFluxEma(
      fluxEmaPhrase: input.fluxEmaPhrase,
      flux: features.flux,
      dtSec: input.dtSec,
    );

    final bool tempoLocked = gateChain.updateTempoLock(
      features,
      tempoUnlockHoldEnabled: input.tempoUnlockHoldEnabled,
    );
    gateChain.updateStrokeReadiness(
      tempoLocked: tempoLocked,
      nowMs: input.nowMs,
    );

    int nextLastBeatTriggerMs = input.lastBeatTriggerMs;
    bool nextPhraseCommitted = input.phraseCommitted;
    int nextPhraseBeatCount = input.phraseBeatCount;
    double nextPhraseFluxAtStart = input.phraseFluxAtStart;
    final bool wasInFill = beatMotion.triggerKind == TriggerKind.fill;

    if (beatRisingEdge && input.mode == StimMode.beat) {
      nextLastBeatTriggerMs = input.nowMs;
      beatMotion.classifyTriggerOnBeatEdge(
        tempoLocked: tempoLocked,
        isSyncopated: features.isSyncopated,
        isDownbeat: features.isDownbeat,
        zScoreBeat: features.zScoreBeat,
        beatValue: features.beat,
      );

      final (
        bool phraseCommitted,
        int phraseBeatCount,
        double phraseFluxAtStart,
      ) = beatMotion.updatePhraseCommitmentOnBeat(
        phraseCommitted: nextPhraseCommitted,
        phraseBeatCount: nextPhraseBeatCount,
        phraseFluxAtStart: nextPhraseFluxAtStart,
        fluxEmaPhrase: nextFluxEmaPhrase,
        wasInFill: wasInFill,
      );
      nextPhraseCommitted = phraseCommitted;
      nextPhraseBeatCount = phraseBeatCount;
      nextPhraseFluxAtStart = phraseFluxAtStart;
    }

    final TriggerKind triggerKindBeforeInactivity = beatMotion.triggerKind;

    // When tempo-unlock hold is active, use the held BPM as effective metronome.
    final double effectiveMetronomeBpm =
        gateChain.tempoUnlockHoldActive && gateChain.tempoUnlockHoldBpm > 0.0
        ? gateChain.tempoUnlockHoldBpm
        : features.metronomeBpm;

    final (
      double nextEffectiveBpm,
      bool phraseCommitted,
      int phraseBeatCount,
    ) = beatMotion.applyInactivityAndResolveBpm(
      tempoLocked: tempoLocked,
      metronomeBpm: effectiveMetronomeBpm,
      stimMode: input.mode,
      lastBeatTriggerMs: nextLastBeatTriggerMs,
      nowMs: input.nowMs,
      phraseCommitted: nextPhraseCommitted,
      phraseBeatCount: nextPhraseBeatCount,
    );
    nextPhraseCommitted = phraseCommitted;
    nextPhraseBeatCount = phraseBeatCount;

    TriggerKind nextTriggerKind = beatMotion.triggerKind;
    final bool inactivityDemoted =
      triggerKindBeforeInactivity != TriggerKind.fill &&
      nextTriggerKind == TriggerKind.fill;
    bool gateDemoted = inactivityDemoted;

    if (input.mode == StimMode.beat &&
        input.hardFillGateEnabled &&
        !features.gateOpen) {
      nextTriggerKind = TriggerKind.fill;
      gateDemoted = true;
      gateChain.resetFillTracking();
    } else if (input.mode == StimMode.beat &&
        nextTriggerKind != TriggerKind.fill) {
      final bool gatesPassed = gateChain.evaluateBeatGates(
        features: features,
        dtSec: input.dtSec,
        triggerKind: nextTriggerKind,
        energyFullness: features.energyFullness,
        energyResponseStrength: input.energyResponseStrength,
      );
      if (!gatesPassed) {
        nextTriggerKind = TriggerKind.fill;
        gateDemoted = true;
        gateChain.resetFillTracking();
      }
    } else if (nextTriggerKind == TriggerKind.fill) {
      gateChain.resetFillTracking();
    }

    if (input.mode == StimMode.beat &&
        nextPhraseCommitted &&
        nextTriggerKind == TriggerKind.fill &&
        !gateDemoted &&
        features.gateOpen) {
      nextTriggerKind = TriggerKind.beat;
    }

    beatMotion.triggerKind = nextTriggerKind;

    final (int nextFillSilenceStartMs, double nextFillTransition) = fillMotion
        .updateFillTransitionState(
          triggerKind: nextTriggerKind,
          fillSilenceStartMs: input.fillSilenceStartMs,
          fillTransition: input.fillTransition,
          nowMs: input.nowMs,
          dtSec: input.dtSec,
        );

    beatMotion.updateCenterWander(stimMode: input.mode, dtSec: input.dtSec);
    beatMotion.maybeFlipOrbitDirection(
      stimMode: input.mode,
      nowMs: input.nowMs,
    );
    final TransientProfile transientProfile = beatMotion
        .evaluateTransientProfile(
          bassLowHighRatio: features.bassLowHighRatio,
          flux: features.flux,
          energyFullness: features.energyFullness,
          tempoLocked: tempoLocked,
        );
    beatMotion.updateFullnessBloomAndRadius(
      totalEnergy: totalEnergy,
      subBass: features.subBass,
      lowBand: features.lowBand,
      dtSec: input.dtSec,
      transientProfile: transientProfile,
    );

    final (
      double nextFillCenterY,
      double nextFillRadius,
      double nextFillAngle,
      double nextFillHhImpulse,
    ) = fillMotion.updateFillMicroMotion(
      dominantFullHz: features.dominantFullHz,
      dominantBassHz: features.dominantBassHz,
      zScoreMid: features.zScoreMid,
      zScoreHigh: features.zScoreHigh,
      nowMs: input.nowMs,
      dtSec: input.dtSec,
      fillAngle: input.fillAngle,
      fillHhImpulse: input.fillHhImpulse,
      fillSilenceStartMs: nextFillSilenceStartMs,
      fillBaseRadius: input.fillBaseRadius,
      fillHhImpulseSize: input.fillHhImpulseSize,
      fillHhDecayRate: input.fillHhDecayRate,
      fillRotOmega: input.fillRotOmega,
    );

    if (input.mode == StimMode.onset) {
      onsetMotion.updateStereoLevels(
        leftLevel: features.left,
        rightLevel: features.right,
        sensitivity: input.sensitivity,
        dtSec: input.dtSec,
        onsetSmoothing: input.onsetSmoothing,
      );

      if (input.outputMode == OutputModeSelection.threePhase) {
        onsetMotion.updateThreePhaseShuttle(
          onsetValue: features.onset,
          beatRisingEdge: beatRisingEdge,
          zScoreMid: features.zScoreMid,
          zScoreHigh: features.zScoreHigh,
          nowMs: input.nowMs,
          dtSec: input.dtSec,
          estimatedBpm: beatMotion.estimatedBpm,
        );
      }
    }

    beatMotion.advanceOrbitAngle(
      stimMode: input.mode,
      effectiveBpm: nextEffectiveBpm,
      dtSec: input.dtSec,
      cadenceHint: input.committedCadenceHint,
      learningEnabled: input.learningEnabled,
    );

    final (
      _,
      _,
      double nextBlendX,
      double nextBlendY,
      double nextBlendedAngle,
    ) = beatMotion.computeBlendedOrbitPosition(
      fillCenterY: nextFillCenterY,
      fillRadius: nextFillRadius,
      fillAngle: nextFillAngle,
      fillHhImpulse: nextFillHhImpulse,
      fillTransition: nextFillTransition,
    );

    final (_, _, double nextButtonHoldRamp, double nextOutputDrive) = beatMotion
        .prepareOutputDrive(
          motionDriveLevel: motionDriveLevel,
          fillTransition: nextFillTransition,
          buttonHoldMuted: input.buttonHoldMuted,
          buttonHoldRamp: input.buttonHoldRamp,
          dtSec: input.dtSec,
          buttonResumeRampSec: input.buttonResumeRampSec,
        );

    final (_, double nextBase, double nextAmplitudeAmps) = beatMotion
        .prepareStimulationAmplitude(
          calibrationPattern: input.calibrationPattern,
          buttonHoldRamp: nextButtonHoldRamp,
          outputDrive: nextOutputDrive,
          intensityCap: input.intensityCap,
        );

    final (
      double nextSmoothedDominantBassHz,
      double nextEffectivePulseHz,
    ) = beatMotion.prepareDynamicPulseFrequency(
      smoothedDominantBassHz: input.smoothedDominantBassHz,
      dominantBassHz: features.dominantBassHz,
      lowBand: features.lowBand,
      dtSec: input.dtSec,
      manualPulseMode: input.manualPulseMode,
      manualPulseHz: input.manualPulseHz,
      pulseMinHz: input.pulseMinHz,
      pulseMaxHz: input.pulseMaxHz,
      bassMonitorLowHz: input.bassMonitorLowHz,
      bassMonitorHighHz: input.bassMonitorHighHz,
    );

    return HeartbeatOrchestratorOutput(
      motionDriveLevel: motionDriveLevel,
      effectivePulseHz: nextEffectivePulseHz,
      triggerKind: nextTriggerKind,
      estimatedBpm: beatMotion.estimatedBpm,
      silenceFade: beatMotion.silenceFade,
      beatRisingEdge: beatRisingEdge,
      fluxEmaPhrase: nextFluxEmaPhrase,
      tempoLocked: tempoLocked,
      effectiveBpm: nextEffectiveBpm,
      phraseCommitted: nextPhraseCommitted,
      phraseBeatCount: nextPhraseBeatCount,
      phraseFluxAtStart: nextPhraseFluxAtStart,
      lastBeatTriggerMs: nextLastBeatTriggerMs,
      fillSilenceStartMs: nextFillSilenceStartMs,
      fillTransition: nextFillTransition,
      fillCenterY: nextFillCenterY,
      fillRadius: nextFillRadius,
      fillAngle: nextFillAngle,
      fillHhImpulse: nextFillHhImpulse,
      blendX: nextBlendX,
      blendY: nextBlendY,
      blendedAngle: nextBlendedAngle,
      buttonHoldRamp: nextButtonHoldRamp,
      outputDrive: nextOutputDrive,
      base: nextBase,
      amplitudeAmps: nextAmplitudeAmps,
      smoothedDominantBassHz: nextSmoothedDominantBassHz,
      tempoUnlockHoldActive: gateChain.tempoUnlockHoldActive,
      tempoUnlockHoldBpm: gateChain.tempoUnlockHoldBpm,
    );
  }
}
