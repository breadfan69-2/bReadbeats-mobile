import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ─── Gold palette ────────────────────────────────────────────────────────────
// Extracted from bbicon.png — the BreadBeats "gold electric" spectrum.
const Color _kGoldDeep = Color(0xFFF0A010); // deep amber  (240,160,16)
const Color _kGoldMid = Color(0xFFF0B018); // amber       (240,176,24)
const Color _kGoldBright = Color(
  0xFFF8D820,
); // electric gold — dominant icon color (248,216,32)
const Color _kGoldHighlight = Color(
  0xFFF8E820,
); // bright highlight (248,232,32)
const Color _kGoldShadow = Color(
  0xFFC07008,
); // shadow (derived from burnt-orange #F07010, darkened)

/// The shape a [EmbossedMediaIcon] should paint.
enum MediaIconShape {
  rewind, // ⏪  two left-pointing triangles
  play, // ▶    single right-pointing triangle
  pause, // ⏸    two vertical bars
  playPause, // ▶⏸  right-pointing triangle + two bars (>||)
  forward, // ⏩  two right-pointing triangles
  skipPrev, // ⏮  bar + left-pointing triangle
  skipNext, // ⏭  right-pointing triangle + bar
}

/// A chromatic-gold, embossed media-control icon drawn with [CustomPainter].
///
/// The icon is fully vector — scales to any [size] without quality loss.
/// The embossed effect is achieved via layered gradient fills, offset
/// highlights, and a soft drop shadow.
class EmbossedMediaIcon extends StatelessWidget {
  const EmbossedMediaIcon({super.key, required this.shape, this.size = 28.0});

  final MediaIconShape shape;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _EmbossedMediaPainter(shape: shape),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _EmbossedMediaPainter extends CustomPainter {
  _EmbossedMediaPainter({required this.shape});

  final MediaIconShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    // Unit-space: all coords in 0..1, then scaled.
    canvas.save();
    canvas.scale(s, s);

    final Path iconPath = _buildPath(shape);

    // --- Layer 1: dark drop shadow (offset down-right) ---
    final Paint shadowPaint = Paint()
      ..color = _kGoldShadow.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.04);
    canvas.save();
    canvas.translate(0.03, 0.04);
    canvas.drawPath(iconPath, shadowPaint);
    canvas.restore();

