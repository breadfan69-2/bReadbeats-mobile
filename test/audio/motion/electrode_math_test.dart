import 'package:breadbeats_mobile/audio/motion/electrode_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constrain4pAmplitudes enforces bounds and triangle inequality', () {
    final List<double> constrained = constrain4pAmplitudes(1.2, 0.2, 0.1, 0.05);

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
}
