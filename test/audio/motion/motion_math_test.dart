import 'package:breadbeats_mobile/audio/motion/motion_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quinticSmoothstep is monotonic and clamped', () {
    double previous = -1.0;
    for (int i = 0; i <= 20; i++) {
      final double t = i / 20.0;
      final double value = quinticSmoothstep(t);
      expect(value, inInclusiveRange(0.0, 1.0));
      expect(value >= previous, isTrue);
      previous = value;
    }

    expect(quinticSmoothstep(0.0), closeTo(0.0, 1e-12));
    expect(quinticSmoothstep(1.0), closeTo(1.0, 1e-12));
    expect(quinticSmoothstep(-3.0), closeTo(0.0, 1e-12));
    expect(quinticSmoothstep(7.0), closeTo(1.0, 1e-12));
  });

  test('smoothValue applies attack/release slew behavior', () {
    final double attackStep = smoothValue(
      previous: 0.0,
      target: 1.0,
      dtSec: 0.1,
      attackSec: 0.1,
      releaseSec: 1.0,
    );
    final double releaseStep = smoothValue(
      previous: 1.0,
      target: 0.0,
      dtSec: 0.1,
      attackSec: 0.1,
      releaseSec: 1.0,
    );

    expect(attackStep, inInclusiveRange(0.0, 1.0));
    expect(releaseStep, inInclusiveRange(0.0, 1.0));
    expect(attackStep, greaterThan(0.0));
    expect(releaseStep, lessThan(1.0));
    expect(attackStep, greaterThan(1.0 - releaseStep));
  });

  test('shuttleArc projects expected half-circle endpoints', () {
    final (double alphaStart, double betaStart) = shuttleArc(0.0, 0.8, 1.0);
    final (double alphaMid, double betaMid) = shuttleArc(0.5, 0.8, 1.0);
    final (double alphaEnd, double betaEnd) = shuttleArc(1.0, 0.8, 1.0);

    expect(alphaStart, closeTo(-0.5, 1e-9));
    expect(betaStart, closeTo(0.866, 1e-9));
    expect(alphaEnd, closeTo(-0.5, 1e-9));
    expect(betaEnd, closeTo(-0.866, 1e-9));

    expect(alphaMid, greaterThan(alphaStart));
    expect(betaMid, closeTo(0.0, 1e-9));
  });
}
