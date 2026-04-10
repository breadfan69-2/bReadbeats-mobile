import 'package:breadbeats_mobile/core/ring_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RingBuffer add wraps at capacity', () {
    final RingBuffer buffer = RingBuffer(3);

    buffer.add(1.0);
    buffer.add(2.0);
    buffer.add(3.0);
    buffer.add(4.0);

    expect(buffer.count, 3);
    expect(buffer.isFull, isTrue);
    expect(buffer.mean(), closeTo((2.0 + 3.0 + 4.0) / 3.0, 1e-12));
  });

  test('RingBuffer mean works for partial and full buffers', () {
    final RingBuffer partial = RingBuffer(5);
    partial.add(2.0);
    partial.add(4.0);
    expect(partial.mean(), closeTo(3.0, 1e-12));

    partial.add(6.0);
    partial.add(8.0);
    partial.add(10.0);
    expect(partial.mean(), closeTo(6.0, 1e-12));
  });

  test('RingBuffer std computes population standard deviation', () {
    final RingBuffer buffer = RingBuffer(5);
    buffer.add(1.0);
    buffer.add(2.0);
    buffer.add(3.0);
    buffer.add(4.0);

    expect(buffer.std(), closeTo(1.118033988749895, 1e-12));
  });

  test('RingBuffer linearSlope is positive for increasing values', () {
    final RingBuffer buffer = RingBuffer(5);
    for (int i = 0; i < 5; i += 1) {
      buffer.add(i.toDouble());
    }

    expect(buffer.linearSlope(), greaterThan(0.0));
  });

  test('RingBuffer linearSlope is negative for decreasing values', () {
    final RingBuffer buffer = RingBuffer(5);
    for (int i = 0; i < 5; i += 1) {
      buffer.add((5 - i).toDouble());
    }

    expect(buffer.linearSlope(), lessThan(0.0));
  });

  test('RingBuffer clear resets stored state', () {
    final RingBuffer buffer = RingBuffer(3);
    buffer.add(1.0);
    buffer.add(2.0);
    expect(buffer.count, 2);

    buffer.clear();

    expect(buffer.count, 0);
    expect(buffer.isFull, isFalse);
    expect(buffer.mean(), closeTo(0.0, 1e-12));
    expect(buffer.std(), closeTo(0.0, 1e-12));
    expect(buffer.linearSlope(), closeTo(0.0, 1e-12));
  });
}
