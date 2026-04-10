import 'dart:math';

import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BeatMotionEngine updateBeatEdgeAndBpm tracks edges and BPM', () {
    final BeatMotionEngine engine = BeatMotionEngine();

    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.6, nowMs: 1000), isTrue);
    expect(engine.beatWasHigh, isTrue);
    expect(engine.lastBeatEdgeMs, 1000);
    expect(engine.beatIntervals, isEmpty);

    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.1, nowMs: 1100), isFalse);
    expect(engine.beatWasHigh, isFalse);

    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.7, nowMs: 1500), isTrue);
    expect(engine.beatIntervals, hasLength(1));
    expect(engine.estimatedBpm, closeTo(120.0, 1e-9));

    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.1, nowMs: 1600), isFalse);
    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.8, nowMs: 2000), isTrue);
    expect(engine.beatIntervals, hasLength(2));
    expect(engine.estimatedBpm, closeTo(120.0, 1e-9));
  });

  test('BeatMotionEngine updateBeatEdgeAndBpm rejects invalid IBI windows', () {
    final BeatMotionEngine engine = BeatMotionEngine();

    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.7, nowMs: 1000), isTrue);
    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.0, nowMs: 1100), isFalse);

    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.8, nowMs: 1200), isTrue);
    expect(engine.beatIntervals, isEmpty);
    expect(engine.estimatedBpm, closeTo(120.0, 1e-9));

    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.0, nowMs: 1300), isFalse);
    expect(engine.updateBeatEdgeAndBpm(beatValue: 0.8, nowMs: 4000), isTrue);
    expect(engine.beatIntervals, isEmpty);
    expect(engine.estimatedBpm, closeTo(120.0, 1e-9));
  });

  test('BeatMotionEngine updateEnergyState applies fast and slow EMAs', () {
    final BeatMotionEngine engine = BeatMotionEngine();

    engine.updateEnergyState(totalEnergy: 1.0, dtSec: 0.1);

    expect(engine.energyEma, closeTo(1.0 - exp(-0.1 / 0.15), 1e-12));
    expect(engine.energyEmaSlow, closeTo(1.0 - exp(-0.1 / 2.0), 1e-12));
  });

  test('BeatMotionEngine updateSilenceFade ramps in and clamps to one', () {
    final BeatMotionEngine engine = BeatMotionEngine();

    final double half = engine.updateSilenceFade(
      gateOpen: true,
      hasRecentPcm: true,
      dtSec: 0.9,
    );
    expect(half, closeTo(0.5, 1e-12));
    expect(engine.silenceFade, closeTo(0.5, 1e-12));

    final double full = engine.updateSilenceFade(
      gateOpen: true,
      hasRecentPcm: true,
      dtSec: 2.0,
    );
    expect(full, closeTo(1.0, 1e-12));
    expect(engine.silenceFade, closeTo(1.0, 1e-12));
  });

  test('BeatMotionEngine updateSilenceFade ramps out and clamps to zero', () {
    final BeatMotionEngine engine = BeatMotionEngine()..silenceFade = 0.8;

    final double reduced = engine.updateSilenceFade(
      gateOpen: true,
      hasRecentPcm: false,
      dtSec: 0.3,
    );
    expect(reduced, closeTo(0.3, 1e-12));
    expect(engine.silenceFade, closeTo(0.3, 1e-12));

    final double zeroed = engine.updateSilenceFade(
      gateOpen: false,
      hasRecentPcm: true,
      dtSec: 1.0,
    );
    expect(zeroed, closeTo(0.0, 1e-12));
    expect(engine.silenceFade, closeTo(0.0, 1e-12));
  });

  test('BeatMotionEngine updatePhraseFluxEma applies expected smoothing', () {
    final BeatMotionEngine engine = BeatMotionEngine();

    final double updated = engine.updatePhraseFluxEma(
      fluxEmaPhrase: 0.2,
      flux: 0.8,
      dtSec: 0.1,
    );

    final double expected = 0.2 + (0.8 - 0.2) * (1.0 - exp(-0.1 / 0.3));
    expect(updated, closeTo(expected, 1e-12));
  });

  test(
    'BeatMotionEngine classifyTriggerOnBeatEdge follows lock and fallback rules',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      engine.classifyTriggerOnBeatEdge(
        tempoLocked: true,
        isSyncopated: true,
        isDownbeat: false,
        zScoreBeat: false,
        beatValue: 0.9,
      );
      expect(engine.triggerKind, TriggerKind.syncopation);
      expect(engine.beatCountInPhrase, 0);

      engine.classifyTriggerOnBeatEdge(
        tempoLocked: true,
        isSyncopated: false,
        isDownbeat: true,
        zScoreBeat: false,
        beatValue: 0.9,
      );
      expect(engine.triggerKind, TriggerKind.downbeat);
      expect(engine.beatCountInPhrase, 0);

      engine.classifyTriggerOnBeatEdge(
        tempoLocked: false,
        isSyncopated: false,
        isDownbeat: false,
        zScoreBeat: false,
        beatValue: 0.9,
      );
      expect(engine.beatCountInPhrase, 1);
      expect(engine.triggerKind, TriggerKind.beat);

      engine.beatCountInPhrase = 3;
      engine.classifyTriggerOnBeatEdge(
        tempoLocked: false,
        isSyncopated: false,
        isDownbeat: false,
        zScoreBeat: true,
        beatValue: 0.6,
      );
      expect(engine.beatCountInPhrase, 4);
      expect(engine.triggerKind, TriggerKind.downbeat);

      engine.beatCountInPhrase = 1;
      engine.classifyTriggerOnBeatEdge(
        tempoLocked: false,
        isSyncopated: false,
        isDownbeat: false,
        zScoreBeat: true,
        beatValue: 0.6,
      );
      expect(engine.beatCountInPhrase, 2);
      expect(engine.triggerKind, TriggerKind.syncopation);
    },
  );

  test(
    'BeatMotionEngine shouldDemoteToFillForInactivity matches threshold behavior',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      expect(
        engine.shouldDemoteToFillForInactivity(
          stimMode: StimMode.onset,
          lastBeatTriggerMs: 1000,
          nowMs: 5000,
          effectiveBpm: 120.0,
        ),
        isFalse,
      );

      expect(
        engine.shouldDemoteToFillForInactivity(
          stimMode: StimMode.beat,
          lastBeatTriggerMs: 0,
          nowMs: 5000,
          effectiveBpm: 120.0,
        ),
        isFalse,
      );

      expect(
        engine.shouldDemoteToFillForInactivity(
          stimMode: StimMode.beat,
          lastBeatTriggerMs: 1000,
          nowMs: 2100,
          effectiveBpm: 120.0,
        ),
        isFalse,
      );

      expect(
        engine.shouldDemoteToFillForInactivity(
          stimMode: StimMode.beat,
          lastBeatTriggerMs: 1000,
          nowMs: 2101,
          effectiveBpm: 120.0,
        ),
        isTrue,
      );
    },
  );

  test(
    'BeatMotionEngine shouldExpirePhraseForInactivity matches threshold behavior',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      expect(
        engine.shouldExpirePhraseForInactivity(
          phraseCommitted: false,
          lastBeatTriggerMs: 1000,
          nowMs: 5000,
          effectiveBpm: 120.0,
        ),
        isFalse,
      );

      expect(
        engine.shouldExpirePhraseForInactivity(
          phraseCommitted: true,
          lastBeatTriggerMs: 0,
          nowMs: 5000,
          effectiveBpm: 120.0,
        ),
        isFalse,
      );

      expect(
        engine.shouldExpirePhraseForInactivity(
          phraseCommitted: true,
          lastBeatTriggerMs: 1000,
          nowMs: 3000,
          effectiveBpm: 120.0,
        ),
        isFalse,
      );

      expect(
        engine.shouldExpirePhraseForInactivity(
          phraseCommitted: true,
          lastBeatTriggerMs: 1000,
          nowMs: 3001,
          effectiveBpm: 120.0,
        ),
        isTrue,
      );
    },
  );

  test(
    'BeatMotionEngine applyInactivityAndResolveBpm prefers metronome when locked',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..estimatedBpm = 110.0
        ..triggerKind = TriggerKind.beat;

      final (
        double effectiveBpm,
        bool phraseCommitted,
        int phraseBeatCount,
      ) = engine.applyInactivityAndResolveBpm(
        tempoLocked: true,
        metronomeBpm: 128.0,
        stimMode: StimMode.beat,
        lastBeatTriggerMs: 4900,
        nowMs: 5000,
        phraseCommitted: true,
        phraseBeatCount: 3,
      );

      expect(effectiveBpm, closeTo(128.0, 1e-12));
      expect(phraseCommitted, isTrue);
      expect(phraseBeatCount, 3);
      expect(engine.triggerKind, TriggerKind.beat);
    },
  );

  test(
    'BeatMotionEngine applyInactivityAndResolveBpm demotes and expires phrase on inactivity',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..estimatedBpm = 120.0
        ..triggerKind = TriggerKind.downbeat;

      final (
        double effectiveBpm,
        bool phraseCommitted,
        int phraseBeatCount,
      ) = engine.applyInactivityAndResolveBpm(
        tempoLocked: false,
        metronomeBpm: 0.0,
        stimMode: StimMode.beat,
        lastBeatTriggerMs: 1000,
        nowMs: 4001,
        phraseCommitted: true,
        phraseBeatCount: 6,
      );

      expect(effectiveBpm, closeTo(120.0, 1e-12));
      expect(phraseCommitted, isFalse);
      expect(phraseBeatCount, 0);
      expect(engine.triggerKind, TriggerKind.fill);
    },
  );

  test('BeatMotionEngine updateCenterWander updates only in beat mode', () {
    final BeatMotionEngine engine = BeatMotionEngine();

    engine.updateCenterWander(stimMode: StimMode.onset, dtSec: 1.0);
    expect(engine.wanderPhase, 0.0);
    expect(engine.centerYWander, 0.0);

    engine.updateCenterWander(stimMode: StimMode.beat, dtSec: 1.0);
    expect(engine.wanderPhase, closeTo(1.0, 1e-12));

    const double wanderPeriod = 40.0;
    const double phi = 1.618033988749895;
    final double expected =
        0.08 * sin(2.0 * pi * 1.0 / wanderPeriod) +
        0.04 * sin(2.0 * pi * 1.0 / (wanderPeriod * phi)) +
        0.02 * sin(2.0 * pi * 1.0 / (wanderPeriod * phi * phi));
    expect(engine.centerYWander, closeTo(expected, 1e-12));
  });

  test(
    'BeatMotionEngine maybeFlipOrbitDirection respects mode and cooldown',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..energyEma = 1.0
        ..energyEmaSlow = 0.5
        ..orbitDirection = 1
        ..lastDirectionChangeMs = 1000;

      engine.maybeFlipOrbitDirection(stimMode: StimMode.onset, nowMs: 20000);
      expect(engine.orbitDirection, 1);
      expect(engine.lastDirectionChangeMs, 1000);

      engine.maybeFlipOrbitDirection(stimMode: StimMode.beat, nowMs: 16000);
      expect(engine.orbitDirection, 1);
      expect(engine.lastDirectionChangeMs, 1000);

      engine.maybeFlipOrbitDirection(stimMode: StimMode.beat, nowMs: 17001);
      expect(engine.orbitDirection, -1);
      expect(engine.lastDirectionChangeMs, 17001);
    },
  );

  test(
    'BeatMotionEngine evaluateTransientProfile returns bassDominant when bass ratio high and flux active',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final TransientProfile profile = engine.evaluateTransientProfile(
        bassLowHighRatio: 2.1,
        flux: 0.2,
        energyFullness: 0.0,
        tempoLocked: true,
      );

      expect(profile, TransientProfile.bassDominant);
    },
  );

  test(
    'BeatMotionEngine evaluateTransientProfile returns neutral when bass ratio low',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final TransientProfile profile = engine.evaluateTransientProfile(
        bassLowHighRatio: 1.2,
        flux: 0.25,
        energyFullness: 0.0,
        tempoLocked: true,
      );

      expect(profile, TransientProfile.neutral);
    },
  );

  test(
    'BeatMotionEngine evaluateTransientProfile returns noFeatures when not tempo locked',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final TransientProfile profile = engine.evaluateTransientProfile(
        bassLowHighRatio: 3.0,
        flux: 0.6,
        energyFullness: 0.7,
        tempoLocked: false,
      );

      expect(profile, TransientProfile.noFeatures);
    },
  );

  test(
    'BeatMotionEngine updateFullnessBloomAndRadius applies reduced bloom for neutral profile',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      engine.updateFullnessBloomAndRadius(
        totalEnergy: 1.0,
        subBass: 1.0,
        lowBand: 1.0,
        dtSec: 0.1,
        transientProfile: TransientProfile.neutral,
      );

      expect(engine.energyFullness, greaterThan(0.0));
      expect(engine.subBassBloom, greaterThan(0.0));
      expect(engine.orbitRadius, greaterThan(0.70));
      expect(engine.orbitRadius, lessThanOrEqualTo(1.0));

      final double neutralBloom = engine.subBassBloom;

      final BeatMotionEngine dominantEngine = BeatMotionEngine();
      dominantEngine.updateFullnessBloomAndRadius(
        totalEnergy: 1.0,
        subBass: 1.0,
        lowBand: 1.0,
        dtSec: 0.1,
        transientProfile: TransientProfile.bassDominant,
      );

      expect(neutralBloom, closeTo(dominantEngine.subBassBloom * 0.5, 1e-12));

      engine.updateFullnessBloomAndRadius(
        totalEnergy: 0.0,
        subBass: 0.0,
        lowBand: 0.0,
        dtSec: 10.0,
        transientProfile: TransientProfile.neutral,
      );
      expect(engine.orbitRadius, inInclusiveRange(0.35, 1.0));
    },
  );

  test(
    'BeatMotionEngine updateFullnessBloomAndRadius applies full bloom for bassDominant profile',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      engine.updateFullnessBloomAndRadius(
        totalEnergy: 1.0,
        subBass: 1.0,
        lowBand: 1.0,
        dtSec: 0.1,
        transientProfile: TransientProfile.bassDominant,
      );

      final double dominantBloom = engine.subBassBloom;

      final BeatMotionEngine neutralEngine = BeatMotionEngine();
      neutralEngine.updateFullnessBloomAndRadius(
        totalEnergy: 1.0,
        subBass: 1.0,
        lowBand: 1.0,
        dtSec: 0.1,
        transientProfile: TransientProfile.neutral,
      );

      expect(dominantBloom, greaterThan(neutralEngine.subBassBloom));
    },
  );

  test('BeatMotionEngine advanceOrbitAngle updates only in beat mode', () {
    final BeatMotionEngine engine = BeatMotionEngine()..orbitAngle = 1.0;

    engine.advanceOrbitAngle(
      stimMode: StimMode.onset,
      effectiveBpm: 120.0,
      dtSec: 0.1,
      cadenceHint: 4,
      learningEnabled: true,
    );

    expect(engine.orbitAngle, closeTo(1.0, 1e-12));
  });

  test(
    'BeatMotionEngine advanceOrbitAngle follows trigger speed and direction',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..orbitAngle = 1.0
        ..triggerKind = TriggerKind.downbeat
        ..silenceFade = 0.5
        ..orbitDirection = -1;

      engine.advanceOrbitAngle(
        stimMode: StimMode.beat,
        effectiveBpm: 120.0,
        dtSec: 0.1,
        cadenceHint: 1,
        learningEnabled: false,
      );

      final double radiansPerSec = (2.0 * pi * 120.0) / (60.0 * 4.0);
      final double speedScale = 0.04 + (0.5 * 0.96);
      final double expected = 1.0 + (-1 * radiansPerSec * speedScale * 0.1);
      expect(engine.orbitAngle, closeTo(expected, 1e-12));
    },
  );

  test(
    'BeatMotionEngine advanceOrbitAngle uses cadenceHint when learning enabled',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..orbitAngle = 0.0
        ..triggerKind = TriggerKind.downbeat
        ..silenceFade = 1.0
        ..orbitDirection = 1;

      engine.advanceOrbitAngle(
        stimMode: StimMode.beat,
        effectiveBpm: 120.0,
        dtSec: 0.1,
        cadenceHint: 1,
        learningEnabled: true,
      );

      final double expectedRadiansPerSec = (2.0 * pi * 120.0) / (60.0 * 1.0);
      expect(engine.orbitAngle, closeTo(expectedRadiansPerSec * 0.1, 1e-12));
    },
  );

  test(
    'BeatMotionEngine advanceOrbitAngle keeps syncopation cadence at one when learning enabled',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..orbitAngle = 0.0
        ..triggerKind = TriggerKind.syncopation
        ..silenceFade = 1.0
        ..orbitDirection = 1;

      engine.advanceOrbitAngle(
        stimMode: StimMode.beat,
        effectiveBpm: 120.0,
        dtSec: 0.1,
        cadenceHint: 4,
        learningEnabled: true,
      );

      final double expectedRadiansPerSec = (2.0 * pi * 120.0) / (60.0 * 1.0);
      expect(engine.orbitAngle, closeTo(expectedRadiansPerSec * 0.1, 1e-12));
    },
  );

  test(
    'BeatMotionEngine computeBlendedOrbitPosition returns beat position at zero transition',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..orbitRadius = 1.0
        ..orbitAngle = pi / 2
        ..centerYWander = 0.2;

      final (
        double beatX,
        double beatY,
        double blendX,
        double blendY,
        double blendedAngle,
      ) = engine.computeBlendedOrbitPosition(
        fillCenterY: -0.5,
        fillRadius: 0.3,
        fillAngle: 0.2,
        fillHhImpulse: 0.1,
        fillTransition: 0.0,
      );

      expect(beatX, closeTo(0.2, 1e-12));
      expect(beatY, closeTo(1.0, 1e-12));
      expect(blendX, closeTo(beatX, 1e-12));
      expect(blendY, closeTo(beatY, 1e-12));
      expect(blendedAngle, closeTo(atan2(beatY, beatX), 1e-12));
    },
  );

  test(
    'BeatMotionEngine computeBlendedOrbitPosition returns fill position at full transition',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..orbitRadius = 0.4
        ..orbitAngle = 0.0
        ..centerYWander = -0.1;

      final (
        double beatX,
        double beatY,
        double blendX,
        double blendY,
        double blendedAngle,
      ) = engine.computeBlendedOrbitPosition(
        fillCenterY: 0.3,
        fillRadius: 0.5,
        fillAngle: pi / 2,
        fillHhImpulse: 0.1,
        fillTransition: 1.0,
      );

      final double expectedFillX = 0.3 + 0.5 * cos(pi / 2) - 0.1;
      final double expectedFillY = 0.5 * sin(pi / 2);
      expect(beatX, closeTo(0.3, 1e-12));
      expect(beatY, closeTo(0.0, 1e-12));
      expect(blendX, closeTo(expectedFillX, 1e-12));
      expect(blendY, closeTo(expectedFillY, 1e-12));
      expect(blendedAngle, closeTo(atan2(expectedFillY, expectedFillX), 1e-12));
    },
  );

  test(
    'BeatMotionEngine computeBeatThreePhasePosition scales by silence fade',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()..silenceFade = 0.5;

      final (double alpha, double beta) = engine.computeBeatThreePhasePosition(
        blendX: 0.8,
        blendY: -0.8,
      );

      expect(alpha, closeTo(0.4, 1e-12));
      expect(beta, closeTo(-0.4, 1e-12));
    },
  );

  test(
    'BeatMotionEngine computeBeatThreePhasePosition enforces fade floor and clamps',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()..silenceFade = 0.0;

      final (double alpha, double beta) = engine.computeBeatThreePhasePosition(
        blendX: 20.0,
        blendY: -20.0,
      );

      expect(alpha, closeTo(1.0, 1e-12));
      expect(beta, closeTo(-1.0, 1e-12));
    },
  );

  test(
    'BeatMotionEngine computeBeatFourPhaseElectrodePowers falls back to uniform drive when silent',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()..silenceFade = 0.0;

      final (double e1, double e2, double e3, double e4) = engine
          .computeBeatFourPhaseElectrodePowers(blendedAngle: 0.0, base: 0.5);

      expect(e1, closeTo(0.075, 1e-12));
      expect(e2, closeTo(0.075, 1e-12));
      expect(e3, closeTo(0.075, 1e-12));
      expect(e4, closeTo(0.075, 1e-12));
    },
  );

  test(
    'BeatMotionEngine computeBeatFourPhaseElectrodePowers follows raised-cosine orbit at full fade',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()..silenceFade = 1.0;

      final (double e1, double e2, double e3, double e4) = engine
          .computeBeatFourPhaseElectrodePowers(blendedAngle: 0.0, base: 0.8);

      expect(e1, closeTo(0.8, 1e-12));
      expect(e2, closeTo(0.4, 1e-12));
      expect(e3, closeTo(0.0, 1e-12));
      expect(e4, closeTo(0.4, 1e-12));
    },
  );

  test(
    'BeatMotionEngine computeBeatFourPhaseElectrodePowers increases contrast with higher blend radius',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..silenceFade = 1.0
        ..orbitAngularSpeedRadPerSec = 0.0;

      final (double lowE1, double lowE2, double lowE3, double lowE4) = engine
          .computeBeatFourPhaseElectrodePowers(
            blendedAngle: pi / 4,
            base: 0.8,
            blendX: 0.10,
            blendY: 0.10,
            radiusAwareContrastStrength: 1.0,
          );

      final (
        double highE1,
        double highE2,
        double highE3,
        double highE4,
      ) = engine.computeBeatFourPhaseElectrodePowers(
        blendedAngle: pi / 4,
        base: 0.8,
        blendX: 0.95,
        blendY: 0.95,
        radiusAwareContrastStrength: 1.0,
      );

      expect(highE1, greaterThan(lowE1));
      expect(highE2, greaterThan(lowE2));
      expect(highE3, lessThan(lowE3));
      expect(highE4, lessThan(lowE4));
    },
  );

  test(
    'BeatMotionEngine computeBeatFourPhaseElectrodePowers applies speed-threshold spread above threshold',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()..silenceFade = 1.0;

      engine.orbitAngularSpeedRadPerSec = 2.0;
      final (double, double, double, double) slow = engine
          .computeBeatFourPhaseElectrodePowers(
            blendedAngle: pi / 4,
            base: 0.8,
            blendX: 0.7,
            blendY: 0.0,
            speedThresholdSpreadStrength: 1.0,
          );

      engine.orbitAngularSpeedRadPerSec = 10.0;
      final (double, double, double, double) fast = engine
          .computeBeatFourPhaseElectrodePowers(
            blendedAngle: pi / 4,
            base: 0.8,
            blendX: 0.7,
            blendY: 0.0,
            speedThresholdSpreadStrength: 1.0,
          );

      expect(fast.$1, greaterThan(slow.$1));
      expect(fast.$3, lessThan(slow.$3));
    },
  );

  test(
    'BeatMotionEngine computeBeatFourPhaseElectrodePowers applies per-electrode response curves',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()
        ..silenceFade = 1.0
        ..orbitAngularSpeedRadPerSec = 0.0;

      final (
        double linearE1,
        double linearE2,
        double linearE3,
        double linearE4,
      ) = engine.computeBeatFourPhaseElectrodePowers(
        blendedAngle: pi / 6,
        base: 1.0,
        responseCurves: const <BeatResponseCurve>[
          BeatResponseCurve.linear,
          BeatResponseCurve.linear,
          BeatResponseCurve.linear,
          BeatResponseCurve.linear,
        ],
      );

      final (
        double easeE1,
        double easeE2,
        double easeE3,
        double easeE4,
      ) = engine.computeBeatFourPhaseElectrodePowers(
        blendedAngle: pi / 6,
        base: 1.0,
        responseCurves: const <BeatResponseCurve>[
          BeatResponseCurve.ease,
          BeatResponseCurve.ease,
          BeatResponseCurve.ease,
          BeatResponseCurve.ease,
        ],
      );

      final (
        double bellE1,
        double bellE2,
        double bellE3,
        double bellE4,
      ) = engine.computeBeatFourPhaseElectrodePowers(
        blendedAngle: pi / 6,
        base: 1.0,
        responseCurves: const <BeatResponseCurve>[
          BeatResponseCurve.bell,
          BeatResponseCurve.bell,
          BeatResponseCurve.bell,
          BeatResponseCurve.bell,
        ],
      );

      expect(bellE2, greaterThan(linearE2));
      expect(linearE2, greaterThan(easeE2));
      expect(bellE1, greaterThan(linearE1));
      expect(linearE1, greaterThan(easeE1));

      for (final double value in <double>[
        linearE1,
        linearE2,
        linearE3,
        linearE4,
        easeE1,
        easeE2,
        easeE3,
        easeE4,
        bellE1,
        bellE2,
        bellE3,
        bellE4,
      ]) {
        expect(value, inInclusiveRange(0.0, 1.0));
      }
    },
  );

  test(
    'BeatMotionEngine prepareOutputDrive mutes output when button hold is active',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()..silenceFade = 0.8;

      final (
        double fillDriveFloor,
        double effectiveDrive,
        double buttonHoldRamp,
        double outputDrive,
      ) = engine.prepareOutputDrive(
        motionDriveLevel: 0.3,
        fillTransition: 0.5,
        buttonHoldMuted: true,
        buttonHoldRamp: 1.0,
        dtSec: 0.1,
        buttonResumeRampSec: 1.8,
      );

      expect(fillDriveFloor, closeTo(0.5 * 0.20 * 0.8, 1e-12));
      expect(effectiveDrive, closeTo(0.3, 1e-12));
      expect(buttonHoldRamp, 0.0);
      expect(outputDrive, 0.0);
    },
  );

  test(
    'BeatMotionEngine prepareOutputDrive applies floor and smoothing when unmuted',
    () {
      final BeatMotionEngine engine = BeatMotionEngine()..silenceFade = 0.5;

      final (
        double fillDriveFloor,
        double effectiveDrive,
        double buttonHoldRamp,
        double outputDrive,
      ) = engine.prepareOutputDrive(
        motionDriveLevel: 0.05,
        fillTransition: 0.8,
        buttonHoldMuted: false,
        buttonHoldRamp: 0.2,
        dtSec: 0.1,
        buttonResumeRampSec: 1.8,
      );

      final double expectedFloor = 0.8 * 0.20 * 0.5;
      final double expectedRamp = (0.2 + (1.0 - exp(-0.1 / 1.8)) * (1.0 - 0.2))
          .clamp(0.0, 1.0);
      expect(fillDriveFloor, closeTo(expectedFloor, 1e-12));
      expect(effectiveDrive, closeTo(expectedFloor, 1e-12));
      expect(buttonHoldRamp, closeTo(expectedRamp, 1e-12));
      expect(outputDrive, closeTo(expectedFloor * expectedRamp, 1e-12));
    },
  );

  test(
    'BeatMotionEngine prepareStimulationAmplitude uses button ramp during calibration',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final (
        double stimulationDrive,
        double base,
        double amplitudeAmps,
      ) = engine.prepareStimulationAmplitude(
        calibrationPattern: CalibrationPattern.circle,
        buttonHoldRamp: 1.2,
        outputDrive: 0.2,
        intensityCap: 80.0,
      );

      expect(stimulationDrive, closeTo(1.0, 1e-12));
      expect(base, closeTo(0.8, 1e-12));
      expect(amplitudeAmps, closeTo(0.096, 1e-12));
    },
  );

  test(
    'BeatMotionEngine prepareStimulationAmplitude uses output drive and clamps outputs',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final (
        double stimulationDrive,
        double base,
        double amplitudeAmps,
      ) = engine.prepareStimulationAmplitude(
        calibrationPattern: CalibrationPattern.none,
        buttonHoldRamp: 0.2,
        outputDrive: 1.5,
        intensityCap: 200.0,
      );

      expect(stimulationDrive, closeTo(1.5, 1e-12));
      expect(base, closeTo(1.0, 1e-12));
      expect(amplitudeAmps, closeTo(0.12, 1e-12));
    },
  );

  test('BeatMotionEngine prepareDynamicPulseFrequency honors manual mode', () {
    final BeatMotionEngine engine = BeatMotionEngine();

    final (double smoothedDominantBassHz, double effectivePulseHz) = engine
        .prepareDynamicPulseFrequency(
          smoothedDominantBassHz: 0.0,
          dominantBassHz: 80.0,
          lowBand: 1.0,
          dtSec: 0.08,
          manualPulseMode: true,
          manualPulseHz: 120.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 100.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
        );

    final double expectedSmoothed = (1.0 - exp(-0.08 / 0.08)) * (80.0 - 0.0);
    expect(smoothedDominantBassHz, closeTo(expectedSmoothed, 1e-12));
    expect(effectivePulseHz, closeTo(100.0, 1e-12));
  });

  test(
    'BeatMotionEngine prepareDynamicPulseFrequency maps dominant bass in auto mode',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final (double smoothedDominantBassHz, double effectivePulseHz) = engine
          .prepareDynamicPulseFrequency(
            smoothedDominantBassHz: 100.0,
            dominantBassHz: 100.0,
            lowBand: 0.4,
            dtSec: 0.1,
            manualPulseMode: false,
            manualPulseHz: 33.0,
            pulseMinHz: 10.0,
            pulseMaxHz: 50.0,
            bassMonitorLowHz: 20.0,
            bassMonitorHighHz: 220.0,
          );

      expect(smoothedDominantBassHz, closeTo(100.0, 1e-12));
      expect(effectivePulseHz, closeTo(26.6, 1e-12));
    },
  );

  test(
    'BeatMotionEngine prepareDynamicPulseFrequency falls back to mid pulse when tracking unavailable',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final (double smoothedDominantBassHz, double effectivePulseHz) = engine
          .prepareDynamicPulseFrequency(
            smoothedDominantBassHz: 20.0,
            dominantBassHz: 0.0,
            lowBand: 1.0,
            dtSec: 1.0,
            manualPulseMode: false,
            manualPulseHz: 33.0,
            pulseMinHz: 10.0,
            pulseMaxHz: 50.0,
            bassMonitorLowHz: 20.0,
            bassMonitorHighHz: 220.0,
          );

      final double expectedSmoothed =
          20.0 + (1.0 - exp(-1.0 / 0.5)) * (0.0 - 20.0);
      expect(smoothedDominantBassHz, closeTo(expectedSmoothed, 1e-12));
      expect(smoothedDominantBassHz, lessThan(10.0));
      expect(effectivePulseHz, closeTo(30.0, 1e-12));
    },
  );

  test(
    'BeatMotionEngine updatePhraseCommitmentOnBeat does not commit when not transitioning from fill',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final (
        bool phraseCommitted,
        int phraseBeatCount,
        double phraseFluxAtStart,
      ) = engine.updatePhraseCommitmentOnBeat(
        phraseCommitted: false,
        phraseBeatCount: 0,
        phraseFluxAtStart: 0.0,
        fluxEmaPhrase: 0.8,
        wasInFill: false,
      );

      expect(phraseCommitted, isFalse);
      expect(phraseBeatCount, 1);
      expect(phraseFluxAtStart, closeTo(0.8, 1e-12));
    },
  );

  test(
    'BeatMotionEngine updatePhraseCommitmentOnBeat commits on first beat after fill',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final (
        bool phraseCommitted,
        int phraseBeatCount,
        double phraseFluxAtStart,
      ) = engine.updatePhraseCommitmentOnBeat(
        phraseCommitted: false,
        phraseBeatCount: 0,
        phraseFluxAtStart: 0.0,
        fluxEmaPhrase: 0.8,
        wasInFill: true,
      );

      expect(phraseCommitted, isTrue);
      expect(phraseBeatCount, 1);
      expect(phraseFluxAtStart, closeTo(0.8, 1e-12));
    },
  );

  test(
    'BeatMotionEngine updatePhraseCommitmentOnBeat follows drop and renewal rules',
    () {
      final BeatMotionEngine engine = BeatMotionEngine();

      final (
        bool commitAfterFluxDrop,
        int countAfterFluxDrop,
        double fluxStartAfterFluxDrop,
      ) = engine.updatePhraseCommitmentOnBeat(
        phraseCommitted: true,
        phraseBeatCount: 2,
        phraseFluxAtStart: 1.0,
        fluxEmaPhrase: 0.34,
        wasInFill: false,
      );
      expect(commitAfterFluxDrop, isFalse);
      expect(countAfterFluxDrop, 0);
      expect(fluxStartAfterFluxDrop, closeTo(1.0, 1e-12));

      final (
        bool commitAfterRenew,
        int countAfterRenew,
        double fluxStartAfterRenew,
      ) = engine.updatePhraseCommitmentOnBeat(
        phraseCommitted: true,
        phraseBeatCount: 7,
        phraseFluxAtStart: 1.0,
        fluxEmaPhrase: 0.56,
        wasInFill: false,
      );
      expect(commitAfterRenew, isTrue);
      expect(countAfterRenew, 0);
      expect(fluxStartAfterRenew, closeTo(1.0, 1e-12));

      final (
        bool commitAfterExpire,
        int countAfterExpire,
        double fluxStartAfterExpire,
      ) = engine.updatePhraseCommitmentOnBeat(
        phraseCommitted: true,
        phraseBeatCount: 7,
        phraseFluxAtStart: 1.0,
        fluxEmaPhrase: 0.55,
        wasInFill: false,
      );
      expect(commitAfterExpire, isFalse);
      expect(countAfterExpire, 0);
      expect(fluxStartAfterExpire, closeTo(1.0, 1e-12));
    },
  );

  test('BeatMotionEngine reset restores defaults', () {
    final BeatMotionEngine engine = BeatMotionEngine()
      ..orbitAngle = 2.5
      ..orbitRadius = 0.91
      ..estimatedBpm = 178.0
      ..silenceFade = 0.77
      ..beatWasHigh = true
      ..lastBeatEdgeMs = 1234
      ..beatIntervals.addAll(<double>[0.4, 0.5])
      ..triggerKind = TriggerKind.downbeat
      ..beatCountInPhrase = 5
      ..energyEma = 0.6
      ..energyEmaSlow = 0.3
      ..orbitDirection = -1
      ..lastDirectionChangeMs = 4567
      ..wanderPhase = 10.0
      ..centerYWander = 0.25
      ..energyFullness = 0.9
      ..subBassBloom = 0.2;

    engine.reset();

    expect(engine.orbitAngle, 0.0);
    expect(engine.orbitRadius, 0.70);
    expect(engine.estimatedBpm, 120.0);
    expect(engine.silenceFade, 0.0);
    expect(engine.beatWasHigh, isFalse);
    expect(engine.lastBeatEdgeMs, 0);
    expect(engine.beatIntervals, isEmpty);
    expect(engine.triggerKind, TriggerKind.fill);
    expect(engine.beatCountInPhrase, 0);
    expect(engine.energyEma, 0.0);
    expect(engine.energyEmaSlow, 0.0);
    expect(engine.orbitDirection, 1);
    expect(engine.lastDirectionChangeMs, 0);
    expect(engine.wanderPhase, 0.0);
    expect(engine.centerYWander, 0.0);
    expect(engine.energyFullness, 0.0);
    expect(engine.subBassBloom, 0.0);
  });
}
