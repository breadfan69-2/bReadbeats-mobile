import 'dart:math';

import '../../models/enums.dart';
import '../../models/motion_constants.dart';
import 'motion_math.dart';

class BeatMotionEngine {
  double orbitAngle = 0.0;
  double orbitRadius = 0.70;
  double estimatedBpm = 120.0;
  double silenceFade = 0.0;
  bool beatWasHigh = false;
  int lastBeatEdgeMs = 0;
  final List<double> beatIntervals = <double>[];

  TriggerKind triggerKind = TriggerKind.fill;
  int beatCountInPhrase = 0;
  double energyEma = 0.0;
  double energyEmaSlow = 0.0;

  int orbitDirection = 1;
  int lastDirectionChangeMs = 0;
  double orbitAngularSpeedRadPerSec = 0.0;
  double wanderPhase = 0.0;
  double centerYWander = 0.0;
  double energyFullness = 0.0;
  double subBassBloom = 0.0;

  bool updateBeatEdgeAndBpm({
    required double beatValue,
    required int nowMs,
    double edgeThreshold = 0.5,
  }) {
    bool beatRisingEdge = false;
    if (beatValue >= edgeThreshold && !beatWasHigh) {
      beatWasHigh = true;
      beatRisingEdge = true;
      if (lastBeatEdgeMs > 0) {
        final double ibiSec = (nowMs - lastBeatEdgeMs) / 1000.0;
        if (ibiSec >= 0.27 && ibiSec <= 1.5) {
          beatIntervals.add(ibiSec);
          if (beatIntervals.length > 8) {
            beatIntervals.removeAt(0);
          }
          if (beatIntervals.length >= 2) {
            final double avgIbi =
                beatIntervals.reduce((double a, double b) => a + b) /
                beatIntervals.length;
            estimatedBpm = (60.0 / avgIbi).clamp(40.0, 220.0);
          }
        }
      }
      lastBeatEdgeMs = nowMs;
    } else if (beatValue < edgeThreshold * 0.4) {
      beatWasHigh = false;
    }
    return beatRisingEdge;
  }

  void updateEnergyState({required double totalEnergy, required double dtSec}) {
    energyEma += (totalEnergy - energyEma) * (1.0 - exp(-dtSec / 0.15));
    energyEmaSlow += (totalEnergy - energyEmaSlow) * (1.0 - exp(-dtSec / 2.0));
  }

  double updateSilenceFade({
    required bool gateOpen,
    required bool hasRecentPcm,
    required double dtSec,
    double fadeInSec = 1.8,
    double fadeOutSec = 0.6,
  }) {
    if (gateOpen && hasRecentPcm) {
      silenceFade = (silenceFade + dtSec / fadeInSec).clamp(0.0, 1.0);
    } else {
      silenceFade = (silenceFade - dtSec / fadeOutSec).clamp(0.0, 1.0);
    }
    return silenceFade;
  }

  double updatePhraseFluxEma({
    required double fluxEmaPhrase,
    required double flux,
    required double dtSec,
  }) {
    return fluxEmaPhrase + (flux - fluxEmaPhrase) * (1.0 - exp(-dtSec / 0.3));
  }

  void classifyTriggerOnBeatEdge({
    required bool tempoLocked,
    required bool isSyncopated,
    required bool isDownbeat,
    required bool zScoreBeat,
    required double beatValue,
  }) {
    if (tempoLocked) {
      if (isSyncopated) {
        triggerKind = TriggerKind.syncopation;
      } else if (isDownbeat) {
        triggerKind = TriggerKind.downbeat;
      } else {
        triggerKind = TriggerKind.beat;
      }
      return;
    }

    beatCountInPhrase = (beatCountInPhrase + 1) % 8;
    if (beatCountInPhrase == 0 || beatCountInPhrase == 4) {
      triggerKind = TriggerKind.downbeat;
    } else if (zScoreBeat && beatValue < 0.7) {
      triggerKind = TriggerKind.syncopation;
    } else {
      triggerKind = TriggerKind.beat;
    }
  }

