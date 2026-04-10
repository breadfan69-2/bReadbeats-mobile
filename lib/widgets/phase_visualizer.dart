import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'neumorphic_tile.dart';

/// Phase position visualizer — renders 3-phase circle or 4-phase tetrahedron.
/// Extracted from main.dart to be reusable as a standalone widget.
class PhasePositionVisualizer extends StatefulWidget {
  const PhasePositionVisualizer({
    super.key,
    required this.isFourPhase,
    required this.animate,
    required this.alpha,
    required this.beta,
    required this.gamma,
    required this.electrodeLevels,
    required this.active,
  });

  final bool isFourPhase;
  final bool animate;
  final double alpha;
  final double beta;
  final double gamma;
  final List<double> electrodeLevels;
  final bool active;

  @override
  State<PhasePositionVisualizer> createState() =>
      _PhasePositionVisualizerState();
}

class _PhasePositionVisualizerState extends State<PhasePositionVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _yaw = 0.4;

  bool get _shouldAnimate => widget.isFourPhase && widget.animate;

  void _syncTicker() {
    if (_shouldAnimate) {
      if (!_ticker.isActive) {
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (_shouldAnimate) {
        setState(() {
          _yaw += 0.008;
        });
      }
    });
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant PhasePositionVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFourPhase != widget.isFourPhase ||
        oldWidget.animate != widget.animate) {
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: CustomPaint(
        painter: widget.isFourPhase
            ? FourPhasePainter(
                yaw: _yaw,
                alpha: widget.alpha,
                beta: widget.beta,
                gamma: widget.gamma,
                active: widget.active,
              )
            : ThreePhasePainter(
                alpha: widget.alpha,
                beta: widget.beta,
                active: widget.active,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
      ),
    );
  }
}

// ── 3-Phase Circle Painter ──

class ThreePhasePainter extends CustomPainter {
  ThreePhasePainter({
    required this.alpha,
    required this.beta,
    required this.active,
    required this.isDark,
  });

  final double alpha;
  final double beta;
  final bool active;
  final bool isDark;

  static const double _sq3_2 = 0.8660254037844386;
  static const List<List<double>> _electrodeAB = <List<double>>[
    <double>[1.0, 0.0],
    <double>[-0.5, _sq3_2],
    <double>[-0.5, -_sq3_2],
  ];
  static const List<String> _labels = <String>['A', 'B', 'C'];
  static const List<Color> _colors = kElectrodeColors;

