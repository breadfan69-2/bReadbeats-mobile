import 'dart:math';

import 'package:breadbeats_mobile/audio/motion/four_phase_onset_mapper.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

AudioFeatures _features({
  double subBass = 0.0,
  double bass = 0.0,
  double lowMid = 0.0,
  double mid = 0.0,
  double upperMid = 0.0,
  double presence = 0.0,
  double brilliance = 0.0,
}) {
  return AudioFeatures(
    mono: 0.0,
    left: 0.0,
    right: 0.0,
    subBass: subBass,
    bass: bass,
    lowMid: lowMid,
    mid: mid,
    upperMid: upperMid,
    presence: presence,
    brilliance: brilliance,
    dominantBassHz: 0.0,
    dominantFullHz: 0.0,
    flux: 0.0,
    onset: 0.0,
    beat: 0.0,
    zScoreBeat: false,
    zScoreMid: false,
    zScoreHigh: false,
    fluxDropActive: false,
    spectrumFillRatio: 0.0,
    metronomeBpm: 0.0,
    metronomeConfidence: 0.0,
    metronomePhase: 0.0,
    metronomeBeatTick: false,
    isDownbeat: false,
    isSyncopated: false,
    rms: 0.0,
    db: -120.0,
    gateOpen: false,
    energyFullness: 0.0,
  );
}

