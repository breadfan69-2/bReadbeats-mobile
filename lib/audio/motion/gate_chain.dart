import '../../models/enums.dart';
import '../../models/motion_constants.dart';
import '../processing/audio_signal_processor.dart';

class GateChain {
  int gateFailCount = 0;
  double specFillPassSeconds = 0.0;
  TriggerKind specFillKind = TriggerKind.fill;

  bool tempoLocked = false;
  bool strokeReady = false;
  int strokeGreenCount = 0;
  int strokeYellowCount = 0;
  int strokeBlockStreak = 0;
  int lastStrokeGraceMs = 0;

  // Tempo-unlock hold state
  bool tempoUnlockHoldActive = false;
  double tempoUnlockHoldBpm = 0.0;
  double tempoUnlockHoldFluxBaseline = 0.0;

  bool updateTempoLock(
    AudioFeatures features, {
    bool tempoUnlockHoldEnabled = true,
  }) {
    final bool hasMetronome = features.metronomeBpm > 0.0;
    final double confidence = features.metronomeConfidence;

    final bool wasLocked = tempoLocked;

    if (tempoLocked) {
      if (!hasMetronome || confidence < tempoLockExitConfidence) {
        tempoLocked = false;
      }
    } else {
      if (hasMetronome && confidence >= tempoLockEnterConfidence) {
        tempoLocked = true;
      }
    }

    // Tempo-unlock hold: when tempo drops from locked, coast on last BPM
    // until flux signature changes significantly (spike or drop).
    if (tempoUnlockHoldEnabled) {
      if (wasLocked && !tempoLocked) {
        // Just lost lock — enter hold mode.
        tempoUnlockHoldActive = true;
        tempoUnlockHoldBpm = features.metronomeBpm > 0.0
            ? features.metronomeBpm
            : tempoUnlockHoldBpm;
        tempoUnlockHoldFluxBaseline = features.flux;
      } else if (tempoLocked) {
        // Re-acquired lock — cancel hold.
        tempoUnlockHoldActive = false;
      }

      if (tempoUnlockHoldActive && tempoUnlockHoldFluxBaseline > 0.01) {
        final double fluxRatio =
            features.flux / tempoUnlockHoldFluxBaseline;
        if (fluxRatio > tempoUnlockHoldFluxSpikeRatio ||
            fluxRatio < tempoUnlockHoldFluxDropRatio) {
          // Flux signature changed — cancel hold.
          tempoUnlockHoldActive = false;
        }
      }
    } else {
      tempoUnlockHoldActive = false;
    }

    return tempoLocked || tempoUnlockHoldActive;
  }

  void updateStrokeReadiness({required bool tempoLocked, required int nowMs}) {
    if (tempoLocked) {
      strokeGreenCount += 1;
      strokeYellowCount = 0;
      strokeBlockStreak = 0;
      lastStrokeGraceMs = 0;
      if (strokeGreenCount >= strokeGreenThreshold) {
        strokeReady = true;
      }
    } else {
      strokeYellowCount += 1;
      strokeGreenCount = 0;
      if (strokeYellowCount >= strokeYellowThreshold) {
        if (strokeReady && lastStrokeGraceMs == 0) {
          lastStrokeGraceMs = nowMs;
        }
        if (lastStrokeGraceMs > 0 &&
            (nowMs - lastStrokeGraceMs) > strokeGracePeriodMs) {
          strokeBlockStreak += 1;
          if (strokeBlockStreak >= strokeBlockLimit) {
            strokeReady = false;
            lastStrokeGraceMs = 0;
          }
        }
      }
    }
  }

  bool evaluateBeatGates({
    required AudioFeatures features,
    required double dtSec,
    required TriggerKind triggerKind,
    double energyFullness = 0.0,
    double energyResponseStrength = 1.0,
  }) {
    final bool fluxDropPasses = !features.fluxDropActive;

    final double fillThreshold;
    final double fillSustainSec;
    if (specFillKind != triggerKind) {
      specFillKind = triggerKind;
      specFillPassSeconds = 0.0;
    }

    switch (triggerKind) {
      case TriggerKind.downbeat:
        fillThreshold = specFillThresholdDownbeat;
        fillSustainSec = specFillSustainDownbeatSec;
      case TriggerKind.syncopation:
        fillThreshold = specFillThresholdSyncopation;
        fillSustainSec = specFillSustainSyncopationSec;
      case TriggerKind.beat:
      case TriggerKind.fill:
        fillThreshold = specFillThresholdBeat;
        fillSustainSec = specFillSustainBeatSec;
    }

    // Energy fullness modulation: high energy reduces the fill threshold,
    // making it easier to pass the gate when music is full/loud.
    final double energyMod =
        energyFullness * energyResponseStrength * energyFillGateReduction;
    final double adjustedFillThreshold =
        (fillThreshold * (1.0 - energyMod)).clamp(0.01, 1.0);

    if (features.spectrumFillRatio >= adjustedFillThreshold) {
      specFillPassSeconds = (specFillPassSeconds + dtSec).clamp(0.0, 2.0);
    } else {
      specFillPassSeconds = 0.0;
    }
    final bool specFillPasses = specFillPassSeconds >= fillSustainSec;

    final bool strokePasses = strokeReady;

    final bool allPass = fluxDropPasses && specFillPasses && strokePasses;

    if (allPass) {
      gateFailCount = 0;
    } else {
      gateFailCount += 1;
    }

    return gateFailCount < gateFailThreshold;
  }

  void resetFillTracking() {
    gateFailCount = 0;
    specFillPassSeconds = 0.0;
    specFillKind = TriggerKind.fill;
  }

  void reset() {
    resetFillTracking();
    tempoLocked = false;
    strokeReady = false;
    strokeGreenCount = 0;
    strokeYellowCount = 0;
    strokeBlockStreak = 0;
    lastStrokeGraceMs = 0;
    tempoUnlockHoldActive = false;
    tempoUnlockHoldBpm = 0.0;
    tempoUnlockHoldFluxBaseline = 0.0;
  }
}
