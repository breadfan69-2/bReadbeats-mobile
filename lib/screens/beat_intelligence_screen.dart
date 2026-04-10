import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/connection_provider.dart';
import '../widgets/neumorphic_tile.dart';
import '../widgets/shared_widgets.dart';

class BeatIntelligenceScreen extends StatelessWidget {
  const BeatIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider c = context.watch<ConnectionProvider>();

    return DetailScreenScaffold(
      title: 'Beat Intelligence',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── Audio Interpretation ──────────────────────────────────────────
          NeumorphicTile(
            depth: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.graphic_eq, size: 18, color: kAccentCyan),
                    SizedBox(width: 8),
                    Text(
                      'AUDIO INTERPRETATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ToggleRow(
                  label: 'Tempo Hold',
                  subtitle: 'Coast on last BPM when tempo lock drops',
                  value: c.tempoUnlockHoldEnabled,
                  onChanged: c.setTempoUnlockHoldEnabled,
                ),
                _ToggleRow(
                  label: 'Adaptive Lead',
                  subtitle: 'Auto-correct phase timing from downbeat error',
                  value: c.adaptiveLeadEnabled,
                  onChanged: c.setAdaptiveLeadEnabled,
                ),
                _ToggleRow(
                  label: 'Hard Fill Gate',
                  subtitle: 'Force fill/creep while the audio gate is closed',
                  value: c.hardFillGateEnabled,
                  onChanged: c.setHardFillGateEnabled,
                ),
                const SizedBox(height: 4),
                LabeledSlider(
                  label: 'Energy Response',
                  value: c.energyResponseStrength,
                  min: 0.0,
                  max: 2.0,
                  divisions: 40,
                  onChanged: c.setEnergyResponseStrength,
                ),
                LabeledSlider(
                  label: 'Latency Offset (ms)',
                  value: c.latencyCompensationMs,
                  min: -100.0,
                  max: 100.0,
                  divisions: 200,
                  onChanged: c.setLatencyCompensationMs,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── ML Intelligence (beat mode only) ─────────────────────────────
          if (c.stimMode == StimMode.beat) ...<Widget>[
            NeumorphicTile(
              depth: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.psychology, size: 18, color: kAccentCyan),
                      SizedBox(width: 8),
                      Text(
                        'ML INTELLIGENCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    title: const Text('Intelligence Layer'),
                    subtitle: const Text(
                      'ML-guided cadence hints for beat orbit speed',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    value: c.learningEnabled,
                    onChanged: (bool v) => c.setLearningEnabled(v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (c.learningEnabled) ...<Widget>[
                    LabeledSlider(
                      label: 'Intelligence Influence',
                      value: c.learningStrength,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: c.setLearningStrength,
                      minTouchDuration: const Duration(milliseconds: 180),
                    ),
                    LabeledSlider(
                      label: 'Lead Correction Speed',
                      value: c.adaptiveLeadCorrectionGain,
                      min: 0.05,
                      max: 1.0,
                      divisions: 19,
                      onChanged: c.setAdaptiveLeadCorrectionGain,
                      minTouchDuration: const Duration(milliseconds: 180),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

// ── Private helper widgets ──────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: kAccentCyan,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
