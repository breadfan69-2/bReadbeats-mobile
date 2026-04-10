import 'package:flutter/material.dart';

/// Base neumorphic surface color that works on the dark background.
const Color kNeumorphicBase = Color(0xFF1A1A2E);
const Color kNeumorphicDarker = Color(0xFF12121F);
const Color kNeumorphicLighter = Color(0xFF252540);
const Color kAccentCyan = Color(0xFF00AAFF);

/// Per-electrode colors matching the phase-position visualizer dots.
/// Index 0-3 = A, B, C, D (4-phase) or A, B, C (3-phase).
const List<Color> kElectrodeColors = <Color>[
  Color(0xFFFE2E2E), // A – red
  Color(0xFF5463FF), // B – blue
  Color(0xFFFFC717), // C – yellow
  Color(0xFF1F9E40), // D – green (4-phase only)
];

/// A neumorphic tile that uses layered BoxShadows for the soft-extrusion look.
///
/// [glowIntensity] drives a reactive cyan glow (0.0 = baseline, 1.0 = full).
/// Feed it a live beat/onset value for audio-reactive tiles.
class NeumorphicTile extends StatelessWidget {
  const NeumorphicTile({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.depth = 6.0,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(14),
    this.glowIntensity = 0.0,
    this.sunken = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double depth;
  final double borderRadius;
  final EdgeInsets padding;
  final double glowIntensity;

  /// When true the tile uses a darker background and inset shadow style,
  /// giving a "pushed-in" / recessed appearance (locked / app-controlled).
  ///
  /// This keeps the same fill color and only changes border/glow/shadow style.
  final bool sunken;

  @override
  Widget build(BuildContext context) {
    final double g = glowIntensity.clamp(0.0, 1.0);
    // Static baseline for all tiles; reactive layer adds on top
    final double borderAlpha = sunken ? 0.08 : 0.18 + g * 0.18;
    final double glowAlpha = sunken ? 0.0 : 0.06 + g * 0.12;
    final double glowSpread = sunken ? 0.0 : 1.0 + g * 2.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: kNeumorphicBase,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: kAccentCyan.withValues(alpha: borderAlpha),
            width: 1.0,
          ),
          boxShadow: sunken
              ? <BoxShadow>[
                  BoxShadow(
                    color: kNeumorphicDarker.withValues(alpha: 0.9),
                    offset: Offset(depth * 0.3, depth * 0.3),
                    blurRadius: depth * 0.5,
                  ),
                  BoxShadow(
                    color: kNeumorphicDarker.withValues(alpha: 0.6),
                    offset: Offset(-depth * 0.15, -depth * 0.15),
                    blurRadius: depth * 0.3,
                  ),
                ]
              : <BoxShadow>[
                  BoxShadow(
                    color: kNeumorphicLighter.withValues(alpha: 0.7),
                    offset: Offset(-depth * 0.5, -depth * 0.5),
                    blurRadius: depth,
                  ),
                  BoxShadow(
                    color: kNeumorphicDarker.withValues(alpha: 0.9),
                    offset: Offset(depth * 0.5, depth * 0.5),
                    blurRadius: depth,
                  ),
                  BoxShadow(
                    color: kAccentCyan.withValues(alpha: glowAlpha),
                    blurRadius: depth * 2 + g * 4,
                    spreadRadius: glowSpread,
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}
