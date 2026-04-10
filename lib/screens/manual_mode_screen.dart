import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/haptics.dart';
import '../models/device_models.dart';
import '../models/enums.dart';
import '../providers/connection_provider.dart';
import '../widgets/manual_four_phase_pad.dart';
import '../widgets/manual_three_phase_pad.dart';
import '../widgets/neumorphic_tile.dart';
import '../widgets/rotary_dial.dart';
import 'calibration_screen.dart';
import 'home_screen.dart';

class ManualModeScreen extends StatefulWidget {
  const ManualModeScreen({super.key});

  @override
  State<ManualModeScreen> createState() => _ManualModeScreenState();
}

class _ManualModeScreenState extends State<ManualModeScreen> {
  bool _intensityLocked = false;
  int _intensityBoundaryEdge = 0;
  int _dAxisBoundaryEdge = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_enterManualMode());
  }

  Future<void> _setManualChrome() async {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _setDefaultChrome() async {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _enterManualMode() async {
    await _setManualChrome();
    if (!mounted) {
      return;
    }
    final ConnectionProvider connection = context.read<ConnectionProvider>();
    connection.setCalibrationPattern(CalibrationPattern.manual);
    connection.setManualPaused(true);
  }

  Future<void> _exitToHome() async {
    if (!mounted) {
      return;
    }
    context.read<ConnectionProvider>().setManualPaused(true);
    await _setDefaultChrome();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _openCalibration() async {
    final ConnectionProvider connection = context.read<ConnectionProvider>();
    connection.setManualPaused(true);
    connection.setCalibrationPattern(CalibrationPattern.none);

    await _setDefaultChrome();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CalibrationScreen()),
    );

    if (!mounted) {
      return;
    }

    await _setManualChrome();
    if (!mounted) {
      return;
    }
    connection.setCalibrationPattern(CalibrationPattern.manual);
    connection.setManualPaused(true);
  }

  @override
  void dispose() {
    final ConnectionProvider connection = context.read<ConnectionProvider>();
    connection.setManualPaused(true);
    connection.setCalibrationPattern(CalibrationPattern.none);
    unawaited(_setDefaultChrome());
    super.dispose();
  }

  Widget _buildPlayStopButton({
    required bool manualPaused,
    required VoidCallback onPressed,
  }) {
    final bool playMode = manualPaused;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        playMode ? Icons.play_arrow_rounded : Icons.stop_rounded,
        size: 18,
      ),
      label: Text(
        playMode ? 'Play' : 'Stop',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: playMode ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        minimumSize: const Size(108, 34),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
    );
  }

  Widget _buildMiniDial({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required double detentStep,
    required ValueChanged<double> onChanged,
  }) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          const SizedBox(height: 2),
          RotaryDial(
            value: value,
            min: min,
            max: max,
            detentStep: detentStep,
            onChanged: onChanged,
            size: 42,
          ),
          const SizedBox(height: 2),
          Text(
            valueText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyDialGroup({
    required String title,
    required bool locked,
    required VoidCallback onToggleLock,
    required double value,
    required String valueText,
    required double min,
    required double max,
    required double detentStep,
    required ValueChanged<double>? onChanged,
    required bool lfoEnabled,
    required ValueChanged<bool> onLfoEnabledChanged,
    required double lfoRateHz,
    required ValueChanged<double> onLfoRateChanged,
    required double lfoDepth,
    required ValueChanged<double> onLfoDepthChanged,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kNeumorphicBase.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 20,
                    height: 20,
                  ),
                  icon: Icon(
                    locked ? Icons.lock : Icons.lock_open,
                    color: locked ? Colors.white70 : kAccentCyan,
                    size: 15,
                  ),
                  onPressed: onToggleLock,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Opacity(
              opacity: locked ? 0.4 : 1.0,
              child: Column(
                children: <Widget>[
                  RotaryDial(
                    value: value,
                    min: min,
                    max: max,
                    detentStep: detentStep,
                    onLockedDragStart: locked ? Haptics.medium : null,
                    onChanged: onChanged,
                    size: 60,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valueText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                const Text(
                  'LFO',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Transform.scale(
                  scale: 0.78,
                  child: Switch(
                    value: lfoEnabled,
                    onChanged: onLfoEnabledChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                _buildMiniDial(
                  label: 'Rate',
                  valueText: '${lfoRateHz.toStringAsFixed(2)} Hz',
                  value: lfoRateHz,
                  min: 0.05,
                  max: 10.0,
                  detentStep: 0.5,
                  onChanged: onLfoRateChanged,
                ),
                const SizedBox(width: 6),
                _buildMiniDial(
                  label: 'Depth',
                  valueText: lfoDepth.toStringAsFixed(2),
                  value: lfoDepth,
                  min: 0.0,
                  max: 1.0,
                  detentStep: 0.05,
                  onChanged: onLfoDepthChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntensityPanel({
    required double manualIntensity,
    required double manualIntensityRamp,
    required ConnectionProvider connection,
    double width = 60.0,
  }) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: kNeumorphicLighter,
          border: Border(left: BorderSide(color: Colors.white12, width: 0.8)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'INTENSITY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${manualIntensity.toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                '→${(manualIntensityRamp * manualIntensity).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white54, fontSize: 9),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Opacity(
                  opacity: _intensityLocked ? 0.4 : 1.0,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: manualIntensity.clamp(0.0, 100.0),
                      min: 0.0,
                      max: 100.0,
                      onChanged: _intensityLocked
                          ? null
                          : (double value) {
                              final int edge = value <= 0.0
                                  ? -1
                                  : (value >= 100.0 ? 1 : 0);
                              if (edge != 0 && edge != _intensityBoundaryEdge) {
                                Haptics.medium();
                              }
                              _intensityBoundaryEdge = edge;
                              connection.setManualIntensity(value);
                            },
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  _intensityLocked ? Icons.lock : Icons.lock_open,
                  color: _intensityLocked ? Colors.white70 : kAccentCyan,
                  size: 17,
                ),
                onPressed: () => setState(() {
                  _intensityLocked = !_intensityLocked;
                  if (_intensityLocked) {
                    Haptics.medium();
                  } else {
                    Haptics.light();
                  }
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDAxisPanel({
    required double targetE4,
    required ConnectionProvider connection,
    double width = 60.0,
  }) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: kNeumorphicLighter,
          border: Border(right: BorderSide(color: Colors.white12, width: 0.8)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'D AXIS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                targetE4.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    value: targetE4.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    onChanged: (double v) {
                      final int edge = v <= 0.0 ? -1 : (v >= 1.0 ? 1 : 0);
                      if (edge != 0 && edge != _dAxisBoundaryEdge) {
                        Haptics.medium();
                      }
                      _dAxisBoundaryEdge = edge;
                      connection.setManualDAxis(v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNeumorphicBase,
      body: SafeArea(
        child:
            Selector<
              ConnectionProvider,
              ({
                OutputModeSelection outputMode,
                double smoothedAlpha,
                double smoothedBeta,
                double smoothedE1,
                double smoothedE2,
                double smoothedE3,
                double smoothedE4,
                double targetE4,
                double userE4,
                bool manualPaused,
                double manualIntensity,
                double manualIntensityRamp,
                double carrierHz,
                double carrierMinHz,
                double carrierMaxHz,
                double pulseHz,
                double pulseMinHz,
                double pulseMaxHz,
                bool carrierLocked,
                bool pulseLocked,
                bool carrierLfoEnabled,
                double carrierLfoRateHz,
                double carrierLfoDepth,
                bool pulseLfoEnabled,
                double pulseLfoRateHz,
                double pulseLfoDepth,
                double effectiveCarrierHz,
                double effectivePulseHz,
              })
            >(
              selector: (_, ConnectionProvider c) => (
                outputMode: c.outputMode,
                smoothedAlpha: c.manualSmoothedAlpha,
                smoothedBeta: c.manualSmoothedBeta,
                smoothedE1: c.manualSmoothedE1,
                smoothedE2: c.manualSmoothedE2,
                smoothedE3: c.manualSmoothedE3,
                smoothedE4: c.manualSmoothedE4,
                targetE4: c.manualTargetE4,
                userE4: c.manualUserE4,
                manualPaused: c.manualPaused,
                manualIntensity: c.manualIntensity,
                manualIntensityRamp: c.manualIntensityRamp,
                carrierHz: c.carrierHz,
                carrierMinHz: c.carrierMinHz,
                carrierMaxHz: c.carrierMaxHz,
                pulseHz: c.manualPulseHz,
                pulseMinHz: c.pulseMinHz,
                pulseMaxHz: c.pulseMaxHz,
                carrierLocked: c.carrierLocked,
                pulseLocked: c.pulseLocked,
                carrierLfoEnabled: c.carrierLfoEnabled,
                carrierLfoRateHz: c.carrierLfoRateHz,
                carrierLfoDepth: c.carrierLfoDepth,
                pulseLfoEnabled: c.pulseLfoEnabled,
                pulseLfoRateHz: c.pulseLfoRateHz,
                pulseLfoDepth: c.pulseLfoDepth,
                effectiveCarrierHz: c.manualEffectiveCarrierHz,
                effectivePulseHz: c.manualEffectivePulseHz,
              ),
              builder: (_, data, _) {
                final ConnectionProvider connection = context
                    .read<ConnectionProvider>();
                final bool isFourPhase =
                    data.outputMode == OutputModeSelection.fourPhase;
                final bool active = !data.manualPaused;

                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    const double sidePanelWidth = 60.0;
                    const double minControlPanelWidth = 296.0;
                    const double minPadWidth = 220.0;

                    final double reservedSideWidth =
                        sidePanelWidth + (isFourPhase ? sidePanelWidth : 0.0);
                    final double availableMainWidth = math.max(
                      0.0,
                      constraints.maxWidth - reservedSideWidth,
                    );

                    final double maxPadByScreen = constraints.maxWidth * 0.5;
                    double padWidth = availableMainWidth - minControlPanelWidth;
                    padWidth = math.max(minPadWidth, padWidth);
                    padWidth = math.min(padWidth, maxPadByScreen);
                    padWidth = math.min(padWidth, availableMainWidth);

                    final double controlPanelWidth = math.max(
                      0.0,
                      availableMainWidth - padWidth,
                    );

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (isFourPhase)
                          _buildDAxisPanel(
                            targetE4: data.targetE4,
                            connection: connection,
                            width: sidePanelWidth,
                          ),

                        SizedBox(
                          width: controlPanelWidth,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: kNeumorphicLighter,
                              border: Border(
                                right: BorderSide(
                                  color: Colors.white12,
                                  width: 0.8,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      _buildPlayStopButton(
                                        manualPaused: data.manualPaused,
                                        onPressed: () {
                                          Haptics.medium();
                                          connection.setManualPaused(
                                            !data.manualPaused,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child:
                                            SegmentedButton<
                                              OutputModeSelection
                                            >(
                                              segments:
                                                  const <
                                                    ButtonSegment<
                                                      OutputModeSelection
                                                    >
                                                  >[
                                                    ButtonSegment<
                                                      OutputModeSelection
                                                    >(
                                                      value: OutputModeSelection
                                                          .threePhase,
                                                      label: Text('3P'),
                                                    ),
                                                    ButtonSegment<
                                                      OutputModeSelection
                                                    >(
                                                      value: OutputModeSelection
                                                          .fourPhase,
                                                      label: Text('4P'),
                                                    ),
                                                  ],
                                              selected: <OutputModeSelection>{
                                                data.outputMode,
                                              },
                                              onSelectionChanged:
                                                  (
                                                    Set<OutputModeSelection>
                                                    selected,
                                                  ) {
                                                    connection.setManualPaused(
                                                      true,
                                                    );
                                                    unawaited(
                                                      connection.setOutputMode(
                                                        selected.first,
                                                      ),
                                                    );
                                                  },
                                              style: SegmentedButton.styleFrom(
                                                textStyle: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: _buildFrequencyDialGroup(
                                            title: 'Carrier',
                                            locked: data.carrierLocked,
                                            onToggleLock: () {
                                              connection.setCarrierLocked(
                                                !data.carrierLocked,
                                              );
                                            },
                                            value: data.carrierHz,
                                            valueText:
                                                '${data.effectiveCarrierHz.toStringAsFixed(1)} Hz',
                                            min: data.carrierMinHz,
                                            max: data.carrierMaxHz,
                                            detentStep: 25.0,
                                            onChanged: data.carrierLocked
                                                ? null
                                                : connection.setCarrierHz,
                                            lfoEnabled: data.carrierLfoEnabled,
                                            onLfoEnabledChanged:
                                                (bool enabled) {
                                                  Haptics.selection();
                                                  connection.setCarrierLfo(
                                                    enabled: enabled,
                                                    rateHz:
                                                        data.carrierLfoRateHz,
                                                    depth: data.carrierLfoDepth,
                                                  );
                                                },
                                            lfoRateHz: data.carrierLfoRateHz,
                                            onLfoRateChanged: (double value) {
                                              connection.setCarrierLfo(
                                                enabled: data.carrierLfoEnabled,
                                                rateHz: value,
                                                depth: data.carrierLfoDepth,
                                              );
                                            },
                                            lfoDepth: data.carrierLfoDepth,
                                            onLfoDepthChanged: (double value) {
                                              connection.setCarrierLfo(
                                                enabled: data.carrierLfoEnabled,
                                                rateHz: data.carrierLfoRateHz,
                                                depth: value,
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildFrequencyDialGroup(
                                            title: 'Pulse',
                                            locked: data.pulseLocked,
                                            onToggleLock: () {
                                              connection.setPulseLocked(
                                                !data.pulseLocked,
                                              );
                                            },
                                            value: data.pulseHz,
                                            valueText:
                                                '${data.effectivePulseHz.toStringAsFixed(1)} Hz',
                                            min: data.pulseMinHz,
                                            max: data.pulseMaxHz,
                                            detentStep: 2.0,
                                            onChanged: data.pulseLocked
                                                ? null
                                                : connection.setManualPulseHz,
                                            lfoEnabled: data.pulseLfoEnabled,
                                            onLfoEnabledChanged:
                                                (bool enabled) {
                                                  Haptics.selection();
                                                  connection.setPulseLfo(
                                                    enabled: enabled,
                                                    rateHz: data.pulseLfoRateHz,
                                                    depth: data.pulseLfoDepth,
                                                  );
                                                },
                                            lfoRateHz: data.pulseLfoRateHz,
                                            onLfoRateChanged: (double value) {
                                              connection.setPulseLfo(
                                                enabled: data.pulseLfoEnabled,
                                                rateHz: value,
                                                depth: data.pulseLfoDepth,
                                              );
                                            },
                                            lfoDepth: data.pulseLfoDepth,
                                            onLfoDepthChanged: (double value) {
                                              connection.setPulseLfo(
                                                enabled: data.pulseLfoEnabled,
                                                rateHz: data.pulseLfoRateHz,
                                                depth: value,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          width: padWidth,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: isFourPhase
                                    ? ManualFourPhasePad(
                                        smoothedE1: data.smoothedE1,
                                        smoothedE2: data.smoothedE2,
                                        smoothedE3: data.smoothedE3,
                                        smoothedE4: data.smoothedE4,
                                        userE4: data.userE4,
                                        active: active,
                                        onElectrodesChanged:
                                            (
                                              double e1,
                                              double e2,
                                              double e3,
                                              double e4,
                                            ) {
                                              connection.setManualElectrodes(
                                                e1,
                                                e2,
                                                e3,
                                                e4,
                                              );
                                            },
                                      )
                                    : ManualThreePhasePad(
                                        smoothedAlpha: data.smoothedAlpha,
                                        smoothedBeta: data.smoothedBeta,
                                        active: active,
                                        onPositionChanged:
                                            (double alpha, double beta) {
                                              connection.setManualPosition(
                                                alpha,
                                                beta,
                                              );
                                            },
                                      ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Column(
                                  children: <Widget>[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      onPressed: _exitToHome,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.settings,
                                        color: Colors.white70,
                                      ),
                                      onPressed: _openCalibration,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildIntensityPanel(
                          manualIntensity: data.manualIntensity,
                          manualIntensityRamp: data.manualIntensityRamp,
                          connection: connection,
                          width: sidePanelWidth,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
      ),
    );
  }
}
