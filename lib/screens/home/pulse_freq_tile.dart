import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/neumorphic_tile.dart';
import 'tile_button.dart';

class PulseFreqTile extends StatefulWidget {
  const PulseFreqTile({required this.onOpenDetail, super.key});

  final VoidCallback onOpenDetail;

  @override
  State<PulseFreqTile> createState() => _PulseFreqTileState();
}

class _PulseFreqTileState extends State<PulseFreqTile> {
  bool _locked = true;

  static const double _stepSmall = 1;
  static const double _stepLarge = 5;

  void _adjust(ConnectionProvider c, double delta) {
    if (_locked) return;
    final double next = c.manualPulseHz + delta;
    final double clamped = next.clamp(c.pulseMinHz, c.pulseMaxHz).toDouble();
    c.setManualPulseHz(next);
    Haptics.selection();
    if (clamped == c.pulseMinHz || clamped == c.pulseMaxHz) {
      Haptics.medium();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<
      ConnectionProvider,
      ({
        double pulseHz,
        double pulseMinHz,
        double pulseMaxHz,
        bool manualPulseMode,
      })
    >(
      selector: (_, ConnectionProvider c) => (
        pulseHz: c.manualPulseMode ? c.manualPulseHz : c.liveEffectivePulseHz,
        pulseMinHz: c.pulseMinHz,
        pulseMaxHz: c.pulseMaxHz,
        manualPulseMode: c.manualPulseMode,
      ),
      builder: (_, data, _) {
        final bool isManual = data.manualPulseMode;
        final bool unlocked = !_locked && isManual;
        final bool isSunken = !unlocked;
        return NeumorphicTile(
          depth: 5,
          sunken: isSunken,
          glowIntensity: unlocked ? 0.35 : 0.0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (isManual)
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
                        color: _locked ? Colors.redAccent : Colors.amberAccent,
                      ),
                    )
                  else
                    const Icon(
                      Icons.music_note,
                      size: 18,
                      color: Colors.white38,
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isManual ? 'PULSE FREQ' : 'PULSE (auto)',
                      style: const TextStyle(
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
                  '${data.pulseHz.toStringAsFixed(1)} Hz',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ),
              if (isManual) ...<Widget>[
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
                      onTap: () => _adjust(
                        context.read<ConnectionProvider>(),
                        _stepSmall,
                      ),
                    ),
                    _StepButton(
                      label: '+${_stepLarge.toInt()}',
                      enabled: unlocked,
                      onTap: () => _adjust(
                        context.read<ConnectionProvider>(),
                        _stepLarge,
                      ),
                    ),
                  ],
                ),
              ],
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
                ? Colors.amberAccent.withValues(alpha: 0.3)
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
