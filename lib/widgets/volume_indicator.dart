import 'package:flutter/material.dart';

/// Bar-graph volume indicator (signal-strength style, 7 bars).
///
/// [volume] is 0.0–1.0.  Bars grow in height from left to right.
/// The shortest bar is always lit when volume > 0.
/// Uses a lock icon when [locked] is true.
class VolumeIndicator extends StatelessWidget {
  const VolumeIndicator({
    super.key,
    required this.volume,
    this.locked = false,
    this.size = 18,
  });

  final double volume;
  final bool locked;
  final double size;

  static const int _barCount = 7;

  @override
  Widget build(BuildContext context) {
    final double clamped = volume.clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.volume_up,
          size: size,
          color: Colors.white70,
        ),
        const SizedBox(width: 4),
        _VolumeBars(volume: clamped, size: size, barCount: _barCount),
        if (locked) ...[
          const SizedBox(width: 3),
          Icon(
            Icons.lock,
            size: size * 0.65,
            color: const Color(0xFFF0A202),
          ),
        ],
      ],
    );
  }
}

class _VolumeBars extends StatelessWidget {
  const _VolumeBars({
    required this.volume,
    required this.size,
    required this.barCount,
  });

  final double volume;
  final double size;
  final int barCount;

  @override
  Widget build(BuildContext context) {
    final double maxHeight = size * 0.9;
    final double minHeight = maxHeight * 0.26;
    final double barWidth = size * 0.18;
    final double gap = size * 0.09;

    return SizedBox(
      height: maxHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (int i) {
          final double barHeight =
              minHeight + (maxHeight - minHeight) * i / (barCount - 1);
          // Shortest bar lights whenever volume is non-zero;
          // each subsequent bar lights when volume crosses its threshold.
          final bool active =
              i == 0 ? volume > 0.0 : volume >= i / (barCount - 1);
          return Container(
            width: barWidth,
            height: barHeight,
            margin: EdgeInsets.only(left: i == 0 ? 0.0 : gap),
            decoration: BoxDecoration(
              color: active ? Colors.white70 : Colors.white24,
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
