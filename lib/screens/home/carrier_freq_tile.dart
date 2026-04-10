import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/neumorphic_tile.dart';
import 'tile_button.dart';

class CarrierFreqTile extends StatefulWidget {
  const CarrierFreqTile({required this.onOpenDetail, super.key});

  final VoidCallback onOpenDetail;

  @override
  State<CarrierFreqTile> createState() => _CarrierFreqTileState();
}

class _CarrierFreqTileState extends State<CarrierFreqTile> {
  bool _locked = true;

  static const double _stepSmall = 10;
  static const double _stepLarge = 50;

  void _adjust(ConnectionProvider c, double delta) {
    if (_locked) return;
    final double next = c.carrierHz + delta;
    final double clamped = next
        .clamp(c.carrierMinHz, c.carrierMaxHz)
        .toDouble();
    c.setCarrierHz(next);
    Haptics.selection();
    if (clamped == c.carrierMinHz || clamped == c.carrierMaxHz) {
      Haptics.medium();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<
      ConnectionProvider,
      ({double carrierHz, double carrierMinHz, double carrierMaxHz})
    >(
      selector: (_, ConnectionProvider c) => (
        carrierHz: c.carrierHz,
        carrierMinHz: c.carrierMinHz,
        carrierMaxHz: c.carrierMaxHz,
      ),
      builder: (_, data, _) {
        final bool unlocked = !_locked;
        return NeumorphicTile(
          depth: 5,
          sunken: _locked,
          glowIntensity: unlocked ? 0.35 : 0.0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () {
                      setState(() => _locked = !_locked);
                      if (_locked) {
                        Haptics.medium();
                      } else {
                        Haptics.light();
                      }
                    },
                    child: Icon(
                      _locked ? Icons.lock : Icons.electric_bolt,
                      size: 18,
                      color: _locked ? Colors.redAccent : kAccentCyan,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'CARRIER FREQ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  HomeTileButton(
                    icon: Icons.more_horiz,
                    size: 18,
                    onPressed: widget.onOpenDetail,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '${data.carrierHz.toStringAsFixed(0)} Hz',
                  style: const TextStyle(
                    color: kAccentCyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _StepButton(
                    label: '−${_stepLarge.toInt()}',
                    enabled: unlocked,
                    onTap: () => _adjust(
                      context.read<ConnectionProvider>(),
                      -_stepLarge,
                    ),
                  ),
                  _StepButton(
                    label: '−${_stepSmall.toInt()}',
                    enabled: unlocked,
                    onTap: () => _adjust(
                      context.read<ConnectionProvider>(),
                      -_stepSmall,
                    ),
                  ),
                  _StepButton(
                    label: '+${_stepSmall.toInt()}',
                    enabled: unlocked,
                    onTap: () =>
                        _adjust(context.read<ConnectionProvider>(), _stepSmall),
                  ),
                  _StepButton(
                    label: '+${_stepLarge.toInt()}',
                    enabled: unlocked,
                    onTap: () =>
                        _adjust(context.read<ConnectionProvider>(), _stepLarge),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: enabled ? kNeumorphicLighter : kNeumorphicDarker,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? kAccentCyan.withValues(alpha: 0.3)
                : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white24,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
