import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/capture/audio_capture_platform_service.dart';
import '../models/device_models.dart';
import '../models/enums.dart';
import '../providers/connection_provider.dart';
import '../screens/audio_screen.dart';
import '../screens/calibration_screen.dart';
import '../screens/device_screen.dart';
import '../screens/beat_intelligence_screen.dart';
import '../screens/home/audio_tile.dart';
import '../screens/home/beat_intelligence_tile.dart';
import '../screens/home/calibration_tile.dart';
import '../screens/home/carrier_freq_tile.dart';
import '../screens/home/manual_mode_tile.dart';
import '../screens/home/pulse_freq_tile.dart';
import '../screens/home/connection_tile.dart';
import '../screens/home/session_tile.dart';
import '../screens/home/telemetry_tile.dart';
import '../screens/manual_mode_screen.dart';
import '../screens/stim_pattern_screen.dart';
import '../screens/telemetry_screen.dart';
import '../screens/waveform_screen.dart';
import '../widgets/neumorphic_tile.dart';
import '../widgets/phase_visualizer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _debugBuildCount = 0;
  int _debugBuildWindowStartMs = 0;
  bool _sessionStartInProgress = false;

  void _recordBuildProbe() {
    if (!kDebugMode) {
      return;
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_debugBuildWindowStartMs == 0) {
      _debugBuildWindowStartMs = nowMs;
    }
    _debugBuildCount += 1;

    if ((nowMs - _debugBuildWindowStartMs) < 1000) {
      return;
    }

    debugPrint('[PERF][home_screen] build=$_debugBuildCount/s');
    _debugBuildCount = 0;
    _debugBuildWindowStartMs = nowMs;
  }

  void _push(Widget screen) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _pushReplacement(Widget screen) {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _showAudioSourcePicker() async {
    final ConnectionProvider c = context.read<ConnectionProvider>();
    try {
      await c.refreshCaptureApps();
    } catch (error, stackTrace) {
      debugPrint('[HomeScreen] refreshCaptureApps failed: $error\n$stackTrace');
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kNeumorphicBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return Consumer<ConnectionProvider>(
          builder: (_, ConnectionProvider c, _) {
            final List<CapturableApp> apps = c.captureApps;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                    child: Row(
                      children: <Widget>[
                        const Text(
                          'Pick audio source',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: kAccentCyan),
                          onPressed: () async {
                            try {
                              await c.refreshCaptureApps();
                            } catch (error, stackTrace) {
                              debugPrint(
                                '[HomeScreen] refreshCaptureApps failed '
                                'from picker: $error\n$stackTrace',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (apps.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No capturable apps found.\nOpen a music player first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: apps
                            .map(
                              (CapturableApp app) => ListTile(
                                leading: const Icon(
                                  Icons.audiotrack,
                                  color: kAccentCyan,
                                ),
                                title: Text(
                                  app.appName,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  app.packageName,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                                selected:
                                    c.selectedCaptureApp?.packageName ==
                                    app.packageName,
                                selectedTileColor: kAccentCyan.withValues(
                                  alpha: 0.08,
                                ),
                                onTap: () {
                                  c.selectCaptureApp(app);
                                  Navigator.pop(ctx);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleSession() async {
    final ConnectionProvider c = context.read<ConnectionProvider>();

    if (c.sessionRunning) {
      await c.stopSession();
      return;
    }

    // Prevent double-tap during async connect (can take several seconds).
    if (_sessionStartInProgress) return;
    _sessionStartInProgress = true;

    try {
      if (c.selectedCaptureApp == null) {
        // Try restoring the last selected capture app automatically.
        try {
          await c.refreshCaptureApps();
        } catch (error, stackTrace) {
          debugPrint(
            '[HomeScreen] Auto-refresh capture apps failed: '
            '$error\n$stackTrace',
          );
        }
      }

      // Show the Flutter picker up-front so the audio source is chosen
      // before any system dialogs appear.  On Android 14+, the subsequent
      // MediaProjection consent dialog skips the "choose app" step (the
      // native side uses createConfigForDefaultDisplay()) and is just a
      // single-tap confirm.  Audio is still filtered by UID.
      if (c.selectedCaptureApp == null) {
        await _showAudioSourcePicker();
        if (!mounted || c.selectedCaptureApp == null) return;
      }

      await c.startSession();
    } catch (e) {
      if (!mounted) return;

      final String err = c.lastError ?? e.toString();
      final bool isAudioError = _isAudioError(err);

      if (isAudioError) {
        // Audio capture / projection permission issue — send to audio screen.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Audio capture failed — check your source.'),
            action: SnackBarAction(
              label: 'Fix',
              onPressed: () => _push(const AudioScreen()),
            ),
          ),
        );
      } else {
        // Connection / firmware error — send to device screen to fix IP.
        _push(const DeviceScreen());
      }
    } finally {
      if (mounted) _sessionStartInProgress = false;
    }
  }

  Future<void> _openManualMode() async {
    final ConnectionProvider connection = context.read<ConnectionProvider>();
    if (connection.sessionRunning) {
      await connection.stopSession();
    }
    if (!mounted) {
      return;
    }
    _pushReplacement(const ManualModeScreen());
  }

  /// Returns true when the error string suggests an audio-capture failure
  /// rather than a network/connection failure.
  static bool _isAudioError(String err) {
    final String lower = err.toLowerCase();
    return lower.contains('projection') ||
        lower.contains('audio') ||
        lower.contains('capture') ||
        lower.contains('permission') ||
        lower.contains('mediaproject');
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      _recordBuildProbe();
      return true;
    }());
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: kNeumorphicBase,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: <Widget>[
            Selector<
              ConnectionProvider,
              ({
                OutputModeSelection outputMode,
                double positionAlpha,
                double positionBeta,
                double positionGamma,
                List<double> visibleElectrodeLevels,
                bool audioMotionActive,
                bool captureRunning,
                CalibrationPattern calibrationPattern,
              })
            >(
              selector: (_, ConnectionProvider c) => (
                outputMode: c.outputMode,
                positionAlpha: c.positionAlpha,
                positionBeta: c.positionBeta,
                positionGamma: c.positionGamma,
                visibleElectrodeLevels: c.visibleElectrodeLevels,
                audioMotionActive: c.audioMotionActive,
                captureRunning: c.captureRunning,
                calibrationPattern: c.calibrationPattern,
              ),
              shouldRebuild: (previous, next) =>
                  previous.outputMode != next.outputMode ||
                  previous.positionAlpha != next.positionAlpha ||
                  previous.positionBeta != next.positionBeta ||
                  previous.positionGamma != next.positionGamma ||
                  previous.audioMotionActive != next.audioMotionActive ||
                  previous.captureRunning != next.captureRunning ||
                  previous.calibrationPattern != next.calibrationPattern ||
                  !listEquals(
                    previous.visibleElectrodeLevels,
                    next.visibleElectrodeLevels,
                  ),
              builder: (_, data, _) => PhasePositionVisualizer(
                isFourPhase: data.outputMode == OutputModeSelection.fourPhase,
                animate:
                    data.captureRunning ||
                    (data.calibrationPattern != CalibrationPattern.none &&
                        data.calibrationPattern != CalibrationPattern.manual),
                alpha: data.positionAlpha,
                beta: data.positionBeta,
                gamma: data.positionGamma,
                electrodeLevels: data.visibleElectrodeLevels,
                active:
                    data.audioMotionActive ||
                    (data.calibrationPattern != CalibrationPattern.none &&
                        data.calibrationPattern != CalibrationPattern.manual),
              ),
            ),
            Selector<ConnectionProvider, bool>(
              selector: (_, ConnectionProvider c) => c.buttonHoldMuted,
              builder: (_, bool buttonHoldMuted, _) {
                if (!buttonHoldMuted) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: <Widget>[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.error.withValues(alpha: 0.55),
                        ),
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
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            SessionTile(
              onToggleSession: _toggleSession,
              onOpenDetail: () => _push(const StimPatternScreen()),
            ),
            const SizedBox(height: 14),
            AudioTile(
              onOpenDetail: () => _push(const AudioScreen()),
              onPickAudioSource: () => unawaited(_showAudioSourcePicker()),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: CarrierFreqTile(
                    onOpenDetail: () => _push(const WaveformScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConnectionTile(
                    onOpenDetail: () => _push(const DeviceScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: PulseFreqTile(
                    onOpenDetail: () => _push(const WaveformScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BeatIntelligenceTile(
                    onOpenDetail: () => _push(const BeatIntelligenceScreen()),
                    onToggleIntelligence: () {
                      final ConnectionProvider c = context
                          .read<ConnectionProvider>();
                      c.setLearningEnabled(!c.learningEnabled);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: TelemetryTile(
                    onOpenDetail: () => _push(const TelemetryScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CalibrationTile(
                    onOpenDetail: () => _push(const CalibrationScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ManualModeTile(onOpenManual: () => unawaited(_openManualMode())),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
