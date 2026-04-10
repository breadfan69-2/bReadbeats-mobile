import 'dart:math';

import 'package:flutter/material.dart';

import 'phase_visualizer.dart';

class ManualThreePhasePad extends StatelessWidget {
  const ManualThreePhasePad({
    super.key,
    required this.smoothedAlpha,
    required this.smoothedBeta,
    required this.active,
    required this.onPositionChanged,
  });

  final double smoothedAlpha;
  final double smoothedBeta;
  final bool active;
  final void Function(double alpha, double beta) onPositionChanged;

  (double alpha, double beta) _toAlphaBeta(Offset local, Size size) {
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double scale = min(size.width, size.height) * 0.38;
    if (scale <= 0.0) {
      return (0.0, 0.0);
    }

    double alpha = (center.dy - local.dy) / scale;
    double beta = (center.dx - local.dx) / scale;
    final double norm = sqrt(alpha * alpha + beta * beta);
    if (norm > 1.0) {
      alpha /= norm;
      beta /= norm;
    }

    return (alpha.clamp(-1.0, 1.0), beta.clamp(-1.0, 1.0));
  }

  void _handleTouch(Offset localPosition, Size size) {
    final (double alpha, double beta) = _toAlphaBeta(localPosition, size);
    onPositionChanged(alpha, beta);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) {
            _handleTouch(details.localPosition, size);
          },
          onPanStart: (DragStartDetails details) {
            _handleTouch(details.localPosition, size);
          },
          onPanUpdate: (DragUpdateDetails details) {
            _handleTouch(details.localPosition, size);
          },
          child: ColoredBox(
            color: const Color(0xFF0A0A0A),
            child: CustomPaint(
              size: Size.infinite,
              painter: ThreePhasePainter(
                alpha: smoothedAlpha,
                beta: smoothedBeta,
                active: active,
                isDark: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
