import '../../models/enums.dart';
import '../processing/audio_signal_processor.dart';
import 'beat_motion_engine.dart';
import 'four_phase_onset_mapper.dart';

class FourPhaseElectrodeOutput {
  const FourPhaseElectrodeOutput({
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
  final double? pulseIntervalRandomNormalized;
}

class FourPhaseElectrodeMapper {
  const FourPhaseElectrodeMapper();

  FourPhaseElectrodeOutput map({
    required StimMode stimMode,
    required BeatMotionEngine beatMotion,
    required AudioFeatures features,
    required double blendedAngle,
    required double blendX,
    required double blendY,
    required double base,
    required double silenceFade,
    required double fillAngle,
    required double pulseIntervalRandomPercent,
    required double beatRadiusAwareContrastStrength,
    required double beatSpeedThresholdSpreadStrength,
    required List<BeatResponseCurve> beatResponseCurves,
    List<List<AudioBand>> bandMapping = defaultOnsetBandMapping,
  }) {
    if (stimMode == StimMode.beat) {
      final (double e1, double e2, double e3, double e4) = beatMotion
          .computeBeatFourPhaseElectrodePowers(
            blendedAngle: blendedAngle,
            base: base,
            blendX: blendX,
            blendY: blendY,
            radiusAwareContrastStrength: beatRadiusAwareContrastStrength,
            speedThresholdSpreadStrength: beatSpeedThresholdSpreadStrength,
            responseCurves: beatResponseCurves,
          );
      return FourPhaseElectrodeOutput(
        e1: e1,
        e2: e2,
        e3: e3,
        e4: e4,
        pulseIntervalRandomNormalized: null,
      );
    }

    final FourPhaseOnsetOutput onsetOutput = FourPhaseOnsetMapper.map(
      features: features,
      base: base,
      silenceFade: silenceFade,
      fillAngle: fillAngle,
      pulseIntervalRandomPercent: pulseIntervalRandomPercent,
      orbitRadius: beatMotion.orbitRadius,
      bandMapping: bandMapping,
    );

    return FourPhaseElectrodeOutput(
      e1: onsetOutput.e1,
      e2: onsetOutput.e2,
      e3: onsetOutput.e3,
      e4: onsetOutput.e4,
      pulseIntervalRandomNormalized: onsetOutput.pulseIntervalRandomNormalized,
    );
  }
}
