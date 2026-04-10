import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/haptics.dart';
import 'neumorphic_tile.dart';

class ManualFourPhasePad extends StatelessWidget {
  const ManualFourPhasePad({
    super.key,
    required this.smoothedE1,
    required this.smoothedE2,
    required this.smoothedE3,
    required this.smoothedE4,
    required this.userE4,
    required this.active,
    required this.onElectrodesChanged,
  });

  final double smoothedE1;
  final double smoothedE2;
  final double smoothedE3;
  final double smoothedE4;
  final double userE4;
  final bool active;
  final void Function(double e1, double e2, double e3, double e4)
  onElectrodesChanged;

  _TriangleGeometry _triangleForSize(Size size) {
    const double padding = 20.0;
    final double availableWidth = max(0.0, size.width - padding * 2.0);
    final double availableHeight = max(0.0, size.height - padding * 2.0);
    final double side = min(availableWidth, availableHeight / (sqrt(3) / 2.0));
    final double triHeight = side * sqrt(3) / 2.0;
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);

    final Offset a = Offset(center.dx, center.dy - triHeight / 2.0);
    final Offset b = Offset(
      center.dx - side / 2.0,
      center.dy + triHeight / 2.0,
    );
    final Offset c = Offset(
      center.dx + side / 2.0,
      center.dy + triHeight / 2.0,
    );

