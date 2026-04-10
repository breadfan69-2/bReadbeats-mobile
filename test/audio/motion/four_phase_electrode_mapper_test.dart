import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/four_phase_electrode_mapper.dart';
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
  const FourPhaseElectrodeMapper mapper = FourPhaseElectrodeMapper();

  test('beat mode mirrors BeatMotionEngine four-phase powers', () {
    final BeatMotionEngine beatMotion = BeatMotionEngine()
      ..silenceFade = 0.75
      ..orbitAngularSpeedRadPerSec = 9.5;

    const double blendX = 0.42;
    const double blendY = -0.31;
    const double radiusStrength = 0.6;
    const double speedStrength = 0.4;
    const List<BeatResponseCurve> beatCurves = <BeatResponseCurve>[
      BeatResponseCurve.linear,
      BeatResponseCurve.ease,
      BeatResponseCurve.bell,
      BeatResponseCurve.linear,
    ];

    final (
      double expectedE1,
      double expectedE2,
      double expectedE3,
      double expectedE4,
    ) = beatMotion.computeBeatFourPhaseElectrodePowers(
      blendedAngle: 1.2,
      base: 0.65,
      blendX: blendX,
      blendY: blendY,
      radiusAwareContrastStrength: radiusStrength,
      speedThresholdSpreadStrength: speedStrength,
      responseCurves: beatCurves,
    );

    final FourPhaseElectrodeOutput output = mapper.map(
      stimMode: StimMode.beat,
      beatMotion: beatMotion,
      features: AudioFeatures.zero,
      blendedAngle: 1.2,
      blendX: blendX,
      blendY: blendY,
      base: 0.65,
      silenceFade: 0.9,
      fillAngle: 0.0,
      pulseIntervalRandomPercent: 40.0,
      beatRadiusAwareContrastStrength: radiusStrength,
      beatSpeedThresholdSpreadStrength: speedStrength,
      beatResponseCurves: beatCurves,
    );

    expect(output.e1, closeTo(expectedE1, 1e-12));
    expect(output.e2, closeTo(expectedE2, 1e-12));
    expect(output.e3, closeTo(expectedE3, 1e-12));
    expect(output.e4, closeTo(expectedE4, 1e-12));
    expect(output.pulseIntervalRandomNormalized, isNull);
  });

  test('onset mode mirrors FourPhaseOnsetMapper output', () {
    final BeatMotionEngine beatMotion = BeatMotionEngine();
    final AudioFeatures features = _features(
      subBass: 0.7,
      bass: 0.8,
      lowMid: 0.6,
      mid: 0.5,
      upperMid: 0.4,
      presence: 0.3,
      brilliance: 0.25,
    );

    final FourPhaseOnsetOutput expected = FourPhaseOnsetMapper.map(
      features: features,
      base: 0.42,
      silenceFade: 0.88,
      fillAngle: 0.35,
      pulseIntervalRandomPercent: 18.0,
      orbitRadius: beatMotion.orbitRadius,
    );

    final FourPhaseElectrodeOutput output = mapper.map(
      stimMode: StimMode.onset,
      beatMotion: beatMotion,
      features: features,
      blendedAngle: 0.0,
      blendX: 0.0,
      blendY: 0.0,
      base: 0.42,
      silenceFade: 0.88,
      fillAngle: 0.35,
      pulseIntervalRandomPercent: 18.0,
      beatRadiusAwareContrastStrength: 0.0,
      beatSpeedThresholdSpreadStrength: 0.0,
      beatResponseCurves: defaultBeatFourPhaseResponseCurves,
    );

    expect(output.e1, closeTo(expected.e1, 1e-12));
    expect(output.e2, closeTo(expected.e2, 1e-12));
    expect(output.e3, closeTo(expected.e3, 1e-12));
    expect(output.e4, closeTo(expected.e4, 1e-12));
    expect(
      output.pulseIntervalRandomNormalized,
      closeTo(expected.pulseIntervalRandomNormalized, 1e-12),
    );
  });
}
