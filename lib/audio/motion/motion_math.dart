import 'dart:math';

double smoothValue({
  required double previous,
  required double target,
  required double dtSec,
  required double attackSec,
  required double releaseSec,
}) {
  if (dtSec <= 0) {
    return target;
  }

  final double tau = target > previous ? attackSec : releaseSec;
  if (tau <= 0) {
    return target;
  }

  final double alpha = 1.0 - exp(-dtSec / tau);
  return previous + alpha * (target - previous);
}

double quinticSmoothstep(double t) {
  final double tc = t.clamp(0.0, 1.0);
  return tc * tc * tc * (tc * (tc * 6.0 - 15.0) + 10.0);
}

(double alpha, double beta) shuttleArc(
  double position,
  double radius,
  double arcDir,
) {
  const double betaL = 0.866;
  const double betaR = -0.866;
  const double alphaBase = -0.50;
  final double theta = position * pi;
  final double beta = betaL + (betaR - betaL) * position;
  final double bulge = radius * sin(theta);
  final double alpha = alphaBase + arcDir * bulge;
  return (alpha.clamp(-1.0, 1.0), beta.clamp(-1.0, 1.0));
}
