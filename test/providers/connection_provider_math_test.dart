import 'package:breadbeats_mobile/providers/connection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectionProvider math helpers', () {
    test('constrain4pAmplitudes enforces bounds and triangle inequality', () {
      final List<double> constrained =
          ConnectionProvider.constrain4pAmplitudesForTest(1.2, 0.2, 0.1, 0.05);

      expect(constrained, hasLength(4));
      for (final double value in constrained) {
        expect(value, inInclusiveRange(0.0, 1.0));
      }

      final double sum = constrained.reduce((double a, double b) => a + b);
      for (final double value in constrained) {
        expect(value <= (sum - value + 1e-9), isTrue);
      }

      final double maxValue = constrained.reduce(
        (double a, double b) => a > b ? a : b,
      );
      expect(maxValue, closeTo(1.0, 1e-9));
    });

    test('quinticSmoothstep is monotonic and clamped', () {
      double previous = -1.0;
      for (int i = 0; i <= 20; i++) {
        final double t = i / 20.0;
        final double value = ConnectionProvider.quinticSmoothstepForTest(t);
        expect(value, inInclusiveRange(0.0, 1.0));
        expect(value >= previous, isTrue);
        previous = value;
      }

      expect(ConnectionProvider.quinticSmoothstepForTest(0.0), closeTo(0.0, 1e-12));
      expect(ConnectionProvider.quinticSmoothstepForTest(1.0), closeTo(1.0, 1e-12));
      expect(ConnectionProvider.quinticSmoothstepForTest(-3.0), closeTo(0.0, 1e-12));
      expect(ConnectionProvider.quinticSmoothstepForTest(7.0), closeTo(1.0, 1e-12));
    });

    test('smoothValue applies attack/release slew behavior', () {
      final double attackStep = ConnectionProvider.smoothValueForTest(
        previous: 0.0,
        target: 1.0,
        dtSec: 0.1,
        attackSec: 0.1,
        releaseSec: 1.0,
      );
      final double releaseStep = ConnectionProvider.smoothValueForTest(
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
      final (double alphaStart, double betaStart) =
          ConnectionProvider.shuttleArcForTest(0.0, 0.8, 1.0);
      final (double alphaMid, double betaMid) =
          ConnectionProvider.shuttleArcForTest(0.5, 0.8, 1.0);
      final (double alphaEnd, double betaEnd) =
          ConnectionProvider.shuttleArcForTest(1.0, 0.8, 1.0);

      expect(alphaStart, closeTo(-0.5, 1e-9));
      expect(betaStart, closeTo(0.866, 1e-9));
      expect(alphaEnd, closeTo(-0.5, 1e-9));
      expect(betaEnd, closeTo(-0.866, 1e-9));

      expect(alphaMid, greaterThan(alphaStart));
      expect(betaMid, closeTo(0.0, 1e-9));
    });
  });
}
