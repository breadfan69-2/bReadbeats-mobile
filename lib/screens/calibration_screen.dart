import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_models.dart';
import '../models/enums.dart';
import '../providers/connection_provider.dart';
import '../widgets/neumorphic_tile.dart';
import '../widgets/phase_visualizer.dart';
import '../widgets/shared_widgets.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const Duration _sliderMinTouchDuration = Duration(milliseconds: 180);

  static const Map<CalibrationPattern, String> _pattern3Labels =
      <CalibrationPattern, String>{
        CalibrationPattern.none: 'None',
        CalibrationPattern.circle: 'Circle (CW)',
        CalibrationPattern.circleReverse: 'Circle (CCW)',
      };

  static const Map<CalibrationPattern, String> _pattern4Labels =
      <CalibrationPattern, String>{
        CalibrationPattern.none: 'None',
        CalibrationPattern.sequential1234: '1→2→3→4',
        CalibrationPattern.sequential4321: '4→3→2→1',
      };

  static const double _patternSpeedUiToRpsScale = 0.25;
  static const double _patternSpeedUiMin = 0.2;
  static const double _patternSpeedUiMax = 20.0;

  List<double> _impedanceValues(
    ConnectionProvider connection,
    bool isFourPhase,
  ) {
    final List<double> skin = <double>[
      connection.telemetrySkinResistanceA,
      connection.telemetrySkinResistanceB,
      connection.telemetrySkinResistanceC,
      connection.telemetrySkinResistanceD,
    ];
    final List<double> output = <double>[
      connection.telemetryOutputResistanceA,
      connection.telemetryOutputResistanceB,
      connection.telemetryOutputResistanceC,
      connection.telemetryOutputResistanceD,
    ];
    final double constant = connection.telemetryOutputResistanceConstant;
    final int count = isFourPhase ? 4 : 3;

    return List<double>.generate(count, (int index) {
      final double skinValue = skin[index];
      if (skinValue > 0.0) {
        return skinValue;
      }

      final double outputValue = output[index];
      if (outputValue <= 0.0) {
        return 0.0;
      }
      if (constant > 0.0 && outputValue > constant) {
        return (outputValue - constant).clamp(0.0, outputValue).toDouble();
      }
      return outputValue;
    }, growable: false);
  }

  String _formatImpedance(double value) {
    if (!value.isFinite || value <= 0.0) {
      return '--';
    }
    return '${value.toStringAsFixed(0)} Ω';
  }

  double _patternSpeedUiValue(ConnectionProvider connection) {
    return (connection.calibrationPatternSpeed / _patternSpeedUiToRpsScale)
        .clamp(_patternSpeedUiMin, _patternSpeedUiMax)
        .toDouble();
  }

  void _setPatternSpeedFromUi(ConnectionProvider connection, double uiValue) {
    connection.setCalibrationPatternSpeed(uiValue * _patternSpeedUiToRpsScale);
  }

  Widget _buildElectrodeIntensityBars(
    List<double> electrodeLevels,
    List<String> electrodeLabels,
    List<double> impedanceValues,
  ) {
    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(electrodeLevels.length, (int i) {
          final double level = electrodeLevels[i].clamp(0.0, 1.0).toDouble();
          final String label = electrodeLabels[i];
          final String impedance =
              i < impedanceValues.length
              ? _formatImpedance(impedanceValues[i])
              : '--';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: <Widget>[
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  height: constraints.maxHeight * level,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: kElectrodeColors[i],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: kElectrodeColors[i],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    impedance,
                    style: TextStyle(
                      color: kElectrodeColors[i].withValues(alpha: 0.75),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();
    final bool is4 = connection.outputMode == OutputModeSelection.fourPhase;
    final List<String> electrodeLabels = connection.visibleElectrodeLabels;
    final List<double> impedanceValues = _impedanceValues(connection, is4);
    final Map<CalibrationPattern, String> patternLabels = is4
        ? _pattern4Labels
        : _pattern3Labels;
    // If current pattern isn't valid for this mode, show none.
    final CalibrationPattern activePattern =
        patternLabels.containsKey(connection.calibrationPattern)
        ? connection.calibrationPattern
        : CalibrationPattern.none;
    final double speedUiValue = _patternSpeedUiValue(connection);

    return DetailScreenScaffold(
      title: connection.outputMode == OutputModeSelection.threePhase
          ? '3-Phase Calibration'
          : '4-Phase Calibration',
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: <Widget>[
                  // ── Phase visualizer ──
                  PhasePositionVisualizer(
                    isFourPhase:
                        connection.outputMode == OutputModeSelection.fourPhase,
                    animate:
                        connection.captureRunning ||
                        connection.calibrationPattern !=
                            CalibrationPattern.none,
                    alpha: connection.positionAlpha,
                    beta: connection.positionBeta,
                    gamma: connection.positionGamma,
                    electrodeLevels: connection.visibleElectrodeLevels,
                    active:
                        connection.audioMotionActive ||
                        connection.calibrationPattern !=
                            CalibrationPattern.none,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedElectrodeBarsHeaderDelegate(
              child: _buildElectrodeIntensityBars(
                connection.visibleElectrodeLevels,
                electrodeLabels,
                impedanceValues,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: <Widget>[
                  const Divider(),

                  // ── Output mode selector ──
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
                    onSelectionChanged:
                        (Set<OutputModeSelection> selected) async {
                          if (selected.isEmpty) return;
                          await connection.setOutputMode(selected.first);
                        },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  // ── Test pattern selector ──
                  const Text(
                    'Test Pattern',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: patternLabels.entries.map((
                      MapEntry<CalibrationPattern, String> e,
                    ) {
                      final bool selected = activePattern == e.key;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: selected,
                        selectedColor: kAccentCyan.withValues(alpha: 0.25),
                        backgroundColor: kNeumorphicLighter,
                        labelStyle: TextStyle(
                          color: selected ? kAccentCyan : Colors.white60,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: selected
                              ? kAccentCyan.withValues(alpha: 0.5)
                              : Colors.white12,
                        ),
                        onSelected: (_) {
                          if (e.key != CalibrationPattern.none &&
                              connection.captureRunning &&
                              connection.sessionRunning) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Calibration pattern unavailable while music capture is active',
                                ),
                              ),
                            );
                            return;
                          }
                          connection.setCalibrationPattern(e.key);
                        },
                      );
                    }).toList(),
                  ),
                  if (activePattern != CalibrationPattern.none) ...<Widget>[
                    const SizedBox(height: 8),
                    LabeledSlider(
                      label: 'Speed (${speedUiValue.toStringAsFixed(2)}×)',
                      value: speedUiValue,
                      min: _patternSpeedUiMin,
                      max: _patternSpeedUiMax,
                      divisions: 198,
                      minTouchDuration: _sliderMinTouchDuration,
                      onChanged: (double uiValue) {
                        _setPatternSpeedFromUi(connection, uiValue);
                      },
                    ),
                  ],
                  const Divider(),

                  // ── Electrode calibration sliders ──
                  if (connection.outputMode ==
                      OutputModeSelection.threePhase) ...<Widget>[
                    LabeledSlider(
                      label: 'Electrode ${electrodeLabels[0]} (dB)',
                      value: connection.cal3A,
                      min: -6.0,
                      max: 6.0,
                      divisions: 120,
                      minTouchDuration: _sliderMinTouchDuration,
                      onChanged: connection.setCal3A,
                    ),
                    LabeledSlider(
                      label: 'Electrode ${electrodeLabels[1]} (dB)',
                      value: connection.cal3B,
                      min: -6.0,
                      max: 6.0,
                      divisions: 120,
                      minTouchDuration: _sliderMinTouchDuration,
                      onChanged: connection.setCal3B,
                    ),
                    LabeledSlider(
                      label: 'Electrode ${electrodeLabels[2]} (dB)',
                      value: connection.cal3C,
                      min: -6.0,
                      max: 0.0,
                      divisions: 60,
                      minTouchDuration: _sliderMinTouchDuration,
                      onChanged: connection.setCal3C,
                    ),
                  ] else ...<Widget>[
                    LabeledSlider(
                      label: 'Electrode A (dB)',
                      value: connection.cal4A,
                      min: -6.0,
                      max: 6.0,
                      divisions: 120,
                      minTouchDuration: _sliderMinTouchDuration,
                      onChanged: connection.setCal4A,
                    ),
                    LabeledSlider(
                      label: 'Electrode B (dB)',
                      value: connection.cal4B,
                      min: -6.0,
                      max: 6.0,
                      divisions: 120,
                      minTouchDuration: _sliderMinTouchDuration,
                      onChanged: connection.setCal4B,
                    ),
                    LabeledSlider(
                      label: 'Electrode C (dB)',
                      value: connection.cal4C,
                      min: -6.0,
                      max: 6.0,
                      divisions: 120,
                      minTouchDuration: _sliderMinTouchDuration,
                      onChanged: connection.setCal4C,
                    ),
                    LabeledSlider(
                      label: 'Electrode D (dB)',
                      value: connection.cal4D,
                      min: -6.0,
                      max: 6.0,
                      divisions: 120,
                      minTouchDuration: _sliderMinTouchDuration,
                      onChanged: connection.setCal4D,
                    ),
                  ],
                  const Divider(),

                  // ── Carrier frequency range ──
                  LabeledRangeSlider(
                    label: 'Carrier Freq Range (Hz)',
                    values: RangeValues(
                      connection.carrierMinHz,
                      connection.carrierMaxHz,
                    ),
                    min: 300.0,
                    max: 2000.0,
                    divisions: 170,
                    minTouchDuration: _sliderMinTouchDuration,
                    onChanged: (RangeValues v) {
                      connection.setCarrierRange(v.start, v.end);
                    },
                  ),
                  const Divider(),

                  // ── Intensity cap ──
                  LabeledSlider(
                    label: 'Intensity Cap',
                    value: connection.intensityCap,
                    min: 0.0,
                    max: 100.0,
                    divisions: 100,
                    minTouchDuration: _sliderMinTouchDuration,
                    onChanged: connection.setIntensityCap,
                  ),
                  const Divider(),

                  LabeledSlider(
                    label: 'Tau (μs)',
                    value: connection.tauMicros,
                    min: 0.0,
                    max: 1000.0,
                    divisions: 200,
                    minTouchDuration: _sliderMinTouchDuration,
                    onChanged: connection.setTauMicros,
                  ),
                  if (connection.telemetryOutputResistanceConstant >
                      0.0) ...<Widget>[
                    const Divider(),
                    Text(
                      'Output stage constant: '
                      '${connection.telemetryOutputResistanceConstant.toStringAsFixed(0)} Ω',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedElectrodeBarsHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  _PinnedElectrodeBarsHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 80;

  @override
  double get maxExtent => 80;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: const Color(0xFF1A1A2E),
      elevation: overlapsContent ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedElectrodeBarsHeaderDelegate oldDelegate) {
    return true;
  }
}