  bool shouldDemoteToFillForInactivity({
    required StimMode stimMode,
    required int lastBeatTriggerMs,
    required int nowMs,
    required double effectiveBpm,
  }) {
    if (stimMode != StimMode.beat || lastBeatTriggerMs <= 0) {
      return false;
    }
    final double beatPeriodMs = 60000.0 / effectiveBpm;
    final int elapsed = nowMs - lastBeatTriggerMs;
    // Demote on BPM-relative gap OR absolute 2s wall-clock timeout.
    return elapsed > beatPeriodMs * 2.2 || elapsed > absoluteNoBeatTimeoutMs;
  }

  bool shouldExpirePhraseForInactivity({
    required bool phraseCommitted,
    required int lastBeatTriggerMs,
    required int nowMs,
    required double effectiveBpm,
  }) {
    if (!phraseCommitted || lastBeatTriggerMs <= 0) {
      return false;
    }
    final double beatPeriodMs = 60000.0 / effectiveBpm;
    return (nowMs - lastBeatTriggerMs) > beatPeriodMs * 4.0;
  }

  (double effectiveBpm, bool phraseCommitted, int phraseBeatCount)
  applyInactivityAndResolveBpm({
    required bool tempoLocked,
    required double metronomeBpm,
    required StimMode stimMode,
    required int lastBeatTriggerMs,
    required int nowMs,
    required bool phraseCommitted,
    required int phraseBeatCount,
  }) {
    final double effectiveBpm = tempoLocked && metronomeBpm > 0.0
        ? metronomeBpm
        : estimatedBpm;

    if (shouldDemoteToFillForInactivity(
      stimMode: stimMode,
      lastBeatTriggerMs: lastBeatTriggerMs,
      nowMs: nowMs,
      effectiveBpm: effectiveBpm,
    )) {
      triggerKind = TriggerKind.fill;
    }

    bool nextPhraseCommitted = phraseCommitted;
    int nextPhraseBeatCount = phraseBeatCount;
    if (shouldExpirePhraseForInactivity(
      phraseCommitted: nextPhraseCommitted,
      lastBeatTriggerMs: lastBeatTriggerMs,
      nowMs: nowMs,
      effectiveBpm: effectiveBpm,
    )) {
      nextPhraseCommitted = false;
      nextPhraseBeatCount = 0;
    }

    return (effectiveBpm, nextPhraseCommitted, nextPhraseBeatCount);
  }

  (bool phraseCommitted, int phraseBeatCount, double phraseFluxAtStart)
  updatePhraseCommitmentOnBeat({
    required bool phraseCommitted,
    required int phraseBeatCount,
    required double phraseFluxAtStart,
    required double fluxEmaPhrase,
    required bool wasInFill,
  }) {
    bool nextPhraseCommitted = phraseCommitted;
    int nextPhraseBeatCount = phraseBeatCount + 1;
    double nextPhraseFluxAtStart = phraseFluxAtStart;

    if (nextPhraseBeatCount == 1) {
      nextPhraseFluxAtStart = fluxEmaPhrase;
    }
    if (!nextPhraseCommitted && nextPhraseBeatCount == 1 && wasInFill) {
      nextPhraseCommitted = true;
    }

    if (nextPhraseCommitted &&
        nextPhraseFluxAtStart > 0.01 &&
        fluxEmaPhrase < nextPhraseFluxAtStart * 0.35) {
      nextPhraseCommitted = false;
      nextPhraseBeatCount = 0;
    }

    if (nextPhraseBeatCount >= 8) {
      if (fluxEmaPhrase > nextPhraseFluxAtStart * 0.55) {
        nextPhraseBeatCount = 0;
      } else {
        nextPhraseCommitted = false;
        nextPhraseBeatCount = 0;
      }
    }

    return (nextPhraseCommitted, nextPhraseBeatCount, nextPhraseFluxAtStart);
  }

