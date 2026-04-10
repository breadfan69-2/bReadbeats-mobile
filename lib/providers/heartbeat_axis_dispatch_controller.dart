import '../generated/protobuf/constants.pbenum.dart' as enums;
import 'heartbeat_axis_command_mapper.dart';

typedef AxisSendPredicate = bool Function({
  required int axisKey,
  required double value,
  required bool forceSync,
});

typedef AxisMoveSender = Future<void> Function(
  enums.AxisType axis,
  double value,
  int intervalMs,
);

class HeartbeatAxisDispatchController {
  const HeartbeatAxisDispatchController();

  void queueAxis({
    required List<Future<void>> operations,
    required enums.AxisType axis,
    required double value,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    int intervalMs = 33,
  }) {
    if (!shouldSendAxis(
      axisKey: axis.value,
      value: value,
      forceSync: forceSync,
    )) {
      return;
    }

    operations.add(moveAxis(axis, value, intervalMs));
  }

  void queueCommands({
    required List<Future<void>> operations,
    required Iterable<HeartbeatAxisCommand> commands,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    int intervalMs = 33,
  }) {
    for (final HeartbeatAxisCommand command in commands) {
      queueAxis(
        operations: operations,
        axis: command.axis,
        value: command.value,
        forceSync: forceSync,
        shouldSendAxis: shouldSendAxis,
        moveAxis: moveAxis,
        intervalMs: intervalMs,
      );
    }
  }
}