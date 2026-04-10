import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/haptics.dart';
import '../models/device_models.dart';
import '../providers/connection_provider.dart';
import '../widgets/battery_indicator.dart';
import '../widgets/shared_widgets.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final FocusNode _hostFocusNode;
  late final FocusNode _portFocusNode;

  @override
  void initState() {
    super.initState();
    final ConnectionProvider connection = context.read<ConnectionProvider>();
    _hostController = TextEditingController(text: connection.host);
    _portController = TextEditingController(text: connection.port.toString());
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

  void _syncInputs(ConnectionProvider connection) {
    if (!_hostFocusNode.hasFocus && _hostController.text != connection.host) {
      _hostController.text = connection.host;
    }
    final String portText = connection.port.toString();
    if (!_portFocusNode.hasFocus && _portController.text != portText) {
      _portController.text = portText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider connection = context.watch<ConnectionProvider>();
    _syncInputs(connection);

    return DetailScreenScaffold(
      title: 'Device Connection',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: connection.hostHistory.length > 1
                    ? DropdownButtonFormField<String>(
                        key: ValueKey<String?>(
                          connection.hostHistory.contains(_hostController.text)
                              ? _hostController.text
                              : null,
                        ),
                        initialValue:
                            connection.hostHistory.contains(
                              _hostController.text,
                            )
                            ? _hostController.text
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'FOC-Stim IP',
                          isDense: true,
                        ),
                        items: connection.hostHistory
                            .map(
                              (String ip) => DropdownMenuItem<String>(
                                value: ip,
                                child: Text(ip),
                              ),
                            )
                            .toList(),
                        onChanged: connection.sessionRunning
                            ? null
                            : (String? value) {
                                if (value != null) {
                                  Haptics.selection();
                                  _hostController.text = value;
                                  connection.setHost(value);
                                }
                              },
                      )
                    : TextField(
                        controller: _hostController,
                        focusNode: _hostFocusNode,
                        onChanged: connection.setHost,
                        decoration: const InputDecoration(
                          labelText: 'FOC-Stim IP',
                          hintText: '192.168.x.x',
                        ),
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
          const SizedBox(height: 16),
          _ConnectButton(connection: connection),
          const SizedBox(height: 12),
          if (connection.connectionState == FocstimConnectionState.connected)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: <Widget>[
                  BatteryIndicator(
                    soc: connection.telemetryBatterySoc / 100.0,
                    charging: connection.telemetryWallPowerPresent,
                    animateCharging: false,
                    width: 36,
                    height: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${connection.telemetryBatterySoc.round()}%'
                    '${connection.telemetryWallPowerPresent ? '  charging' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          SwitchListTile(
            title: const Text('Enable IMU sensor streaming'),
            subtitle: Text(
              'LSM6DSOX on-device sensors. Applies on next session start. '
              'Capability: ${connection.telemetryImuCapabilityStatus} • '
              'Status: ${connection.telemetryImuStreamingStatus}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            value: connection.imuStreamingEnabled,
            onChanged: connection.sessionRunning
                ? null
                : connection.setImuStreamingEnabled,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.connection});

  final ConnectionProvider connection;

  @override
  Widget build(BuildContext context) {
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
          : () => connection.testConnect(),
      child: connecting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Test Connection'),
    );
  }
}