    // --- Layer 2: main gold gradient fill (top-left → bottom-right) ---
    // 5-stop sweep across the full bbicon.png spectrum.
    final Paint bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0.1, 0.0),
        const Offset(0.9, 1.0),
        <Color>[
          _kGoldHighlight, // #F8E820
          _kGoldBright, // #F8D820
          const Color(0xFFF8C828), // warm gold #F8C828
          _kGoldMid, // #F0B018
          _kGoldDeep, // #F0A010
        ],
        <double>[0.0, 0.25, 0.50, 0.75, 1.0],
      );
    canvas.drawPath(iconPath, bodyPaint);

    // --- Layer 3: bright top-edge highlight (emboss ridge) ---
    final Paint highlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0.2, 0.0),
        const Offset(0.5, 0.55),
        <Color>[
          _kGoldHighlight.withValues(alpha: 0.7),
          _kGoldHighlight.withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(iconPath, highlightPaint);

    // --- Layer 4: dark bottom-edge inner shadow (emboss recess) ---
    // We draw the path offset slightly up-left with a dark transparent fill.
    final Paint recessPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0.5, 0.55),
        const Offset(0.8, 1.0),
        <Color>[
          _kGoldShadow.withValues(alpha: 0.0),
          _kGoldShadow.withValues(alpha: 0.40),
        ],
      );
    canvas.drawPath(iconPath, recessPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmbossedMediaPainter old) => old.shape != shape;

  // ─── Path builders (unit-square 0..1) ──────────────────────────────────

  static Path _buildPath(MediaIconShape shape) {
    switch (shape) {
      case MediaIconShape.rewind:
        return _doubleTrianglePath(pointsLeft: true);
      case MediaIconShape.forward:
        return _doubleTrianglePath(pointsLeft: false);
      case MediaIconShape.play:
        return _playPath();
      case MediaIconShape.pause:
        return _pausePath();
      case MediaIconShape.playPause:
        return _playPausePath();
      case MediaIconShape.skipPrev:
        return _skipPath(pointsLeft: true);
      case MediaIconShape.skipNext:
        return _skipPath(pointsLeft: false);
    }
  }

  /// ▶ Play: equilateral-ish right-pointing triangle centred in the square.
  static Path _playPath() {
    return Path()
      ..moveTo(0.28, 0.15)
      ..lineTo(0.80, 0.50)
      ..lineTo(0.28, 0.85)
      ..close();
  }

  /// ⏸ Pause: two vertical rounded-rect bars.
  static Path _pausePath() {
    const double bw = 0.16; // bar width
    const double gap = 0.10;
    const double top = 0.18;
    const double bot = 0.82;
    final double x1 = 0.5 - gap / 2 - bw;
    final double x2 = 0.5 + gap / 2;
    const Radius r = Radius.circular(0.04);
    return Path()
      ..addRRect(RRect.fromLTRBR(x1, top, x1 + bw, bot, r))
      ..addRRect(RRect.fromLTRBR(x2, top, x2 + bw, bot, r));
  }

  /// ▶⏸ Play/Pause: right-pointing triangle + two vertical bars (>||).
  static Path _playPausePath() {
    const double barW = 0.11;
    const double gap = 0.06;
    const double top = 0.18;
    const double bot = 0.82;
    const Radius r = Radius.circular(0.03);
    const double ty = 0.50;
    const double halfH = (bot - top) / 2;
    // Play triangle on the left
    const double triLeft = 0.10;
    const double triTip = 0.42;
    // Two pause bars on the right
    final double x1 = triTip + 0.06;
    final double x2 = x1 + barW + gap;
    return Path()
      ..moveTo(triLeft, ty - halfH)
      ..lineTo(triTip, ty)
      ..lineTo(triLeft, ty + halfH)
      ..close()
      ..addRRect(RRect.fromLTRBR(x1, top, x1 + barW, bot, r))
      ..addRRect(RRect.fromLTRBR(x2, top, x2 + barW, bot, r));
  }

  /// ⏪ / ⏩  Two side-by-side triangles.
  static Path _doubleTrianglePath({required bool pointsLeft}) {
    final Path p = Path();
    const double ty = 0.50; // vertical centre
    const double halfH = 0.35; // half-height of each triangle
    // Two triangles sit side by side within 0.15..0.85
    if (pointsLeft) {
      // left triangle
      p.moveTo(0.15, ty);
      p.lineTo(0.50, ty - halfH);
      p.lineTo(0.50, ty + halfH);
      p.close();
      // right triangle
      p.moveTo(0.44, ty);
      p.lineTo(0.79, ty - halfH);
      p.lineTo(0.79, ty + halfH);
      p.close();
    } else {
      // left triangle
      p.moveTo(0.21, ty - halfH);
      p.lineTo(0.56, ty);
      p.lineTo(0.21, ty + halfH);
      p.close();
      // right triangle
      p.moveTo(0.50, ty - halfH);
      p.lineTo(0.85, ty);
      p.lineTo(0.50, ty + halfH);
      p.close();
    }
    return p;
  }

  /// ⏮ / ⏭  Bar + single triangle.
  static Path _skipPath({required bool pointsLeft}) {
    final Path p = Path();
    const double ty = 0.50;
    const double halfH = 0.35;
    const double barW = 0.08;
    const Radius r = Radius.circular(0.02);
    if (pointsLeft) {
      // bar on the left
      p.addRRect(RRect.fromLTRBR(0.18, ty - halfH, 0.18 + barW, ty + halfH, r));
      // triangle pointing left
      p.moveTo(0.30, ty);
      p.lineTo(0.78, ty - halfH);
      p.lineTo(0.78, ty + halfH);
      p.close();
    } else {
      // triangle pointing right
      p.moveTo(0.22, ty - halfH);
      p.lineTo(0.70, ty);
      p.lineTo(0.22, ty + halfH);
      p.close();
      // bar on the right
      p.addRRect(RRect.fromLTRBR(0.74, ty - halfH, 0.74 + barW, ty + halfH, r));
    }
    return p;
  }
}
