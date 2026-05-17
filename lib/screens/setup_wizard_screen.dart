import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/haptics.dart';
import '../models/device_models.dart';
import '../models/enums.dart';
import '../providers/connection_provider.dart';
import '../widgets/neumorphic_tile.dart';
import '../widgets/phase_visualizer.dart';
import '../widgets/shared_widgets.dart';
import 'home_screen.dart';

/// First-launch setup wizard shown once before [HomeScreen].
///
/// Flow: Security Warning → Device Connection → Calibration → Home.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  static const String prefsKey = 'ui.setup_wizard_completed';

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;
  static const int _totalSteps = 3;
  static const Duration _sliderMinTouchDuration = Duration(milliseconds: 180);

  // ── Connection-step controllers ──
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final FocusNode _hostFocusNode;
  late final FocusNode _portFocusNode;

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
      if (skinValue > 0.0) return skinValue;
      final double outputValue = output[index];
      if (outputValue <= 0.0) return 0.0;
      if (constant > 0.0 && outputValue > constant) {
        return (outputValue - constant).clamp(0.0, outputValue).toDouble();
      }
      return outputValue;
    }, growable: false);
  }

  String _formatImpedance(double value) {
    if (!value.isFinite || value <= 0.0) return '--';
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
          final String impedance = i < impedanceValues.length
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

  Widget _buildTestConnectionButton(ConnectionProvider connection) {
    final bool connecting =
        connection.connectionState == FocstimConnectionState.connecting;
    final bool connected =
        connection.connectionState == FocstimConnectionState.connected;
    final bool sessionRunning = connection.sessionRunning;

    if (connected) {
      return OutlinedButton(
        onPressed: sessionRunning ? null : () => connection.disconnect(),
        child: const Text('Disconnect'),
      );
    }

    return ElevatedButton(
      onPressed: (connecting || sessionRunning)
          ? null
          : () async {
              try {
                await connection.testConnect();
              } catch (error, stackTrace) {
                debugPrint(
                  '[SetupWizard] testConnect failed: $error\n$stackTrace',
                );
                // Error text is surfaced through connection.lastError.
              }
            },
      child: connecting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Test Connection'),
    );
  }

  @override
  void initState() {
    super.initState();
    final ConnectionProvider c = context.read<ConnectionProvider>();
    _hostController = TextEditingController(text: c.host);
    _portController = TextEditingController(text: c.port.toString());
    _hostFocusNode = FocusNode();
    _portFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _hostFocusNode.dispose();
    _portFocusNode.dispose();
    super.dispose();
  }

  // ── Navigation ──

  Future<void> _next() async {
    if (_step < _totalSteps - 1) {
      Haptics.selection();
      setState(() => _step++);
    } else {
      Haptics.medium();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SetupWizardScreen.prefsKey, true);
      // Also mark the legacy keys so the old dialog/calibration logic never
      // fires if someone downgrades or hits a code path that checks them.
      await prefs.setBool('security.unencrypted_wifi_notice_dismissed', true);
      await prefs.setBool('ui.first_launch_calibration_shown', true);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    }
  }

  // ── Step titles ──

  String get _title => switch (_step) {
    0 => 'Network Security',
    1 => 'Device Connection',
    2 => 'Calibration',
    _ => '',
  };

  String get _buttonLabel => _step < _totalSteps - 1 ? 'Next' : 'Finish';

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: const Color(0xFFE0E0E0),
        automaticallyImplyLeading: false, // no back button
        title: Text(_title),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Step ${_step + 1} of $_totalSteps',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ),
        ],
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // ── Step indicator dots ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_totalSteps, (int i) {
                  final bool active = i == _step;
                  final bool done = i < _step;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: active
                            ? kAccentCyan
                            : done
                            ? kAccentCyan.withValues(alpha: 0.4)
                            : Colors.white24,
                      ),
                    ),
                  );
                }),
              ),
            ),
            // ── Page content ──
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey<int>(_step),
                  child: switch (_step) {
                    0 => _buildSecurityPage(),
                    1 => _buildConnectionPage(),
                    2 => _buildCalibrationPage(),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ),
            // ── Next / Finish button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _buttonLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Step 0 — Security Warning
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildSecurityPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.security_rounded, size: 64, color: Colors.amber.shade300),
          const SizedBox(height: 24),
          const Text(
            'Network Security Warning',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'This app communicates with your FOC-Stim device over '
            'unencrypted WiFi. Do not use on public or shared networks.\n\n'
            'An attacker on the same network could intercept or inject '
            'device commands.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Step 1 — Device Connection
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildConnectionPage() {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();

    // Keep text fields in sync when provider changes externally.
    if (!_hostFocusNode.hasFocus && _hostController.text != connection.host) {
      _hostController.text = connection.host;
    }
    final String portText = connection.port.toString();
    if (!_portFocusNode.hasFocus && _portController.text != portText) {
      _portController.text = portText;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Enter the IP address of your FOC-Stim device. '
          'You can find it in the device\'s WiFi settings.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: HostHistoryTextField(
                controller: _hostController,
                focusNode: _hostFocusNode,
                hostHistory: connection.hostHistory,
                onChanged: connection.setHost,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _portController,
                focusNode: _portFocusNode,
                onChanged: connection.setPort,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StatusChip(state: connection.connectionState),
        if (connection.firmware != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'FW ${connection.firmware!.pretty}  •  ${connection.firmware!.board}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        if (connection.lastError != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            connection.lastError!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _buildTestConnectionButton(connection),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Step 2 — Calibration
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCalibrationPage() {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();
    final bool is4 = connection.outputMode == OutputModeSelection.fourPhase;
    final List<String> electrodeLabels = connection.visibleElectrodeLabels;
    final List<double> impedanceValues = _impedanceValues(connection, is4);

    final Map<CalibrationPattern, String> patternLabels = is4
        ? const <CalibrationPattern, String>{
            CalibrationPattern.none: 'None',
            CalibrationPattern.sequential1234: '1→2→3→4',
            CalibrationPattern.sequential4321: '4→3→2→1',
          }
        : const <CalibrationPattern, String>{
            CalibrationPattern.none: 'None',
            CalibrationPattern.circle: 'Circle (CW)',
            CalibrationPattern.circleReverse: 'Circle (CCW)',
          };

    final CalibrationPattern activePattern =
        patternLabels.containsKey(connection.calibrationPattern)
        ? connection.calibrationPattern
        : CalibrationPattern.none;
    final double speedUiValue = _patternSpeedUiValue(connection);

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: <Widget>[
                // ── Phase visualizer ──
                PhasePositionVisualizer(
                  isFourPhase: is4,
                  animate:
                      connection.captureRunning ||
                      connection.calibrationPattern != CalibrationPattern.none,
                  alpha: connection.positionAlpha,
                  beta: connection.positionBeta,
                  gamma: connection.positionGamma,
                  electrodeLevels: connection.visibleElectrodeLevels,
                  active:
                      connection.audioMotionActive ||
                      connection.calibrationPattern != CalibrationPattern.none,
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
                    label: 'Electrode ${electrodeLabels[0]} (dB)',
                    value: connection.cal4A,
                    min: -6.0,
                    max: 6.0,
                    divisions: 120,
                    minTouchDuration: _sliderMinTouchDuration,
                    onChanged: connection.setCal4A,
                  ),
                  LabeledSlider(
                    label: 'Electrode ${electrodeLabels[1]} (dB)',
                    value: connection.cal4B,
                    min: -6.0,
                    max: 6.0,
                    divisions: 120,
                    minTouchDuration: _sliderMinTouchDuration,
                    onChanged: connection.setCal4B,
                  ),
                  LabeledSlider(
                    label: 'Electrode ${electrodeLabels[2]} (dB)',
                    value: connection.cal4C,
                    min: -6.0,
                    max: 6.0,
                    divisions: 120,
                    minTouchDuration: _sliderMinTouchDuration,
                    onChanged: connection.setCal4C,
                  ),
                  LabeledSlider(
                    label: 'Electrode ${electrodeLabels[3]} (dB)',
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
                // Extra padding so content doesn't hide behind the Finish button.
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
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
