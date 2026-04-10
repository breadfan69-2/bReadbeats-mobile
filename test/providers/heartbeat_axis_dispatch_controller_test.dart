import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/providers/heartbeat_axis_command_mapper.dart';
import 'package:breadbeats_mobile/providers/heartbeat_axis_dispatch_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatAxisDispatchController controller =
      HeartbeatAxisDispatchController();

  test('queueAxis enqueues move operation when delta-send passes', () async {
    final List<Future<void>> operations = <Future<void>>[];
    enums.AxisType? sentAxis;
    double? sentValue;
    int? sentInterval;

    controller.queueAxis(
      operations: operations,
      axis: enums.AxisType.AXIS_POSITION_ALPHA,
      value: 0.42,
      forceSync: true,
      shouldSendAxis: ({
        required int axisKey,
        required double value,
        required bool forceSync,
      }) {
        expect(axisKey, enums.AxisType.AXIS_POSITION_ALPHA.value);
        expect(value, closeTo(0.42, 1e-12));
        expect(forceSync, isTrue);
        return true;
      },
      moveAxis: (enums.AxisType axis, double value, int intervalMs) {
        sentAxis = axis;
        sentValue = value;
        sentInterval = intervalMs;
        return Future<void>.value();
      },
    );

    expect(operations.length, 1);
    await Future.wait(operations);
    expect(sentAxis, enums.AxisType.AXIS_POSITION_ALPHA);
    expect(sentValue, closeTo(0.42, 1e-12));
    expect(sentInterval, 33);
  });

  test('queueAxis skips move operation when delta-send rejects', () {
    final List<Future<void>> operations = <Future<void>>[];
    int moveCalls = 0;

    controller.queueAxis(
      operations: operations,
      axis: enums.AxisType.AXIS_POSITION_BETA,
      value: -0.25,
      forceSync: false,
      shouldSendAxis: ({
        required int axisKey,
        required double value,
        required bool forceSync,
      }) {
        return false;
      },
      moveAxis: (enums.AxisType axis, double value, int intervalMs) {
        moveCalls++;
        return Future<void>.value();
      },
    );

    expect(operations, isEmpty);
    expect(moveCalls, 0);
  });

  test('queueCommands dispatches each command via shared policy', () async {
    final List<Future<void>> operations = <Future<void>>[];
    final List<enums.AxisType> sentAxes = <enums.AxisType>[];

    final List<HeartbeatAxisCommand> commands = <HeartbeatAxisCommand>[
      const HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS,
        value: 0.8,
      ),
      const HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_CARRIER_FREQUENCY_HZ,
        value: 520.0,
      ),
      const HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_PULSE_FREQUENCY_HZ,
        value: 24.0,
      ),
    ];

    controller.queueCommands(
      operations: operations,
      commands: commands,
      forceSync: false,
      shouldSendAxis: ({
        required int axisKey,
        required double value,
        required bool forceSync,
      }) {
        return axisKey != enums.AxisType.AXIS_CARRIER_FREQUENCY_HZ.value;
      },
      moveAxis: (enums.AxisType axis, double value, int intervalMs) {
        sentAxes.add(axis);
        expect(intervalMs, 33);
        return Future<void>.value();
      },
    );

    await Future.wait(operations);
    expect(sentAxes, <enums.AxisType>[
      enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS,
      enums.AxisType.AXIS_PULSE_FREQUENCY_HZ,
    ]);
  });
}
