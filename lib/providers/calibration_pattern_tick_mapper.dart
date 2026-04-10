import '../models/device_models.dart';
import '../models/enums.dart';
import 'calibration_controller.dart';

class CalibrationPatternTickOutput {
  const CalibrationPatternTickOutput.fourPhase({
    required this.e1,
    required this.e2,
    required this.e3,
    required this.e4,
  }) : alpha = null,
       beta = null;

  const CalibrationPatternTickOutput.threePhase({
    required this.alpha,
    required this.beta,
  }) : e1 = null,
       e2 = null,
       e3 = null,
       e4 = null;

  final double? e1;
  final double? e2;
  final double? e3;
  final double? e4;
  final double? alpha;
  final double? beta;

  bool get isFourPhase => e1 != null && e2 != null && e3 != null && e4 != null;
}

class CalibrationPatternTickMapper {
  const CalibrationPatternTickMapper();

  CalibrationPatternTickOutput map({
    required CalibrationPattern pattern,
    required CalibrationController controller,
    required OutputModeSelection outputMode,
    required double dtSec,
    double? manualAlpha,
    double? manualBeta,
    double? manualE1,
    double? manualE2,
    double? manualE3,
    double? manualE4,
  }) {
    if (pattern == CalibrationPattern.manual) {
      if (outputMode == OutputModeSelection.fourPhase) {
        return CalibrationPatternTickOutput.fourPhase(
          e1: (manualE1 ?? 0.333).clamp(0.0, 1.0),
          e2: (manualE2 ?? 0.333).clamp(0.0, 1.0),
          e3: (manualE3 ?? 0.333).clamp(0.0, 1.0),
          e4: (manualE4 ?? 0.0).clamp(0.0, 1.0),
        );
      }

      return CalibrationPatternTickOutput.threePhase(
        alpha: (manualAlpha ?? 0.0).clamp(-1.0, 1.0),
        beta: (manualBeta ?? 0.0).clamp(-1.0, 1.0),
      );
    }

    controller.advance(dtSec);

    if (outputMode == OutputModeSelection.fourPhase) {
      final (double e1, double e2, double e3, double e4) = controller
          .fourPhasePowers();
      return CalibrationPatternTickOutput.fourPhase(
        e1: e1,
        e2: e2,
        e3: e3,
        e4: e4,
      );
    }

    final (double alpha, double beta) = controller.threePhasePosition();
    return CalibrationPatternTickOutput.threePhase(alpha: alpha, beta: beta);
  }
}
