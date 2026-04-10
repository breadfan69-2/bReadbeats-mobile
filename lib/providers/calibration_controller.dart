import 'dart:math';

import '../models/enums.dart';

class CalibrationController {
  CalibrationPattern _pattern = CalibrationPattern.none;
  double _patternSpeedRps = 0.5;
  double _angle = 0.0;

  CalibrationPattern get pattern => _pattern;
  double get patternSpeedRps => _patternSpeedRps;

  void setPattern(CalibrationPattern pattern) {
    _pattern = pattern;
  }

  bool get isActive => _pattern != CalibrationPattern.none;

  void resetAngle() {
    _angle = 0.0;
  }

  void setPatternSpeed(double rps) {
    _patternSpeedRps = rps.clamp(0.05, 5.0);
  }

  void advance(double dtSec) {
    if (!isActive || _pattern == CalibrationPattern.manual) {
      return;
    }

    final double direction =
        (_pattern == CalibrationPattern.circleReverse ||
            _pattern == CalibrationPattern.sequential4321)
        ? -1.0
        : 1.0;

    _angle += direction * 2.0 * pi * _patternSpeedRps * dtSec;
    _angle %= 2.0 * pi;
    if (_angle < 0.0) {
      _angle += 2.0 * pi;
    }
  }

  (double e1, double e2, double e3, double e4) fourPhasePowers() {
    final double e1 = (cos(_angle - 0 * pi / 2) + 1.0) * 0.5;
    final double e2 = (cos(_angle - 1 * pi / 2) + 1.0) * 0.5;
    final double e3 = (cos(_angle - 2 * pi / 2) + 1.0) * 0.5;
    final double e4 = (cos(_angle - 3 * pi / 2) + 1.0) * 0.5;
    return (e1, e2, e3, e4);
  }

  (double alpha, double beta) threePhasePosition() {
    final double alpha = cos(_angle);
    final double beta = sin(_angle);
    return (alpha, beta);
  }
}