  void updateCenterWander({required StimMode stimMode, required double dtSec}) {
    if (stimMode != StimMode.beat) {
      return;
    }

    wanderPhase += dtSec;
    const double wanderPeriod = 40.0;
    const double phi = 1.618033988749895;
    centerYWander =
        0.08 * sin(2.0 * pi * wanderPhase / wanderPeriod) +
        0.04 * sin(2.0 * pi * wanderPhase / (wanderPeriod * phi)) +
        0.02 * sin(2.0 * pi * wanderPhase / (wanderPeriod * phi * phi));
  }

  void maybeFlipOrbitDirection({
    required StimMode stimMode,
    required int nowMs,
    int cooldownMs = 15000,
  }) {
    if (stimMode != StimMode.beat) {
      return;
    }

    final bool energyRising = energyEma > energyEmaSlow * 1.4;
    final bool energyFalling = energyEma < energyEmaSlow * 0.6;
    if ((energyRising || energyFalling) &&
        (nowMs - lastDirectionChangeMs) > cooldownMs) {
      orbitDirection *= -1;
      lastDirectionChangeMs = nowMs;
    }
  }

  TransientProfile evaluateTransientProfile({
    required double bassLowHighRatio,
    required double flux,
    required double energyFullness,
    required bool tempoLocked,
  }) {
    if (!tempoLocked) {
      return TransientProfile.noFeatures;
    }

    final bool fluxActive =
        flux >= bassDominanceMinFlux ||
        energyFullness >= bassDominanceMinFullness;
    final bool bassPresent = bassLowHighRatio >= bassDominanceMinRatio;

    if (bassPresent && fluxActive) {
      return TransientProfile.bassDominant;
    }
    return TransientProfile.neutral;
  }

  void updateFullnessBloomAndRadius({
    required double totalEnergy,
    required double subBass,
    required double lowBand,
    required double dtSec,
    required TransientProfile transientProfile,
  }) {
    energyFullness = smoothValue(
      previous: energyFullness,
      target: totalEnergy.clamp(0.0, 1.0),
      dtSec: dtSec,
      attackSec: 3.0,
      releaseSec: 5.0,
    );
    final double bloomMult = transientProfile == TransientProfile.neutral
        ? bassDominanceNeutralBloomMult
        : 1.0;
    subBassBloom = smoothValue(
      previous: subBassBloom,
      target: subBass * subBass * 0.15 * bloomMult,
      dtSec: dtSec,
      attackSec: 0.12,
      releaseSec: 0.5,
    );
    orbitRadius = smoothValue(
      previous: orbitRadius,
      target: (0.50 + (lowBand * 0.35) + energyFullness * 0.10 + subBassBloom)
          .clamp(0.35, 1.0),
      dtSec: dtSec,
      attackSec: 0.15,
      releaseSec: 0.4,
    ).clamp(0.35, 1.0);
  }

  void advanceOrbitAngle({
    required StimMode stimMode,
    required double effectiveBpm,
    required double dtSec,
    required int cadenceHint,
    required bool learningEnabled,
  }) {
    if (stimMode != StimMode.beat) {
      orbitAngularSpeedRadPerSec = 0.0;
      return;
    }

    final double beatsPerRevolution;
    if (learningEnabled && triggerKind != TriggerKind.syncopation) {
      beatsPerRevolution = cadenceHint.toDouble().clamp(1.0, 4.0);
    } else {
      switch (triggerKind) {
        case TriggerKind.syncopation:
          beatsPerRevolution = 1.0;
        case TriggerKind.beat:
          beatsPerRevolution = 2.0;
        case TriggerKind.downbeat:
          beatsPerRevolution = 4.0;
        case TriggerKind.fill:
          beatsPerRevolution = 2.0;
      }
    }
    final double radiansPerSec =
        (2.0 * pi * effectiveBpm) / (60.0 * beatsPerRevolution);
    final double speedScale = 0.04 + (silenceFade * 0.96);
    final double angularSpeed = radiansPerSec * speedScale;
    orbitAngularSpeedRadPerSec = angularSpeed.abs();
    orbitAngle += orbitDirection * angularSpeed * dtSec;
  }

