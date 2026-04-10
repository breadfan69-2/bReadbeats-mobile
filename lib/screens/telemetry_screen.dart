import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../widgets/neumorphic_tile.dart';
import '../widgets/shared_widgets.dart';

class TelemetryScreen extends StatelessWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();

    return DetailScreenScaffold(
      title: 'Telemetry',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: <Widget>[
          // ── Overview ──
          _SectionTile(
            icon: Icons.analytics_outlined,
            title: 'OVERVIEW',
            trailing: _ClearButton(onPressed: connection.clearTelemetry),
            children: <Widget>[
              TelemetryRow(label: 'Notifications', value: '${connection.notificationCount}'),
              TelemetryRow(
                  label: 'Rate', value: '${connection.telemetryRateHz.toStringAsFixed(1)} Hz'),
              TelemetryRow(
                label: 'Categories Seen',
                value:
                    '${connection.telemetrySeenCategories}/${ConnectionProvider.totalTelemetryCategories}',
              ),
              TelemetryRow(label: 'Last Category', value: connection.telemetryLastCategory),
              TelemetryRow(
                label: 'HDLC Dropped',
                value: '${connection.telemetryHdlcDroppedFrames}',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Signal + Current Stats ──
          _SectionTile(
            icon: Icons.electric_bolt,
            title: 'SIGNAL + CURRENT',
            children: <Widget>[
              TelemetryRow(
                label: 'Actual Pulse',
                value: '${connection.telemetryActualPulseFrequency.toStringAsFixed(2)} Hz',
              ),
              TelemetryRow(
                label: 'V Drive',
                value: '${connection.telemetryVDrive.toStringAsFixed(2)} Vpp',
              ),
              TelemetryRow(
                label: 'Transformer Util.',
                value:
                    '${(connection.telemetryTransformerUtilization * 100.0).toStringAsFixed(1)}%',
              ),
              TelemetryRow(
                label: 'Voltage Util.',
                value: '${(connection.telemetryVoltageUtilization * 100.0).toStringAsFixed(1)}%',
              ),
              TelemetryRow(
                label: 'Output Power',
                value:
                    '${connection.telemetryOutputPowerW.toStringAsFixed(2)} W (${connection.telemetryOutputPowerSkinW.toStringAsFixed(2)} W skin)',
              ),
              const SizedBox(height: 6),
              _ElectrodeQuadRow(
                label: 'RMS',
                values: <double>[
                  connection.telemetryRmsA,
                  connection.telemetryRmsB,
                  connection.telemetryRmsC,
                  connection.telemetryRmsD,
                ],
                decimals: 3,
                unit: 'A',
              ),
              _ElectrodeQuadRow(
                label: 'Peak',
                values: <double>[
                  connection.telemetryPeakA,
                  connection.telemetryPeakB,
                  connection.telemetryPeakC,
                  connection.telemetryPeakD,
                ],
                decimals: 3,
                unit: 'A',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── System / Battery / Debug ──
          _SectionTile(
            icon: Icons.battery_charging_full,
            title: 'SYSTEM / BATTERY',
            children: <Widget>[
              TelemetryRow(label: 'System Variant', value: connection.telemetrySystemVariant),
              TelemetryRow(
                label: 'STM32 Temp',
                value: '${connection.telemetrySystemTempStm32.toStringAsFixed(1)} °C',
              ),
              TelemetryRow(
                label: 'Battery',
                value:
                    '${connection.telemetryBatteryVoltage.toStringAsFixed(2)} V, ${connection.telemetryBatterySoc.toStringAsFixed(1)}%, wall=${connection.telemetryWallPowerPresent ? 'yes' : 'no'}',
              ),
              TelemetryRow(
                label: 'Device Volume',
                value:
                    '${(connection.telemetryDeviceVolume * 100.0).toStringAsFixed(1)}% (${connection.telemetryDeviceVolumeLocked ? 'locked' : 'unlocked'})',
              ),
              TelemetryRow(
                label: 'Pressure',
                value: '${connection.telemetryPressurePa.toStringAsFixed(1)} Pa',
              ),
              TelemetryRow(
                label: 'Button',
                value:
                    '${connection.telemetryButtonState} @ ${connection.telemetryButtonTimestampMs} ms',
              ),
              TelemetryRow(
                label: 'Debug String',
                value: connection.telemetryDebugString.isEmpty
                    ? '(none)'
                    : connection.telemetryDebugString,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Model / IMU / Impedance ──
          _SectionTile(
            icon: Icons.sensors,
            title: 'MODEL / IMU',
            children: <Widget>[
              TelemetryRow(
                label: 'IMU Capable (fw)',
                value: connection.telemetryImuCapabilityStatus,
              ),
              TelemetryRow(
                label: 'IMU Stream',
                value: connection.telemetryImuStreamingStatus,
              ),
              TelemetryRow(
                label: 'IMU Notifs',
                value: '${connection.telemetryImuNotificationCount}',
              ),
              const SizedBox(height: 6),
              _ElectrodeQuadRow(
                label: 'Out R',
                values: <double>[
                  connection.telemetryOutputResistanceA,
                  connection.telemetryOutputResistanceB,
                  connection.telemetryOutputResistanceC,
                  connection.telemetryOutputResistanceD,
                ],
                decimals: 2,
                unit: 'Ω',
              ),
              _ElectrodeQuadRow(
                label: 'Out X',
                values: <double>[
                  connection.telemetryOutputReluctanceA,
                  connection.telemetryOutputReluctanceB,
                  connection.telemetryOutputReluctanceC,
                  connection.telemetryOutputReluctanceD,
                ],
                decimals: 2,
                unit: 'Ω',
              ),
              _ElectrodeQuadRow(
                label: 'Skin R',
                values: <double>[
                  connection.telemetrySkinResistanceA,
                  connection.telemetrySkinResistanceB,
                  connection.telemetrySkinResistanceC,
                  connection.telemetrySkinResistanceD,
                ],
                decimals: 2,
                unit: 'Ω',
              ),
              _ElectrodeQuadRow(
                label: 'Skin X',
                values: <double>[
                  connection.telemetrySkinReluctanceA,
                  connection.telemetrySkinReluctanceB,
                  connection.telemetrySkinReluctanceC,
                  connection.telemetrySkinReluctanceD,
                ],
                decimals: 2,
                unit: 'Ω',
              ),
              const SizedBox(height: 6),
              TelemetryRow(
                label: 'IMU Acc X/Y/Z',
                value:
                    '${connection.telemetryAccX} / ${connection.telemetryAccY} / ${connection.telemetryAccZ}',
              ),
              TelemetryRow(
                label: 'IMU Gyr X/Y/Z',
                value:
                    '${connection.telemetryGyrX} / ${connection.telemetryGyrY} / ${connection.telemetryGyrZ}',
              ),
              TelemetryRow(
                label: 'AS5311',
                value:
                    '${connection.telemetryDebugAs5311Raw} / ${connection.telemetryDebugAs5311Tracked} / ${connection.telemetryDebugAs5311Flags}',
              ),
              TelemetryRow(
                label: 'Edging thresholds',
                value:
                    '${connection.telemetryDebugEdgingFullPowerThreshold.toStringAsFixed(3)} / ${connection.telemetryDebugEdgingReducedPowerThreshold.toStringAsFixed(3)} / ${connection.telemetryDebugEdgingReduction.toStringAsFixed(3)}',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Category Activity ──
          _SectionTile(
            icon: Icons.category_outlined,
            title: 'CATEGORY ACTIVITY',
            children: <Widget>[
              if (connection.telemetryCategoryCountEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No categories received yet.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              else
                ...connection.telemetryCategoryCountEntries.map(
                  (MapEntry<String, int> entry) =>
                      TelemetryRow(label: entry.key, value: '${entry.value}'),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ── Private helper widgets ──────────────────────────────────────────────────

/// A NeumorphicTile that wraps a titled section with an icon header.
class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return NeumorphicTile(
      depth: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: kAccentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (trailing case final Widget trailingWidget) trailingWidget,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Color-coded A/B/C/D electrode value row.
class _ElectrodeQuadRow extends StatelessWidget {
  const _ElectrodeQuadRow({
    required this.label,
    required this.values,
    required this.decimals,
    this.unit = '',
  });

  final String label;
  final List<double> values;
  final int decimals;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          for (int i = 0; i < values.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                decoration: BoxDecoration(
                  color: kElectrodeColors[i].withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: kElectrodeColors[i].withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  values[i].toStringAsFixed(decimals),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kElectrodeColors[i],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          if (unit.isNotEmpty) ...<Widget>[
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact clear-counters button for the overview tile header.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.cleaning_services, size: 14),
        label: const Text('Clear', style: TextStyle(fontSize: 11)),
        style: TextButton.styleFrom(
          foregroundColor: kAccentCyan,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
