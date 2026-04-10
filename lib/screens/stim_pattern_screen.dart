import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_models.dart';
import '../models/enums.dart';
import '../providers/connection_provider.dart';
import '../widgets/shared_widgets.dart';

class StimPatternScreen extends StatefulWidget {
  const StimPatternScreen({super.key});

  @override
  State<StimPatternScreen> createState() => _StimPatternScreenState();
}

class _StimPatternScreenState extends State<StimPatternScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-stop any running session when this screen opens — the user is
    // about to change mode settings which are incompatible mid-session.
    final ConnectionProvider c = context.read<ConnectionProvider>();
    if (c.sessionRunning) {
      c.stopSession(emitHaptic: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return DetailScreenScaffold(
      title: 'Stim Pattern',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (connection.buttonHoldMuted) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.error.withValues(alpha: 0.55)),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.volume_up,
                          size: 18,
                          color: scheme.onErrorContainer,
                        ),
                        Icon(
                          Icons.not_interested,
                          size: 22,
                          color: scheme.error,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Muted By FOC Device - Long Press Knob to Resume',
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // ── Mode selectors ──
          Text(
            'Output Mode',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          SegmentedButton<OutputModeSelection>(
            segments: const <ButtonSegment<OutputModeSelection>>[
              ButtonSegment<OutputModeSelection>(
                value: OutputModeSelection.threePhase,
                label: Text('3-Phase'),
              ),
              ButtonSegment<OutputModeSelection>(
                value: OutputModeSelection.fourPhase,
                label: Text('4-Phase'),
              ),
            ],
            selected: <OutputModeSelection>{connection.outputMode},
            onSelectionChanged: (Set<OutputModeSelection> selected) async {
              if (selected.isEmpty) {
                return;
              }
              await connection.setOutputMode(selected.first);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Stim Mode',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          SegmentedButton<StimMode>(
            segments: const <ButtonSegment<StimMode>>[
              ButtonSegment<StimMode>(
                value: StimMode.beat,
                label: Text('Beat'),
                icon: Icon(Icons.music_note),
              ),
              ButtonSegment<StimMode>(
                value: StimMode.onset,
                label: Text('Onset'),
                icon: Icon(Icons.waves),
              ),
            ],
            selected: <StimMode>{connection.stimMode},
            onSelectionChanged: (Set<StimMode> selected) async {
              if (selected.isEmpty) {
                return;
              }
              await connection.setStimMode(selected.first);
            },
          ),
          if (connection.outputMode == OutputModeSelection.fourPhase &&
              connection.stimMode == StimMode.onset) ...<Widget>[
            const SizedBox(height: 16),
            const _OnsetBandMappingSection(),
          ],
          // ── 4P beat controls ──
          if (connection.stimMode == StimMode.beat) ...<Widget>[
            if (connection.outputMode ==
                OutputModeSelection.fourPhase) ...<Widget>[
              const SizedBox(height: 12),
              LabeledSlider(
                label: '4P Radius Contrast',
                value: connection.beatRadiusAwareContrastStrength,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: connection.setBeatRadiusAwareContrastStrength,
                minTouchDuration: const Duration(milliseconds: 180),
              ),
              LabeledSlider(
                label: '4P Speed Spread',
                value: connection.beatSpeedThresholdSpreadStrength,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: connection.setBeatSpeedThresholdSpreadStrength,
                minTouchDuration: const Duration(milliseconds: 180),
              ),
              const SizedBox(height: 8),
              const _FourPhaseBeatResponseCurveSection(),
            ],
          ],
          const SizedBox(height: 24),

          // ── START / STOP ──
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: !connection.sessionRunning
                  ? () async {
                      try {
                        await connection.startSession();
                      } catch (error, stackTrace) {
                        debugPrint(
                          '[StimPatternScreen] startSession failed: '
                          '$error\n$stackTrace',
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              connection.lastError ?? 'Could not start session',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('START', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: connection.sessionRunning
                  ? () async {
                      await connection.stopSession();
                    }
                  : null,
              icon: const Icon(Icons.stop),
              label: const Text('STOP', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 24),

          // ── Electrode bars visibility toggle ──
          SwitchListTile(
            title: const Text('Show electrode bars on tile'),
            subtitle: const Text(
              'Mini intensity bars on the home screen session tile',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            value: connection.showElectrodeBars,
            onChanged: (_) => connection.toggleShowElectrodeBars(),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),

          // ── Output meters ──
          Text(
            'Output',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            connection.outputMode == OutputModeSelection.fourPhase
                ? 'Live 4-electrode intensity meter'
                : 'Live 3-electrode intensity meter',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ElectrodeIntensityMeter(
            levels: connection.visibleElectrodeLevels,
            labels: connection.visibleElectrodeLabels,
            active: connection.audioMotionActive,
          ),
        ],
      ),
    );
  }
}

class _FourPhaseBeatResponseCurveSection extends StatelessWidget {
  const _FourPhaseBeatResponseCurveSection();

  static const List<String> _electrodeLabels = <String>['A', 'B', 'C', 'D'];

  static const List<ButtonSegment<BeatResponseCurve>> _curveSegments =
      <ButtonSegment<BeatResponseCurve>>[
        ButtonSegment<BeatResponseCurve>(
          value: BeatResponseCurve.linear,
          label: Text('Linear'),
        ),
        ButtonSegment<BeatResponseCurve>(
          value: BeatResponseCurve.ease,
          label: Text('Ease'),
        ),
        ButtonSegment<BeatResponseCurve>(
          value: BeatResponseCurve.bell,
          label: Text('Bell'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<BeatResponseCurve> curves =
        connection.beatFourPhaseResponseCurves;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '4P Electrode Curves',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 4),
        const Text(
          'Per-electrode response shaping presets for beat orbit.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < 4; i++) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 26,
                child: Text(
                  _electrodeLabels[i],
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: SegmentedButton<BeatResponseCurve>(
                  segments: _curveSegments,
                  selected: <BeatResponseCurve>{
                    i < curves.length ? curves[i] : BeatResponseCurve.linear,
                  },
                  onSelectionChanged: (Set<BeatResponseCurve> selected) {
                    if (selected.isEmpty) {
                      return;
                    }
                    connection.setBeatFourPhaseResponseCurve(i, selected.first);
                  },
                ),
              ),
            ],
          ),
          if (i < 3) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _OnsetBandMappingSection extends StatelessWidget {
  const _OnsetBandMappingSection();

  static const List<String> _electrodeLabels = <String>['A', 'B', 'C', 'D'];

  static const List<(AudioBand, String)> _bandOptions = <(AudioBand, String)>[
    (AudioBand.subBass, 'Sub'),
    (AudioBand.bass, 'Bass'),
    (AudioBand.lowMid, 'Lo-Mid'),
    (AudioBand.mid, 'Mid'),
    (AudioBand.upperMid, 'Hi-Mid'),
    (AudioBand.presence, 'Presence'),
    (AudioBand.brilliance, 'Brilliance'),
  ];

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<List<AudioBand>> mapping = connection.onsetBandMapping;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Onset Band Mapping',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          'Select 1–3 frequency bands per electrode.',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < 4; i++) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 26,
                child: Text(
                  _electrodeLabels[i],
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final (AudioBand band, String label) in _bandOptions)
                      _BandChip(
                        label: label,
                        selected: mapping[i].contains(band),
                        onTap: () {
                          final List<List<AudioBand>> next = mapping
                              .map(
                                (List<AudioBand> electrodeBands) =>
                                    List<AudioBand>.from(electrodeBands),
                              )
                              .toList();

                          final bool isSelected = next[i].contains(band);
                          if (isSelected) {
                            if (next[i].length <= 1) {
                              return;
                            }
                            next[i].remove(band);
                          } else {
                            if (next[i].length >= 3) {
                              return;
                            }
                            next[i].add(band);
                          }

                          connection.setOnsetBandMapping(next);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (i < 3) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimaryContainer : Colors.white70,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}
