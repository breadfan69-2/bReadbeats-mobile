import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_models.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/battery_indicator.dart';
import '../../widgets/neumorphic_tile.dart';
import '../../widgets/volume_indicator.dart';
import 'tile_button.dart';

class ConnectionTile extends StatelessWidget {
  const ConnectionTile({required this.onOpenDetail, super.key});

  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Selector<
      ConnectionProvider,
      ({
        FocstimConnectionState connectionState,
        double telemetryBatterySoc,
        bool telemetryWallPowerPresent,
        double telemetryDeviceVolume,
        bool telemetryDeviceVolumeLocked,
      })
    >(
      selector: (_, ConnectionProvider c) => (
        connectionState: c.connectionState,
        telemetryBatterySoc: c.telemetryBatterySoc,
        telemetryWallPowerPresent: c.telemetryWallPowerPresent,
        telemetryDeviceVolume: c.telemetryDeviceVolume,
        telemetryDeviceVolumeLocked: c.telemetryDeviceVolumeLocked,
      ),
      builder: (_, data, _) {
        return NeumorphicTile(
          depth: 5,
          sunken: data.connectionState != FocstimConnectionState.connected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.wifi,
                    size: 20,
                    color: _connectionColor(data.connectionState),
                  ),
                  const Spacer(),
                  HomeTileButton(
                    icon: Icons.more_horiz,
                    size: 18,
                    onPressed: onOpenDetail,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'DEVICE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              if (data.connectionState == FocstimConnectionState.connected) ...[
                Row(
                  children: <Widget>[
                    BatteryIndicator(
                      soc: data.telemetryBatterySoc / 100.0,
                      charging: data.telemetryWallPowerPresent,
                    ),
                    const SizedBox(width: 10),
                    VolumeIndicator(
                      volume: data.telemetryDeviceVolume,
                      locked: data.telemetryDeviceVolumeLocked,
                    ),
                  ],
                ),
              ] else
                Text(
                  _connectionLabel(data.connectionState),
                  style: TextStyle(
                    color: _connectionColor(data.connectionState),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static Color _connectionColor(FocstimConnectionState state) {
    return switch (state) {
      FocstimConnectionState.disconnected => const Color(0xFF6C757D),
      FocstimConnectionState.connecting => const Color(0xFFF0A202),
      FocstimConnectionState.connected => const Color(0xFF2E933C),
      FocstimConnectionState.error => const Color(0xFFD73A49),
    };
  }

  static String _connectionLabel(FocstimConnectionState state) {
    return switch (state) {
      FocstimConnectionState.disconnected => 'Disconnected',
      FocstimConnectionState.connecting => 'Connecting...',
      FocstimConnectionState.connected => 'Connected',
      FocstimConnectionState.error => 'Error',
    };
  }
}