    return _TriangleGeometry(a: a, b: b, c: c);
  }

  (double e1, double e2, double e3) _barycentricFromPoint(
    Offset point,
    _TriangleGeometry tri,
  ) {
    final Offset a = tri.a;
    final Offset b = tri.b;
    final Offset c = tri.c;

    final double denominator =
        ((b.dy - c.dy) * (a.dx - c.dx)) + ((c.dx - b.dx) * (a.dy - c.dy));
    if (denominator.abs() < 1e-9) {
      return (1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0);
    }

    double u =
        ((b.dy - c.dy) * (point.dx - c.dx) +
            (c.dx - b.dx) * (point.dy - c.dy)) /
        denominator;
    double v =
        ((c.dy - a.dy) * (point.dx - c.dx) +
            (a.dx - c.dx) * (point.dy - c.dy)) /
        denominator;
    double w = 1.0 - u - v;

    u = u.clamp(0.0, 0.5);
    v = v.clamp(0.0, 0.5);
    w = w.clamp(0.0, 0.5);

    final double sum = u + v + w;
    if (sum <= 1e-9) {
      return (1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0);
    }

    return (u / sum, v / sum, w / sum);
  }

  void _handleTouch(
    Offset localPosition,
    Size size, {
    bool withHaptic = false,
  }) {
    final _TriangleGeometry tri = _triangleForSize(size);
    final (double b1, double b2, double b3) = _barycentricFromPoint(
      localPosition,
      tri,
    );

    // Auto-reduce D so the touch position can be fully represented.
    // D_max = 3 * min(b_i): farther from centroid → lower D allowed.
    final double dMax = 3.0 * min(b1, min(b2, b3));
    final double newE4 = min(userE4, dMax);

    // When the triangle position forces D lower than the slider, alert the user
    // with a haptic (only on the initial touch, not on every drag frame).
    if (withHaptic && newE4 < userE4 - 0.01) {
      Haptics.medium();
    }

    // Expand the barycentric ratios to compensate for the visual lerp toward
    // centroid, so the on-screen dot lands at the touched point.
    final double budget = 1.0 - newE4;
    double r1, r2, r3;
    if (budget > 1e-9) {
      const double third = 1.0 / 3.0;
      r1 = third + (b1 - third) / budget;
      r2 = third + (b2 - third) / budget;
      r3 = third + (b3 - third) / budget;
    } else {
      r1 = 1.0 / 3.0;
      r2 = 1.0 / 3.0;
      r3 = 1.0 / 3.0;
    }

    onElectrodesChanged(r1, r2, r3, newE4);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final _TriangleGeometry tri = _triangleForSize(size);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) {
            _handleTouch(details.localPosition, size, withHaptic: true);
          },
          onPanStart: (DragStartDetails details) {
            _handleTouch(details.localPosition, size, withHaptic: true);
          },
          onPanUpdate: (DragUpdateDetails details) {
            _handleTouch(details.localPosition, size);
          },
          child: ColoredBox(
            color: const Color(0xFF0A0A0A),
            child: CustomPaint(
              size: Size.infinite,
              painter: _ManualFourPhasePainter(
                triangle: tri,
                smoothedE1: smoothedE1,
                smoothedE2: smoothedE2,
                smoothedE3: smoothedE3,
                smoothedE4: smoothedE4,
                active: active,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TriangleGeometry {
  const _TriangleGeometry({required this.a, required this.b, required this.c});

  final Offset a;
  final Offset b;
  final Offset c;
}

class _ManualFourPhasePainter extends CustomPainter {
  const _ManualFourPhasePainter({
    required this.triangle,
    required this.smoothedE1,
    required this.smoothedE2,
    required this.smoothedE3,
    required this.smoothedE4,
    required this.active,
  });

  final _TriangleGeometry triangle;
  final double smoothedE1;
  final double smoothedE2;
  final double smoothedE3;
  final double smoothedE4;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final Path trianglePath = Path()
      ..moveTo(triangle.a.dx, triangle.a.dy)
      ..lineTo(triangle.b.dx, triangle.b.dy)
      ..lineTo(triangle.c.dx, triangle.c.dy)
      ..close();

    final Rect triBounds = trianglePath.getBounds();
    canvas.drawPath(
      trianglePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF17172A), Color(0xFF0E0E18)],
        ).createShader(triBounds),
    );

    canvas.drawPath(
      trianglePath,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Depth lines: fading from each vertex toward the centroid to convey
    // the perspective of looking at the bottom face of the tetrahedron.
    final Offset centroid = Offset(
      (triangle.a.dx + triangle.b.dx + triangle.c.dx) / 3.0,
      (triangle.a.dy + triangle.b.dy + triangle.c.dy) / 3.0,
    );
    final List<Offset> triVerts = <Offset>[triangle.a, triangle.b, triangle.c];
    for (int j = 0; j < 3; j++) {
      canvas.drawLine(
        triVerts[j],
        centroid,
        Paint()
          ..strokeWidth = 1.1
          ..shader = ui.Gradient.linear(triVerts[j], centroid, <Color>[
            kElectrodeColors[j].withValues(alpha: 0.38),
            Colors.transparent,
          ]),
      );
    }

    final List<Offset> points = <Offset>[triangle.a, triangle.b, triangle.c];
    final List<String> labels = <String>['A', 'B', 'C'];
    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < 3; i++) {
      final Offset point = points[i];
      final Color color = kElectrodeColors[i];
      canvas.drawCircle(point, 7.0, Paint()..color = color);
      canvas.drawCircle(
        point,
        7.0,
        Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final Offset center = triBounds.center;
      final Offset dir = point - center;
      final double len = dir.distance;
      final Offset labelPos = len > 1e-6
          ? point + dir / len * 15.0
          : point + const Offset(0, -15);

      tp.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      );
      tp.layout();
      tp.paint(canvas, labelPos - Offset(tp.width / 2.0, tp.height / 2.0));
    }

    // Compute dot position: raw ratio-based position lerped toward centroid
    // by the D-axis value, so the dot smoothly moves inward as D increases.
    final double eSum = smoothedE1 + smoothedE2 + smoothedE3;
    final double rn1 = eSum > 1e-9 ? smoothedE1 / eSum : (1.0 / 3.0);
    final double rn2 = eSum > 1e-9 ? smoothedE2 / eSum : (1.0 / 3.0);
    final double rn3 = 1.0 - rn1 - rn2;
    final Offset rawCursor = Offset(
      triangle.a.dx * rn1 + triangle.b.dx * rn2 + triangle.c.dx * rn3,
      triangle.a.dy * rn1 + triangle.b.dy * rn2 + triangle.c.dy * rn3,
    );
    final Offset cursor = Offset.lerp(
      rawCursor,
      centroid,
      smoothedE4.clamp(0.0, 1.0),
    )!;

    final Color cursorColor = active
        ? const Color.fromARGB(220, 180, 140, 220)
        : const Color.fromARGB(180, 127, 154, 153);
    // Dot shrinks as D-axis increases: larger = closer (e4≈0), smaller = farther (e4≈1).
    final double cursorRadius = 8.0 - 4.5 * smoothedE4.clamp(0.0, 1.0);
    canvas.drawCircle(cursor, cursorRadius, Paint()..color = cursorColor);
    canvas.drawCircle(
      cursor,
      cursorRadius,
      Paint()
        ..color = const Color.fromARGB(200, 255, 255, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _ManualFourPhasePainter oldDelegate) {
    return triangle != oldDelegate.triangle ||
        smoothedE1 != oldDelegate.smoothedE1 ||
        smoothedE2 != oldDelegate.smoothedE2 ||
        smoothedE3 != oldDelegate.smoothedE3 ||
        smoothedE4 != oldDelegate.smoothedE4 ||
        active != oldDelegate.active;
  }
}
