import 'dart:math';

import 'electrode_math.dart';

class ElectrodeStateController {
  double _electrode1Level = 0.0;
  double _electrode2Level = 0.0;
  double _electrode3Level = 0.0;
  double _electrode4Level = 0.0;

  double _positionAlpha = 0.0;
  double _positionBeta = 0.0;
  double _positionGamma = 0.0;

  List<double> _threePhaseElectrodeLevels = const <double>[0.0, 0.0, 0.0];
  List<double> _fourPhaseElectrodeLevels = const <double>[0.0, 0.0, 0.0, 0.0];

  double get electrode1Level => _electrode1Level;
  double get electrode2Level => _electrode2Level;
  double get electrode3Level => _electrode3Level;
  double get electrode4Level => _electrode4Level;

  double get positionAlpha => _positionAlpha;
  double get positionBeta => _positionBeta;
  double get positionGamma => _positionGamma;

  List<double> get threePhaseElectrodeLevels => _threePhaseElectrodeLevels;
  List<double> get fourPhaseElectrodeLevels => _fourPhaseElectrodeLevels;

  void updateFourPhaseLevels({
    required double e1,
    required double e2,
    required double e3,
    required double e4,
  }) {
    final double total = e1 + e2 + e3 + e4;
    if (total > 1e-9) {
      const double c2 = 0.9428090415820634; // sqrt(8)/3
      const double c3 = 0.8164965809277261; // sqrt(2/3)
      _positionAlpha =
          (e1 * 1.0 +
              e2 * (-1.0 / 3.0) +
              e3 * (-1.0 / 3.0) +
              e4 * (-1.0 / 3.0)) /
          total;
      _positionBeta = (e2 * c2 + e3 * (-c2 / 2.0) + e4 * (-c2 / 2.0)) / total;
      _positionGamma = (e3 * c3 + e4 * (-c3)) / total;
    } else {
      _positionAlpha = 0.0;
      _positionBeta = 0.0;
      _positionGamma = 0.0;
    }

    final List<double> constrained = constrain4pAmplitudes(e1, e2, e3, e4);
    _electrode1Level = constrained[0];
    _electrode2Level = constrained[1];
    _electrode3Level = constrained[2];
    _electrode4Level = constrained[3];
    _fourPhaseElectrodeLevels = <double>[
      _electrode1Level,
      _electrode2Level,
      _electrode3Level,
      _electrode4Level,
    ];
    _threePhaseElectrodeLevels = <double>[
      _electrode1Level,
      _electrode2Level,
      _electrode3Level,
    ];
  }

  void updateThreePhaseLevels({
    required double alpha,
    required double beta,
    required double outputScale,
  }) {
    _positionAlpha = alpha;
    _positionBeta = beta;

    final double r = sqrt(alpha * alpha + beta * beta).clamp(0.0, 1.0);

    final double a00 = 0.5 * (2.0 - r + alpha);
    final double a01 = 0.5 * beta;
    final double a10 = 0.5 * beta;
    final double a11 = 0.5 * (2.0 - r - alpha);

    const double sq3 = 0.8660254037844386; // sqrt(3)/2
    final double m00 = a00;
    final double m10 = -0.5 * a00 + sq3 * a10;
    final double m20 = -0.5 * a00 - sq3 * a10;
    final double m01 = a01;
    final double m11 = -0.5 * a01 + sq3 * a11;
    final double m21 = -0.5 * a01 - sq3 * a11;

    final double p1 = sqrt(m00 * m00 + m01 * m01);
    final double p2 = sqrt(m10 * m10 + m11 * m11);
    final double p3 = sqrt(m20 * m20 + m21 * m21);

    final double mx = <double>[
      p1,
      p2,
      p3,
    ].reduce((double a, double b) => a > b ? a : b);
    if (mx > 1e-9) {
      _electrode1Level = (p1 / mx * outputScale).clamp(0.0, 1.0);
      _electrode2Level = (p2 / mx * outputScale).clamp(0.0, 1.0);
      _electrode3Level = (p3 / mx * outputScale).clamp(0.0, 1.0);
    } else {
      _electrode1Level = 0.0;
      _electrode2Level = 0.0;
      _electrode3Level = 0.0;
    }
    _electrode4Level = 0.0;
    _threePhaseElectrodeLevels = <double>[
      _electrode1Level,
      _electrode2Level,
      _electrode3Level,
    ];
    _fourPhaseElectrodeLevels = <double>[
      _electrode1Level,
      _electrode2Level,
      _electrode3Level,
      _electrode4Level,
    ];
  }

  void reset() {
    _electrode1Level = 0.0;
    _electrode2Level = 0.0;
    _electrode3Level = 0.0;
    _electrode4Level = 0.0;
    _positionAlpha = 0.0;
    _positionBeta = 0.0;
    _positionGamma = 0.0;
    _threePhaseElectrodeLevels = const <double>[0.0, 0.0, 0.0];
    _fourPhaseElectrodeLevels = const <double>[0.0, 0.0, 0.0, 0.0];
  }
}
