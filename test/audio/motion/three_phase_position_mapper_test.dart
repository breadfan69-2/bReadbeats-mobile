import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/onset_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/three_phase_position_mapper.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ThreePhasePositionMapper mapper = ThreePhasePositionMapper();

  test('uses beat engine output in beat mode', () {
    final BeatMotionEngine beatMotion = BeatMotionEngine()..silenceFade = 1.0;
    final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

    final (double expectedAlpha, double expectedBeta) = beatMotion
        .computeBeatThreePhasePosition(blendX: 0.8, blendY: -0.4);

    final (double alpha, double beta) = mapper.map(
      stimMode: StimMode.beat,
      beatMotion: beatMotion,
      onsetMotion: onsetMotion,
      blendX: 0.8,
      blendY: -0.4,
      fillCenterY: 0.1,
      fillRadius: 0.2,
      fillAngle: 0.0,
      fillHhImpulse: 0.0,
      silenceFade: 0.7,
    );

    expect(alpha, closeTo(expectedAlpha, 1e-12));
    expect(beta, closeTo(expectedBeta, 1e-12));
  });

  test('uses onset engine output in onset mode', () {
    final BeatMotionEngine beatMotion = BeatMotionEngine();
    final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

    final (double expectedAlpha, double expectedBeta) = onsetMotion
        .computeThreePhasePosition(
          fillCenterY: 0.2,
          fillRadius: 0.15,
          fillAngle: 0.6,
          fillHhImpulse: 0.03,
          silenceFade: 0.8,
          orbitRadius: beatMotion.orbitRadius,
        );

    final (double alpha, double beta) = mapper.map(
      stimMode: StimMode.onset,
      beatMotion: beatMotion,
      onsetMotion: onsetMotion,
      blendX: -0.3,
      blendY: 0.7,
      fillCenterY: 0.2,
      fillRadius: 0.15,
      fillAngle: 0.6,
      fillHhImpulse: 0.03,
      silenceFade: 0.8,
    );

    expect(alpha, closeTo(expectedAlpha, 1e-12));
    expect(beta, closeTo(expectedBeta, 1e-12));
  });
}