  (
    double beatX,
    double beatY,
    double blendX,
    double blendY,
    double blendedAngle,
  )
  computeBlendedOrbitPosition({
    required double fillCenterY,
    required double fillRadius,
    required double fillAngle,
    required double fillHhImpulse,
    required double fillTransition,
  }) {
    final double beatX = orbitRadius * cos(orbitAngle) + centerYWander;
    final double beatY = orbitRadius * sin(orbitAngle);
    final double fillX =
        fillCenterY + fillRadius * cos(fillAngle) - fillHhImpulse;
    final double fillY = fillRadius * sin(fillAngle);
    final double blendX =
        beatX * (1.0 - fillTransition) + fillX * fillTransition;
    final double blendY =
        beatY * (1.0 - fillTransition) + fillY * fillTransition;
    final double blendedAngle = atan2(blendY, blendX);
    return (beatX, beatY, blendX, blendY, blendedAngle);
  }

  (double alpha, double beta) computeBeatThreePhasePosition({
    required double blendX,
    required double blendY,
  }) {
    final double fade = silenceFade.clamp(0.1, 1.0);
    final double alpha = (blendX * fade).clamp(-1.0, 1.0);
    final double beta = (blendY * fade).clamp(-1.0, 1.0);
    return (alpha, beta);
  }

  (double e1, double e2, double e3, double e4)
  computeBeatFourPhaseElectrodePowers({
    required double blendedAngle,
    required double base,
    double? blendX,
    double? blendY,
    double radiusAwareContrastStrength = 0.0,
    double speedThresholdSpreadStrength = 0.0,
    List<BeatResponseCurve> responseCurves = defaultBeatFourPhaseResponseCurves,
  }) {
    final double idleLevel = base * 0.15;
    final double orbitWeight = silenceFade;
    final double radiusMagnitude = blendX != null && blendY != null
        ? sqrt(blendX * blendX + blendY * blendY)
        : orbitRadius;
    final double contrastStrength = _resolveBeatFourPhaseContrast(
      radiusMagnitude: radiusMagnitude,
      radiusAwareContrastStrength: radiusAwareContrastStrength,
      speedThresholdSpreadStrength: speedThresholdSpreadStrength,
    );
    final double e1 = _circleElectrodePower(
      blendedAngle,
      0,
      4,
      base,
      idleLevel,
      orbitWeight,
      contrastStrength,
      _resolveBeatResponseCurve(responseCurves, 0),
    );
    final double e2 = _circleElectrodePower(
      blendedAngle,
      1,
      4,
      base,
      idleLevel,
      orbitWeight,
      contrastStrength,
      _resolveBeatResponseCurve(responseCurves, 1),
    );
    final double e3 = _circleElectrodePower(
      blendedAngle,
      2,
      4,
      base,
      idleLevel,
      orbitWeight,
      contrastStrength,
      _resolveBeatResponseCurve(responseCurves, 2),
    );
    final double e4 = _circleElectrodePower(
      blendedAngle,
      3,
      4,
      base,
      idleLevel,
      orbitWeight,
      contrastStrength,
      _resolveBeatResponseCurve(responseCurves, 3),
    );
    return (e1, e2, e3, e4);
  }