void main() {
  test('silenceFade zero keeps idle floor for all electrodes', () {
    final FourPhaseOnsetOutput output = FourPhaseOnsetMapper.map(
      features: _features(
        subBass: 1.0,
        bass: 1.0,
        lowMid: 1.0,
        mid: 1.0,
        upperMid: 1.0,
        presence: 1.0,
      ),
      base: 0.4,
      silenceFade: 0.0,
      fillAngle: 0.0,
      pulseIntervalRandomPercent: 35.0,
      orbitRadius: 0.7,
    );

    const double expectedIdle = 0.4 * (0.85 + 0.7 * 0.20) * 0.10;
    expect(output.e1, closeTo(expectedIdle, 1e-12));
    expect(output.e2, closeTo(expectedIdle, 1e-12));
    expect(output.e3, closeTo(expectedIdle, 1e-12));
    expect(output.e4, closeTo(expectedIdle, 1e-12));
  });

  test('default mapping matches prior hardcoded onset formulas', () {
    final AudioFeatures features = _features(
      subBass: 0.25,
      bass: 0.15,
      lowMid: 0.35,
      mid: 0.45,
      upperMid: 0.30,
      presence: 0.20,
      brilliance: 0.10,
    );

    const double base = 0.52;
    const double silenceFade = 0.73;
    const double fillAngle = 0.9;
    const double pulseIntervalRandomPercent = 12.0;
    const double orbitRadius = 0.62;

    final FourPhaseOnsetOutput output = FourPhaseOnsetMapper.map(
      features: features,
      base: base,
      silenceFade: silenceFade,
      fillAngle: fillAngle,
      pulseIntervalRandomPercent: pulseIntervalRandomPercent,
      orbitRadius: orbitRadius,
    );

    const double spectralWeight = 0.85;
    const double fillMixWeight = 0.12;
    const double idleFraction = 0.10;

    final double rawE1 = (features.mid + features.upperMid + features.presence)
        .clamp(0.0, 1.0);
    final double rawE2 = (features.lowMid + features.mid).clamp(0.0, 1.0);
    final double rawE3 = (features.bass + features.lowMid).clamp(0.0, 1.0);
    final double rawE4 = (features.subBass + features.bass).clamp(0.0, 1.0);

    final double bloomScale = 0.85 + orbitRadius.clamp(0.35, 1.0) * 0.20;
    final double dynamicBase = (base * bloomScale).clamp(0.0, 1.0);
    final double idleLevel = dynamicBase * idleFraction;

    final double f1 = (cos(fillAngle - 0 * pi / 2) + 1.0) * 0.5;
    final double f2 = (cos(fillAngle - 1 * pi / 2) + 1.0) * 0.5;
    final double f3 = (cos(fillAngle - 2 * pi / 2) + 1.0) * 0.5;
    final double f4 = (cos(fillAngle - 3 * pi / 2) + 1.0) * 0.5;

    final double expectedE1 =
        (dynamicBase *
                    (rawE1 * spectralWeight + f1 * fillMixWeight) *
                    silenceFade +
                idleLevel)
            .clamp(0.0, 1.0);
    final double expectedE2 =
        (dynamicBase *
                    (rawE2 * spectralWeight + f2 * fillMixWeight) *
                    silenceFade +
                idleLevel)
            .clamp(0.0, 1.0);
    final double expectedE3 =
        (dynamicBase *
                    (rawE3 * spectralWeight + f3 * fillMixWeight) *
                    silenceFade +
                idleLevel)
            .clamp(0.0, 1.0);
    final double expectedE4 =
        (dynamicBase *
                    (rawE4 * spectralWeight + f4 * fillMixWeight) *
                    silenceFade +
                idleLevel)
            .clamp(0.0, 1.0);

    expect(output.e1, closeTo(expectedE1, 1e-12));
    expect(output.e2, closeTo(expectedE2, 1e-12));
    expect(output.e3, closeTo(expectedE3, 1e-12));
    expect(output.e4, closeTo(expectedE4, 1e-12));
  });

  test('custom single-band mapping routes selected band to electrode', () {
    final AudioFeatures features = _features(
      subBass: 0.90,
      bass: 0.20,
      lowMid: 0.30,
      mid: 0.80,
      upperMid: 0.15,
      presence: 0.10,
      brilliance: 0.0,
    );

    const double base = 0.55;
    const double silenceFade = 1.0;
    const double fillAngle = 0.0;
    const double pulseIntervalRandomPercent = 20.0;
    const double orbitRadius = 0.7;

    final FourPhaseOnsetOutput defaultOutput = FourPhaseOnsetMapper.map(
      features: features,
      base: base,
      silenceFade: silenceFade,
      fillAngle: fillAngle,
      pulseIntervalRandomPercent: pulseIntervalRandomPercent,
      orbitRadius: orbitRadius,
    );

    final FourPhaseOnsetOutput customOutput = FourPhaseOnsetMapper.map(
      features: features,
      base: base,
      silenceFade: silenceFade,
      fillAngle: fillAngle,
      pulseIntervalRandomPercent: pulseIntervalRandomPercent,
      orbitRadius: orbitRadius,
      bandMapping: const <List<AudioBand>>[
        <AudioBand>[AudioBand.bass],
        <AudioBand>[AudioBand.lowMid],
        <AudioBand>[AudioBand.mid],
        <AudioBand>[AudioBand.subBass],
      ],
    );

    expect(customOutput.e1, lessThan(defaultOutput.e1));
    expect(customOutput.e3, greaterThan(defaultOutput.e3));
    expect(customOutput.e4, lessThan(defaultOutput.e4));
  });

  test('brilliance steers randomization toward 50 percent', () {
    final FourPhaseOnsetOutput lowBrilliance = FourPhaseOnsetMapper.map(
      features: _features(brilliance: 0.0),
      base: 0.2,
      silenceFade: 1.0,
      fillAngle: 0.0,
      pulseIntervalRandomPercent: 30.0,
      orbitRadius: 0.7,
    );
    final FourPhaseOnsetOutput highBrilliance = FourPhaseOnsetMapper.map(
      features: _features(brilliance: 1.0),
      base: 0.2,
      silenceFade: 1.0,
      fillAngle: 0.0,
      pulseIntervalRandomPercent: 30.0,
      orbitRadius: 0.7,
    );

    expect(lowBrilliance.pulseIntervalRandomNormalized, closeTo(0.30, 1e-12));
    expect(highBrilliance.pulseIntervalRandomNormalized, closeTo(0.50, 1e-12));
  });

  test('fill-angle proximity influences electrode ordering', () {
    final FourPhaseOnsetOutput output = FourPhaseOnsetMapper.map(
      features: _features(),
      base: 1.0,
      silenceFade: 1.0,
      fillAngle: 0.0,
      pulseIntervalRandomPercent: 0.0,
      orbitRadius: 0.7,
    );

    expect(output.e1, greaterThan(output.e2));
    expect(output.e2, closeTo(output.e4, 1e-12));
    expect(output.e4, greaterThan(output.e3));
    expect(output.e1, inInclusiveRange(0.0, 1.0));
    expect(output.e2, inInclusiveRange(0.0, 1.0));
    expect(output.e3, inInclusiveRange(0.0, 1.0));
    expect(output.e4, inInclusiveRange(0.0, 1.0));
  });

  test('orbitRadius increases onset four-phase intensity envelope', () {
    final AudioFeatures features = _features(
      subBass: 0.7,
      bass: 0.8,
      lowMid: 0.6,
      mid: 0.5,
      upperMid: 0.4,
      presence: 0.3,
    );

    final FourPhaseOnsetOutput lowOrbit = FourPhaseOnsetMapper.map(
      features: features,
      base: 0.35,
      silenceFade: 1.0,
      fillAngle: 0.0,
      pulseIntervalRandomPercent: 20.0,
      orbitRadius: 0.35,
    );
    final FourPhaseOnsetOutput highOrbit = FourPhaseOnsetMapper.map(
      features: features,
      base: 0.35,
      silenceFade: 1.0,
      fillAngle: 0.0,
      pulseIntervalRandomPercent: 20.0,
      orbitRadius: 1.0,
    );

    expect(highOrbit.e1, greaterThan(lowOrbit.e1));
    expect(highOrbit.e2, greaterThan(lowOrbit.e2));
    expect(highOrbit.e3, greaterThan(lowOrbit.e3));
    expect(highOrbit.e4, greaterThan(lowOrbit.e4));
  });
}
