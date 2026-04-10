import 'dart:math';
import 'dart:typed_data';

class RingBuffer {
  RingBuffer(this.capacity)
    : assert(capacity > 0),
      _buffer = Float64List(capacity);

  final int capacity;
  final Float64List _buffer;

  int _head = 0;
  int _count = 0;

  int get count => _count;
  bool get isFull => _count >= capacity;

  void add(double value) {
    _buffer[_head] = value;
    _head = (_head + 1) % capacity;
    if (_count < capacity) {
      _count += 1;
    }
  }

  double mean() {
    if (_count == 0) {
      return 0.0;
    }

    double sum = 0.0;
    for (int i = 0; i < _count; i += 1) {
      sum += _valueAtOldestOffset(i);
    }
    return sum / _count;
  }

  double std() {
    if (_count < 2) {
      return 0.0;
    }

    final double m = mean();
    double sumSq = 0.0;
    for (int i = 0; i < _count; i += 1) {
      final double delta = _valueAtOldestOffset(i) - m;
      sumSq += delta * delta;
    }
    return sqrt(sumSq / _count);
  }

  double linearSlope() {
    if (_count < 2) {
      return 0.0;
    }

    final double xMean = (_count - 1) / 2.0;
    double sxy = 0.0;
    double sxx = 0.0;

    for (int i = 0; i < _count; i += 1) {
      final double y = _valueAtOldestOffset(i);
      final double dx = i.toDouble() - xMean;
      sxy += dx * y;
      sxx += dx * dx;
    }

    if (sxx <= 1e-12) {
      return 0.0;
    }
    return sxy / sxx;
  }

  void clear() {
    _head = 0;
    _count = 0;
  }

  double _valueAtOldestOffset(int offset) {
    final int oldest = (_head - _count + capacity) % capacity;
    final int index = (oldest + offset) % capacity;
    return _buffer[index];
  }
}