  double _circleElectrodePower(
    double orbitAngle,
    int index,
    int total,
    double base,
    double idleLevel,
    double orbitWeight,
    double contrastStrength,
    BeatResponseCurve responseCurve,
  ) {
    final double electrodeAngle = index * (2.0 * pi / total);
    double delta = (orbitAngle - electrodeAngle) % (2.0 * pi);
    if (delta > pi) {
      delta -= 2.0 * pi;
    }
    final double proximity = (cos(delta) + 1.0) * 0.5;
    final double shapedProximity = _applyBeatFourPhaseContrast(
      proximity,
      contrastStrength,
    );
    final double curvedProximity = _applyBeatResponseCurve(
      shapedProximity,
      responseCurve,
    );
    final double orbitPower = (base * curvedProximity).clamp(0.0, 1.0);
    return (orbitPower * orbitWeight + idleLevel * (1.0 - orbitWeight)).clamp(
      0.0,
      1.0,
    );
  }

  BeatResponseCurve _resolveBeatResponseCurve(
    List<BeatResponseCurve> responseCurves,
    int index,
  ) {
    if (index < 0 || index >= responseCurves.length) {
      return BeatResponseCurve.linear;
    }
    return responseCurves[index];
  }

  double _resolveBeatFourPhaseContrast({
    required double radiusMagnitude,
    required double radiusAwareContrastStrength,
    required double speedThresholdSpreadStrength,
  }) {
    final double radiusStrength = radiusAwareContrastStrength.clamp(0.0, 1.0);
    final double speedStrength = speedThresholdSpreadStrength.clamp(0.0, 1.0);
    final double radiusNormalized = (radiusMagnitude / 1.0).clamp(0.0, 1.0);
    const double speedThresholdRadPerSec = 4.0;
    const double speedCeilingRadPerSec = 12.0;
    final double speedActivation =
        ((orbitAngularSpeedRadPerSec - speedThresholdRadPerSec) /
                (speedCeilingRadPerSec - speedThresholdRadPerSec))
            .clamp(0.0, 1.0);
    return (radiusStrength * radiusNormalized + speedStrength * speedActivation)
        .clamp(0.0, 1.0);
  }

  double _applyBeatFourPhaseContrast(
    double proximity,
    double contrastStrength,
  ) {
    final double clampedProximity = proximity.clamp(0.0, 1.0);
    final double clampedContrast = contrastStrength.clamp(0.0, 1.0);
    if (clampedContrast <= 1e-9) {
      return clampedProximity;
    }

    final double power = 1.0 + clampedContrast * 3.0;
    if (clampedProximity <= 0.5) {
      final double normalized = (clampedProximity * 2.0).clamp(0.0, 1.0);
      return 0.5 * pow(normalized, power).toDouble();
    }

    final double normalized = (2.0 * (1.0 - clampedProximity)).clamp(0.0, 1.0);
    return 1.0 - 0.5 * pow(normalized, power).toDouble();
  }

  double _applyBeatResponseCurve(
    double proximity,
    BeatResponseCurve responseCurve,
  ) {
    final double x = proximity.clamp(0.0, 1.0);
    switch (responseCurve) {
      case BeatResponseCurve.linear:
        return x;
      case BeatResponseCurve.ease:
        return pow(x, 1.8).toDouble().clamp(0.0, 1.0);
      case BeatResponseCurve.bell:
        if (x <= 0.5) {
          return 2.0 * x * x;
        }
        final double inv = 1.0 - x;
        return 1.0 - 2.0 * inv * inv;
    }
  }

  (
    double fillDriveFloor,
    double effectiveDrive,
    double buttonHoldRamp,
    double outputDrive,
  )
  prepareOutputDrive({
    required double motionDriveLevel,
    required double fillTransition,
    required bool buttonHoldMuted,
    required double buttonHoldRamp,
    required double dtSec,
    required double buttonResumeRampSec,
  }) {
    final double fillDriveFloor = fillTransition * 0.20 * silenceFade;
    final double effectiveDrive = max(motionDriveLevel, fillDriveFloor);
    final double nextButtonHoldRamp = buttonHoldMuted
        ? 0.0
        : smoothValue(
            previous: buttonHoldRamp,
            target: 1.0,
            dtSec: dtSec,
            attackSec: buttonResumeRampSec,
            releaseSec: buttonResumeRampSec,
          ).clamp(0.0, 1.0);
    final double outputDrive = (effectiveDrive * nextButtonHoldRamp).clamp(
      0.0,
      1.0,
    );
    return (fillDriveFloor, effectiveDrive, nextButtonHoldRamp, outputDrive);
  }

