import 'package:flutter/material.dart';

/// Phone-style battery icon: outline + proportional fill.
///
/// [soc] is 0.0–1.0 (state of charge).
/// Fill is green >= 10%, red < 10%.
/// When [charging] and [animateCharging], a green sweep grows left-to-right.
class BatteryIndicator extends StatefulWidget {
  const BatteryIndicator({
    super.key,
    required this.soc,
    this.charging = false,
    this.animateCharging = true,
    this.width = 28,
    this.height = 14,
  });

  final double soc;
  final bool charging;
  final bool animateCharging;
  final double width;
  final double height;

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  bool get _shouldAnimate => widget.charging && widget.animateCharging;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    if (_shouldAnimate) _controller.repeat();
  }

  @override
  void didUpdateWidget(BatteryIndicator old) {
    super.didUpdateWidget(old);
    final bool oldShouldAnimate = old.charging && old.animateCharging;
    if (_shouldAnimate != oldShouldAnimate) {
      if (_shouldAnimate) {
        _controller.repeat();
      } else {
        _controller
          ..stop()
          ..reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _BatteryPainter(
          soc: widget.soc.clamp(0.0, 1.0),
          chargeAnim: _shouldAnimate ? _controller.value : -1.0,
        ),
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter({required this.soc, required this.chargeAnim});

  final double soc;
  /// -1 means not charging. 0.0–1.0 is the animation progress (sawtooth).
  final double chargeAnim;

  @override
  void paint(Canvas canvas, Size size) {
    final nubWidth = size.width * 0.08;
    final bodyWidth = size.width - nubWidth;
    final bodyHeight = size.height;
    final radius = bodyHeight * 0.18;
    const strokeWidth = 1.5;

    // ── outline ──
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, bodyWidth, bodyHeight, Radius.circular(radius)),
      Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // ── nub (positive terminal) ──
    final nubHeight = bodyHeight * 0.4;
    final nubTop = (bodyHeight - nubHeight) / 2;
    canvas.drawRRect(
      RRect.fromLTRBR(
        bodyWidth - 0.5,
        nubTop,
        bodyWidth + nubWidth,
        nubTop + nubHeight,
        Radius.circular(nubWidth * 0.4),
      ),
      Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.fill,
    );

    // ── fill ──
    final inset = strokeWidth + 1.0;
    final fillMaxWidth = bodyWidth - inset * 2;
    final bool isChargingAnim = chargeAnim >= 0.0;

    if (isChargingAnim) {
      final double baseWidth = fillMaxWidth * soc;
      if (baseWidth > 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            inset,
            inset,
            inset + baseWidth,
            bodyHeight - inset,
            Radius.circular((radius - inset).clamp(0.5, radius)),
          ),
          Paint()..color = const Color(0xFF2E7D32),
        );
      }

      final double sweepWidth = fillMaxWidth * chargeAnim;
      if (sweepWidth > 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            inset,
            inset,
            inset + sweepWidth,
            bodyHeight - inset,
            Radius.circular((radius - inset).clamp(0.5, radius)),
          ),
          Paint()..color = const Color(0xFF4CAF50),
        );
      }
    } else {
      final double fillWidth = fillMaxWidth * soc;
      if (fillWidth > 0) {
        final Color fillColor = soc < 0.10
            ? const Color(0xFFE05260) // red – low battery
            : const Color(0xFF4CAF50); // green
        canvas.drawRRect(
          RRect.fromLTRBR(
            inset,
            inset,
            inset + fillWidth,
            bodyHeight - inset,
            Radius.circular((radius - inset).clamp(0.5, radius)),
          ),
          Paint()..color = fillColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BatteryPainter old) =>
      old.soc != soc || old.chargeAnim != chargeAnim;
}