  Offset _abToXY(double a, double b, Offset center, double scale) {
    return Offset(center.dx - b * scale, center.dy - a * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double scale = min(size.width, size.height) * 0.38;

    const Color cyan = Color(0xFF0B8C89);
    canvas.drawCircle(
      center,
      scale,
      Paint()
        ..color = isDark ? const Color(0xFF1A2A2A) : const Color(0xFFE6F1F0)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      scale,
      Paint()
        ..color = cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final List<Offset> triPts = <Offset>[
      for (int i = 0; i < 3; i++)
        _abToXY(_electrodeAB[i][0], _electrodeAB[i][1], center, scale),
    ];
    final Path triPath = Path()
      ..moveTo(triPts[0].dx, triPts[0].dy)
      ..lineTo(triPts[1].dx, triPts[1].dy)
      ..lineTo(triPts[2].dx, triPts[2].dy)
      ..close();
    canvas.drawPath(
      triPath,
      Paint()
        ..color = cyan.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.drawCircle(
      center,
      2.5,
      Paint()..color = cyan.withValues(alpha: 0.5),
    );

    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 3; i++) {
      final Offset pt = triPts[i];
      canvas.drawCircle(pt, 6, Paint()..color = _colors[i]);
      canvas.drawCircle(
        pt,
        6,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final Offset dir = (pt - center);
      final double len = dir.distance;
      final Offset labelPos =
          len > 0 ? pt + dir / len * 14 : pt + const Offset(0, -14);
      tp.text = TextSpan(
        text: _labels[i],
        style: TextStyle(
          color: _colors[i],
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      );
      tp.layout();
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }

    final double a = alpha.clamp(-1.0, 1.0);
    final double b = beta.clamp(-1.0, 1.0);
    final double norm = sqrt(a * a + b * b);
    final double ca = norm >= 1.0 ? a / norm : a;
    final double cb = norm >= 1.0 ? b / norm : b;
    final Offset cursor = _abToXY(ca, cb, center, scale);
    final Color dotColor =
        active ? const Color(0xFF0FFFFF) : const Color(0xFF7F9A99);
    canvas.drawCircle(cursor, 5.5, Paint()..color = dotColor);
    canvas.drawCircle(
      cursor,
      5.5,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant ThreePhasePainter old) {
    return alpha != old.alpha ||
        beta != old.beta ||
        active != old.active ||
        isDark != old.isDark;
  }
}

// ── 4-Phase Tetrahedron Painter ──

class FourPhasePainter extends CustomPainter {
  FourPhasePainter({
    required this.yaw,
    required this.alpha,
    required this.beta,
    required this.gamma,
    required this.active,
  });

  final double yaw;
  final double alpha;
  final double beta;
  final double gamma;
  final bool active;

  static const List<List<double>> _verts = <List<double>>[
    <double>[1.0, 0.0, 0.0],
    <double>[-0.3333333, 0.9428090415820634, 0.0],
    <double>[-0.3333333, -0.4714045207910317, 0.8164965809277261],
    <double>[-0.3333333, -0.4714045207910317, -0.8164965809277261],
  ];

  static const List<String> _labels = <String>['A', 'B', 'C', 'D'];
  static const List<Color> _colors = kElectrodeColors;

  static const List<List<int>> _edges = <List<int>>[
    <int>[0, 1], <int>[0, 2], <int>[0, 3],
    <int>[1, 2], <int>[1, 3], <int>[2, 3],
  ];

  static const List<List<int>> _faces = <List<int>>[
    <int>[1, 2, 3],
    <int>[0, 2, 3],
    <int>[0, 1, 3],
    <int>[0, 1, 2],
  ];

  List<List<double>> _rotate(double yaw, double pitch) {
    final double cy = cos(yaw), sy = sin(yaw);
    final double cp = cos(pitch), sp = sin(pitch);
    return <List<double>>[
      <double>[cy, sy * sp, sy * cp],
      <double>[0, cp, -sp],
      <double>[-sy, cy * sp, cy * cp],
    ];
  }

  List<double> _mul(List<List<double>> m, List<double> v) {
    return <double>[
      m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
      m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
      m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double scale = min(size.width, size.height) * 0.46;
    const double pitch = -0.35;
    final List<List<double>> rot = _rotate(yaw, pitch);

    final List<List<double>> rv = <List<double>>[
      for (final List<double> v in _verts) _mul(rot, v),
    ];
    final List<Offset> proj = <Offset>[
      for (final List<double> v in rv)
        Offset(center.dx + v[0] * scale, center.dy - v[1] * scale),
    ];
    final List<double> depth = <double>[for (final List<double> v in rv) v[2]];

    final List<int> faceOrder = List<int>.generate(4, (int i) => i);
    faceOrder.sort((int a, int b) {
      final double za = (depth[_faces[a][0]] + depth[_faces[a][1]] + depth[_faces[a][2]]) / 3;
      final double zb = (depth[_faces[b][0]] + depth[_faces[b][1]] + depth[_faces[b][2]]) / 3;
      return za.compareTo(zb);
    });
    for (final int fi in faceOrder) {
      final List<int> face = _faces[fi];
      final Path path = Path()
        ..moveTo(proj[face[0]].dx, proj[face[0]].dy)
        ..lineTo(proj[face[1]].dx, proj[face[1]].dy)
        ..lineTo(proj[face[2]].dx, proj[face[2]].dy)
        ..close();
      final Offset d1 = proj[face[1]] - proj[face[0]];
      final Offset d2 = proj[face[2]] - proj[face[0]];
      final double nz = d1.dx * d2.dy - d1.dy * d2.dx;
      final int a = nz > 0 ? 35 : 15;
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromARGB(a, 0, 0, 0)
          ..style = PaintingStyle.fill,
      );
    }

    for (final List<int> edge in _edges) {
      final double az = (depth[edge[0]] + depth[edge[1]]) / 2;
      final double t = ((az + 1.2) / 2.4).clamp(0.0, 1.0);
      final int ea = (60 + t * 140).round();
      final double w = 1.0 + t * 1.2;
      canvas.drawLine(
        proj[edge[0]],
        proj[edge[1]],
        Paint()
          ..color = Color.fromARGB(ea, 80, 80, 80)
          ..strokeWidth = w,
      );
    }

    final List<int> vertOrder = List<int>.generate(4, (int i) => i);
    vertOrder.sort((int a, int b) => depth[a].compareTo(depth[b]));
    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    for (final int vi in vertOrder) {
      final double t = ((depth[vi] + 1.2) / 2.4).clamp(0.0, 1.0);
      final double df = 0.7 + t * 0.5;
      final double af = 0.4 + t * 0.6;
      final double r = 6.0 * df;
      canvas.drawCircle(
        proj[vi],
        r,
        Paint()..color = _colors[vi].withValues(alpha: af),
      );
      canvas.drawCircle(
        proj[vi],
        r,
        Paint()
          ..color = Color.fromARGB((180 * af).round(), 255, 255, 255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final Offset dir = proj[vi] - center;
      final double len = dir.distance;
      final Offset labelPos =
          len > 0 ? proj[vi] + dir / len * (r + 10) : proj[vi] + const Offset(0, -14);
      tp.text = TextSpan(
        text: _labels[vi],
        style: TextStyle(
          color: _colors[vi].withValues(alpha: af),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      );
      tp.layout();
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));
    }

    final List<double> cursorAbc = <double>[alpha, beta, gamma];
    final List<double> rc = _mul(rot, cursorAbc);
    final Offset cursorPos =
        Offset(center.dx + rc[0] * scale, center.dy - rc[1] * scale);
    final double curNorm = sqrt(alpha * alpha + beta * beta + gamma * gamma);
    final double curAlpha = (curNorm * 1.5).clamp(0.0, 1.0);
    final Color cursorColor = active
        ? Color.fromARGB((220 * curAlpha).round(), 180, 140, 220)
        : Color.fromARGB((180 * curAlpha).round(), 127, 154, 153);
    canvas.drawCircle(cursorPos, 6, Paint()..color = cursorColor);
    canvas.drawCircle(
      cursorPos,
      6,
      Paint()
        ..color = Color.fromARGB((200 * curAlpha).round(), 255, 255, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant FourPhasePainter old) {
    return yaw != old.yaw ||
        alpha != old.alpha ||
        beta != old.beta ||
        gamma != old.gamma ||
        active != old.active;
  }
}