  (double stimulationDrive, double base, double amplitudeAmps)
  prepareStimulationAmplitude({
    required CalibrationPattern calibrationPattern,
    required double buttonHoldRamp,
    required double outputDrive,
    required double intensityCap,
  }) {
    final double stimulationDrive =
        calibrationPattern != CalibrationPattern.none
        ? buttonHoldRamp.clamp(0.0, 1.0)
        : outputDrive;
    final double capFraction = (intensityCap / 100.0).clamp(0.0, 1.0);
    final double base = (capFraction * stimulationDrive).clamp(0.0, 1.0);
    final double amplitudeAmps = (0.12 * capFraction * stimulationDrive).clamp(
      0.0,
      0.12,
    );
    return (stimulationDrive, base, amplitudeAmps);
  }

  (double smoothedDominantBassHz, double effectivePulseHz)
  prepareDynamicPulseFrequency({
    required double smoothedDominantBassHz,
    required double dominantBassHz,
    required double lowBand,
    required double dtSec,
    required bool manualPulseMode,
    required double manualPulseHz,
    required double pulseMinHz,
    required double pulseMaxHz,
    required double bassMonitorLowHz,
    required double bassMonitorHighHz,
  }) {
    final double nextSmoothedDominantBassHz = dominantBassHz > 0.0
        ? smoothValue(
            previous: smoothedDominantBassHz,
            target: dominantBassHz,
            dtSec: dtSec,
            attackSec: 0.08,
            releaseSec: 0.30,
          )
        : smoothValue(
            previous: smoothedDominantBassHz,
            target: 0.0,
            dtSec: dtSec,
            attackSec: 0.5,
            releaseSec: 0.5,
          );

    final double bassEnergy = lowBand.clamp(0.0, 1.0);
    final double trackingWeight = (bassEnergy * 2.5).clamp(0.0, 0.85);

    double effectivePulse;
    if (manualPulseMode) {
      effectivePulse = manualPulseHz;
    } else {
      final double pulseMid = (pulseMinHz + pulseMaxHz) / 2.0;
      if (nextSmoothedDominantBassHz > 10.0 && trackingWeight > 0.05) {
        final double monitorSpan = bassMonitorHighHz - bassMonitorLowHz;
        final double t = monitorSpan > 1.0
            ? ((nextSmoothedDominantBassHz - bassMonitorLowHz) / monitorSpan)
                  .clamp(0.0, 1.0)
            : 0.5;
        final double mappedHz = pulseMinHz + t * (pulseMaxHz - pulseMinHz);
        effectivePulse =
            pulseMid * (1.0 - trackingWeight) + mappedHz * trackingWeight;
      } else {
        effectivePulse = pulseMid;
      }
    }

    final double nextEffectivePulseHz = effectivePulse.clamp(
      pulseMinHz,
      pulseMaxHz,
    );
    return (nextSmoothedDominantBassHz, nextEffectivePulseHz);
  }

  void reset() {
    orbitAngle = 0.0;
    orbitRadius = 0.70;
    estimatedBpm = 120.0;
    silenceFade = 0.0;
    beatWasHigh = false;
    lastBeatEdgeMs = 0;
    beatIntervals.clear();

    triggerKind = TriggerKind.fill;
    beatCountInPhrase = 0;
    energyEma = 0.0;
    energyEmaSlow = 0.0;

    orbitDirection = 1;
    lastDirectionChangeMs = 0;
    wanderPhase = 0.0;
    centerYWander = 0.0;
    energyFullness = 0.0;
    subBassBloom = 0.0;
  }
}
