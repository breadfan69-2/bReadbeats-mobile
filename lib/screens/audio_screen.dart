import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/capture/audio_capture_platform_service.dart';
import '../models/enums.dart';
import '../providers/connection_provider.dart';
import '../widgets/neumorphic_tile.dart';
import '../widgets/shared_widgets.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-refresh the app list when this screen opens so the dropdown
    // is never stale/empty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ConnectionProvider c = context.read<ConnectionProvider>();
      // Skip the refresh if capture is already running — calling
      // listCapturableApps() via MethodChannel while MediaProjection is
      // active stalls the Android main thread on some Samsung devices,
      // which blocks subsequent capture MethodChannel calls and freezes
      // the stim pipeline for up to 60 s.
      if (c.captureRunning) {
        return;
      }
      c
          .refreshCaptureApps()
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint(
              '[AudioScreen] refreshCaptureApps failed on open: '
              '$error\n$stackTrace',
            );
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider c = context.watch<ConnectionProvider>();

    return DetailScreenScaffold(
      title: 'Audio Capture',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: <Widget>[
          // ── Source picker tile ──
          Selector<ConnectionProvider,
              ({List<CapturableApp> apps, String? selected, bool running})>(
            selector: (_, ConnectionProvider c) => (
              apps: c.captureApps,
              selected: c.selectedCaptureApp?.packageName,
              running: c.captureRunning,
            ),
            builder: (BuildContext ctx,
                ({List<CapturableApp> apps, String? selected, bool running})
                    data,
                _) {
              final ConnectionProvider c = ctx.read<ConnectionProvider>();
              return NeumorphicTile(
                depth: 5,
                sunken: data.selected == null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.cable, size: 18, color: kAccentCyan),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'SOURCE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 28,
                          child: IconButton(
                            onPressed: () async {
                              try {
                                await c.refreshCaptureApps();
                              } catch (error, stackTrace) {
                                debugPrint(
                                  '[AudioScreen] Manual refresh failed: '
                                  '$error\n$stackTrace',
                                );
                              }
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            color: kAccentCyan,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            tooltip: 'Refresh app list',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Compact dropdown-style picker row
                    _AppPickerRow(
                      apps: data.apps,
                      selected: data.selected,
                      onSelect: (CapturableApp? app) => c.selectCaptureApp(app),
                    ),
                    const SizedBox(height: 12),
                    // Start / Stop row
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: data.running || data.selected == null
                                ? null
                                : () async {
                                    try {
                                      await c.startAudioCapture();
                                    } catch (error, stackTrace) {
                                      debugPrint(
                                        '[AudioScreen] startAudioCapture failed: '
                                        '$error\n$stackTrace',
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            c.lastError ??
                                                'Could not start audio capture',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.mic, size: 16),
                            label: const Text('Start'),
                            style: FilledButton.styleFrom(
                              backgroundColor: kAccentCyan,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor:
                                  kNeumorphicLighter,
                              disabledForegroundColor: Colors.white38,
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: data.running
                                ? () async {
                                    await c.stopAudioCapture();
                                  }
                                : null,
                            icon: const Icon(Icons.stop, size: 16),
                            label: const Text('Stop'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(
                                color: data.running
                                    ? Colors.redAccent.withValues(alpha: 0.5)
                                    : Colors.white12,
                              ),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // ── Live level meter tile ──
          Selector<ConnectionProvider,
              ({double level, double db, bool gateOpen, String status,
                bool blocked, String? blockedMsg, bool noSource})>(
            selector: (_, ConnectionProvider c) => (
              level: c.liveAudioLevel,
              db: c.liveDb,
              gateOpen: c.liveGateOpen,
              status: c.captureStatus,
              blocked: c.captureSourceBlocked,
              blockedMsg: c.captureSourceMessage,
              noSource: c.selectedCaptureApp == null,
            ),
            builder: (BuildContext ctx, data, _) {
              return NeumorphicTile(
                depth: 5,
                glowIntensity: data.gateOpen ? (data.level * 0.6) : 0.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          data.gateOpen
                              ? Icons.volume_up
                              : Icons.volume_off,
                          size: 18,
                          color: data.gateOpen ? kAccentCyan : Colors.white38,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'LEVEL',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Text(
                          '${data.db.toStringAsFixed(1)} dB',
                          style: TextStyle(
                            color: data.blocked
                                ? Colors.redAccent
                                : kAccentCyan,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: data.level.clamp(0.0, 1.0),
                        backgroundColor: kNeumorphicDarker,
                        color: data.blocked
                            ? Colors.redAccent
                            : kAccentCyan,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        _StatusDot(
                          active: data.gateOpen,
                          color: data.gateOpen ? kAccentCyan : Colors.white24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Gate ${data.gateOpen ? 'open' : 'closed'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: data.gateOpen
                                ? Colors.white70
                                : Colors.white38,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            data.status,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (data.noSource)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Select an app above to start capture.',
                          style:
                              TextStyle(color: Colors.orange, fontSize: 11),
                        ),
                      ),
                    if (data.blocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          data.blockedMsg ??
                              'Selected app appears blocked or silent.',
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // ── Audio Monitoring tile ──
          NeumorphicTile(
            depth: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.tune, size: 18, color: kAccentCyan),
                    SizedBox(width: 8),
                    Text(
                      'MONITORING',
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
                LabeledSlider(
                  label: 'Sensitivity',
                  value: c.sensitivity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: c.setSensitivity,
                ),
                LabeledRangeSlider(
                  label: 'Bass Monitor (Hz)',
                  values:
                      RangeValues(c.bassMonitorLowHz, c.bassMonitorHighHz),
                  min: 20.0,
                  max: 500.0,
                  divisions: 96,
                  onChanged: (RangeValues v) {
                    c.setBassMonitorRange(v.start, v.end);
                  },
                ),
                if (c.stimMode == StimMode.onset) ...<Widget>[
                  const SizedBox(height: 8),
                  LabeledRangeSlider(
                    label: 'Onset Sensitivity Window',
                    values: RangeValues(
                        c.onsetSensitivityMin, c.onsetSensitivityMax),
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    displayDecimals: 2,
                    onChanged: (RangeValues v) {
                      c.setOnsetSensitivityWindow(v.start, v.end);
                    },
                  ),
                  LabeledSlider(
                    label: 'Onset Smoothing',
                    value: c.onsetSmoothing,
                    min: 0.0,
                    max: 100.0,
                    divisions: 100,
                    onChanged: c.setOnsetSmoothing,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
/// and opens a bottom-sheet list when tapped — nothing is visible until then.
class _AppPickerRow extends StatelessWidget {
  const _AppPickerRow({
    required this.apps,
    required this.selected,
    required this.onSelect,
  });

  final List<CapturableApp> apps;
  final String? selected;
  final ValueChanged<CapturableApp?> onSelect;

  String get _label {
    if (apps.isEmpty) return 'No apps found — tap refresh';
    if (selected == null) return 'Select app…';
    return apps
            .cast<CapturableApp?>()
            .firstWhere((a) => a?.packageName == selected, orElse: () => null)
            ?.appName ??
        'Select app…';
  }

  void _openSheet(BuildContext context) {
    if (apps.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kNeumorphicBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'SELECT APP TO CAPTURE',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...apps.map((CapturableApp app) {
              final bool sel = app.packageName == selected;
              return ListTile(
                dense: true,
                title: Text(
                  app.appName,
                  style: TextStyle(
                    color: sel ? kAccentCyan : Colors.white,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                trailing: sel
                    ? const Icon(Icons.check, color: kAccentCyan, size: 18)
                    : null,
                onTap: () {
                  onSelect(sel ? null : app);
                  Navigator.of(context).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = selected != null;
    return GestureDetector(
      onTap: () => _openSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kNeumorphicDarker,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasSelection
                ? kAccentCyan.withValues(alpha: 0.4)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _label,
                style: TextStyle(
                  color: hasSelection ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight:
                      hasSelection ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.expand_more,
              size: 18,
              color: hasSelection ? kAccentCyan : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small colored dot for status indicators.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: active
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

