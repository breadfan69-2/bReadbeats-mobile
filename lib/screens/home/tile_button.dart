import 'package:flutter/material.dart';

import '../../widgets/neumorphic_tile.dart';

class HomeTileButton extends StatelessWidget {
  const HomeTileButton({
    required this.icon,
    required this.onPressed,
    this.size = 28,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    const double minTarget = 40;
    final double dimension = size > minTarget ? size : minTarget;
    return SizedBox(
      width: dimension,
      height: dimension,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: dimension, minHeight: dimension),
        iconSize: size,
        color: kAccentCyan,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
