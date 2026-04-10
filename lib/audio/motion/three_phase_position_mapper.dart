import '../../models/enums.dart';
import 'beat_motion_engine.dart';
import 'onset_motion_engine.dart';

class ThreePhasePositionMapper {
  const ThreePhasePositionMapper();

  (double alpha, double beta) map({
    required StimMode stimMode,
    required BeatMotionEngine beatMotion,
    required OnsetMotionEngine onsetMotion,
    required double blendX,
    required double blendY,
    required double fillCenterY,
    required double fillRadius,
    required double fillAngle,
    required double fillHhImpulse,
    required double silenceFade,
  }) {
    if (stimMode == StimMode.beat) {
      return beatMotion.computeBeatThreePhasePosition(
        blendX: blendX,
        blendY: blendY,
      );
    }

    return onsetMotion.computeThreePhasePosition(
      fillCenterY: fillCenterY,
      fillRadius: fillRadius,
      fillAngle: fillAngle,
      fillHhImpulse: fillHhImpulse,
      silenceFade: silenceFade,
      orbitRadius: beatMotion.orbitRadius,
    );
  }
}
