import 'dart:math';

import '../../models/enums.dart';
import '../processing/audio_signal_processor.dart';

class FourPhaseOnsetOutput {
  const FourPhaseOnsetOutput({
    required this.e1,
    required this.e2,
    required this.e3,
    required this.e4,
    required this.pulseIntervalRandomNormalized,
  });

  final double e1;
  final double e2;
  final double e3;
  final double e4;
  final double pulseIntervalRandomNormalized;
}

class FourPhaseOnsetMapper {
  static const double _spectralWeight = 0.85;
  static const double _fillMixWeight = 0.12;
  static const double _idleFraction = 0.10;
  static const double _maxBrillianceRandomPercent = 50.0;

  const FourPhaseOnsetMapper._();

  static FourPhaseOnsetOutput map({
    required AudioFeatures features,
    required double base,
    required double silenceFade,
    required double fillAngle,
    required double pulseIntervalRandomPercent,
    required double orbitRadius,
    List<List<AudioBand>> bandMapping = defaultOnsetBandMapping,
  }) {
    final List<List<AudioBand>> effectiveBandMapping = bandMapping.length == 4
        ? bandMapping
        : defaultOnsetBandMapping;

    final double rawE1 = _computeRaw(effectiveBandMapping[0], features);
    final double rawE2 = _computeRaw(effectiveBandMapping[1], features);
    final double rawE3 = _computeRaw(effectiveBandMapping[2], features);
    final double rawE4 = _computeRaw(effectiveBandMapping[3], features);

    final double bloomScale = 0.85 + orbitRadius.clamp(0.35, 1.0) * 0.20;
    final double dynamicBase = (base * bloomScale).clamp(0.0, 1.0);
    final double idleLevel = dynamicBase * _idleFraction;
    final double f1 = _fillProximity(fillAngle: fillAngle, phaseIndex: 0);
    final double f2 = _fillProximity(fillAngle: fillAngle, phaseIndex: 1);
    final double f3 = _fillProximity(fillAngle: fillAngle, phaseIndex: 2);
    final double f4 = _fillProximity(fillAngle: fillAngle, phaseIndex: 3);

    final double e1 =
        (dynamicBase *
                    (rawE1 * _spectralWeight + f1 * _fillMixWeight) *
                    silenceFade +
                idleLevel)
            .clamp(0.0, 1.0);
    final double e2 =
        (dynamicBase *
                    (rawE2 * _spectralWeight + f2 * _fillMixWeight) *
                    silenceFade +
                idleLevel)
            .clamp(0.0, 1.0);
    final double e3 =
        (dynamicBase *
                    (rawE3 * _spectralWeight + f3 * _fillMixWeight) *
                    silenceFade +
                idleLevel)
            .clamp(0.0, 1.0);
    final double e4 =
        (dynamicBase *
                    (rawE4 * _spectralWeight + f4 * _fillMixWeight) *
                    silenceFade +
                idleLevel)
            .clamp(0.0, 1.0);

    final double brilliance = features.brilliance.clamp(0.0, 1.0);
    final double dynamicRandom =
        pulseIntervalRandomPercent +
        brilliance * (_maxBrillianceRandomPercent - pulseIntervalRandomPercent);

    return FourPhaseOnsetOutput(
      e1: e1,
      e2: e2,
      e3: e3,
      e4: e4,
      pulseIntervalRandomNormalized: dynamicRandom.clamp(0.0, 100.0) / 100.0,
    );
  }

  static double _computeRaw(List<AudioBand> bands, AudioFeatures features) {
    double sum = 0.0;
    for (final AudioBand band in bands) {
      switch (band) {
        case AudioBand.subBass:
          sum += features.subBass;
        case AudioBand.bass:
          sum += features.bass;
        case AudioBand.lowMid:
          sum += features.lowMid;
        case AudioBand.mid:
          sum += features.mid;
        case AudioBand.upperMid:
          sum += features.upperMid;
        case AudioBand.presence:
          sum += features.presence;
        case AudioBand.brilliance:
          sum += features.brilliance;
      }
    }
    return sum.clamp(0.0, 1.0);
  }

  static double _fillProximity({
    required double fillAngle,
    required int phaseIndex,
  }) {
    return (cos(fillAngle - phaseIndex * pi / 2) + 1.0) * 0.5;
  }
}
