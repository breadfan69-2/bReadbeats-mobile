import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/haptics.dart';
import 'neumorphic_tile.dart';

class RotaryDial extends StatefulWidget {
  const RotaryDial({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.detentStep,
    this.onLockedDragStart,
    this.size = 56.0,
    this.accentColor = kAccentCyan,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final double? detentStep;
  final VoidCallback? onLockedDragStart;
  final double size;
  final Color accentColor;

  // Arc geometry — must match _RotaryDialPainter.
  static const double _kStartAngle = math.pi * 0.75;
  static const double _kSweepAngle = math.pi * 1.5;

  @override
  State<RotaryDial> createState() => _RotaryDialState();
}

class _RotaryDialState extends State<RotaryDial> {
  int? _lastDetentBucket;
  int _boundaryEdge = 0;
  bool _lockedDragHandled = false;

  int _detentBucket(double value) {
    final double step = widget.detentStep ?? 0.0;
    if (step <= 0.0) {
      return 0;
    }
    return ((value - widget.min) / step).floor();
  }

  void _emitBoundary(double value) {
    final bool atMin = (value - widget.min).abs() <= 1e-6;
    final bool atMax = (widget.max - value).abs() <= 1e-6;
    final int edge = atMin ? -1 : (atMax ? 1 : 0);
    if (edge != 0 && edge != _boundaryEdge) {
      Haptics.medium();
    }
    _boundaryEdge = edge;
  }

  void _handleDrag(Offset localPos) {
    if (widget.onChanged == null || widget.max <= widget.min) return;
    final double cx = widget.size / 2.0;
    final double cy = widget.size / 2.0;
    // Angle of the touch point relative to the dial centre, in [0, 2π).
    double angle = math.atan2(localPos.dy - cy, localPos.dx - cx);
    if (angle < 0) angle += 2 * math.pi;
    // Rotate so the arc's start maps to 0.
    double shifted = angle - RotaryDial._kStartAngle;
    if (shifted < 0) shifted += 2 * math.pi;
    // Ignore touches that fall in the dead-zone gap below the dial.
    if (shifted > RotaryDial._kSweepAngle) return;
    final double normalized = (shifted / RotaryDial._kSweepAngle).clamp(0.0, 1.0);
    final double nextValue = widget.min + normalized * (widget.max - widget.min);
    widget.onChanged!(nextValue);
    _emitBoundary(nextValue);

    final double step = widget.detentStep ?? 0.0;
    if (step > 0.0) {
      final int bucket = _detentBucket(nextValue);
      final int? previousBucket = _lastDetentBucket;
      if (previousBucket != null && bucket != previousBucket) {
        Haptics.selection();
      }
      _lastDetentBucket = bucket;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onChanged != null && widget.max > widget.min;
    final double clampedValue = widget.value.clamp(widget.min, widget.max).toDouble();

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) {
          if (!enabled) {
            if (_lockedDragHandled) {
              return;
            }
            _lockedDragHandled = true;
            widget.onLockedDragStart?.call();
            return;
          }
          _lastDetentBucket = _detentBucket(clampedValue);
          _boundaryEdge = 0;
          _lockedDragHandled = false;
        },
        onPanUpdate: enabled
            ? (details) => _handleDrag(details.localPosition)
            : null,
        onPanEnd: (_) {
          _lastDetentBucket = null;
          _boundaryEdge = 0;
          _lockedDragHandled = false;
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RotaryDialPainter(
              min: widget.min,
              max: widget.max,
              value: clampedValue,
              accentColor: widget.accentColor,
              enabled: enabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _RotaryDialPainter extends CustomPainter {
  const _RotaryDialPainter({
    required this.min,
    required this.max,
    required this.value,
    required this.accentColor,
    required this.enabled,
  });

  final double min;
  final double max;
  final double value;
  final Color accentColor;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final double shortest = math.min(size.width, size.height);
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double radius = shortest / 2.0;
    final double outerStroke = math.max(3.0, shortest * 0.12);
    final double ringRadius = radius - outerStroke * 0.65;

    final Paint basePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          kNeumorphicLighter.withValues(alpha: 0.95),
          kNeumorphicBase.withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, basePaint);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    const double startAngle = math.pi * 0.75;
    const double sweepAngle = math.pi * 1.5;
    final double normalized = max > min
        ? ((value - min) / (max - min)).clamp(0.0, 1.0)
        : 0.0;

    final Rect ringRect = Rect.fromCircle(center: center, radius: ringRadius);

    canvas.drawArc(
      ringRect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke
        ..strokeCap = StrokeCap.round,
    );

    final Color activeAccent = enabled
        ? accentColor
        : accentColor.withValues(alpha: 0.45);

    canvas.drawArc(
      ringRect,
      startAngle,
      sweepAngle * normalized,
      false,
      Paint()
        ..color = activeAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke
        ..strokeCap = StrokeCap.round,
    );

    final double indicatorAngle = startAngle + sweepAngle * normalized;
    final Offset indicatorCenter = Offset(
      center.dx + math.cos(indicatorAngle) * ringRadius,
      center.dy + math.sin(indicatorAngle) * ringRadius,
    );

    final double indicatorRadius = math.max(2.8, shortest * 0.075);
    canvas.drawCircle(
      indicatorCenter,
      indicatorRadius,
      Paint()..color = activeAccent,
    );
    canvas.drawCircle(
      indicatorCenter,
      indicatorRadius,
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    final double innerRadius = radius - outerStroke * 1.35;
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..color = kNeumorphicDarker.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RotaryDialPainter oldDelegate) {
    return oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.value != value ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.enabled != enabled;
  }
}
