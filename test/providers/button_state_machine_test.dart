import 'dart:async';

import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/models/motion_constants.dart';
import 'package:breadbeats_mobile/providers/button_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

class _TimerHarness {
  void Function()? callback;
  final Map<int, void Function()> _callbacksByDurationMs =
      <int, void Function()>{};

  Timer create(Duration duration, void Function() next) {
    callback = next;
    _callbacksByDurationMs[duration.inMilliseconds] = next;
    return Timer(const Duration(days: 365), () {});
  }

  void trigger(int durationMs) {
    final void Function()? next = _callbacksByDurationMs[durationMs];
    expect(next, isNotNull);
    next!.call();
  }
}

void main() {
  test(
    'long press emits toggleMute and suppresses click action on release',
    () {
      final _TimerHarness timerHarness = _TimerHarness();
      final List<ButtonStateMachineAction> actions =
          <ButtonStateMachineAction>[];
      final ButtonStateMachine machine = ButtonStateMachine(
        timerFactory: timerHarness.create,
        nowMsProvider: () => 1000,
      );

      machine.handleHardwareButtonState(
        state: enums.ButtonState.BUTTON_DOWN,
        onAction: actions.add,
      );
      expect(actions, isEmpty);
      expect(timerHarness.callback, isNotNull);

      timerHarness.callback!.call();
      expect(actions, <ButtonStateMachineAction>[
        ButtonStateMachineAction.toggleMute,
      ]);

      machine.handleHardwareButtonState(
        state: enums.ButtonState.BUTTON_UP,
        onAction: actions.add,
      );
      expect(actions, <ButtonStateMachineAction>[
        ButtonStateMachineAction.toggleMute,
      ]);
      machine.dispose();
    },
  );

  test('triple-click emits toggleVolumeLock on third click within gap', () {
    final _TimerHarness timerHarness = _TimerHarness();
    int nowMs = 1000;
    final List<ButtonStateMachineAction> actions = <ButtonStateMachineAction>[];
    final ButtonStateMachine machine = ButtonStateMachine(
      timerFactory: timerHarness.create,
      nowMsProvider: () => nowMs,
    );

    for (int i = 0; i < 3; i += 1) {
      machine.handleHardwareButtonState(
        state: enums.ButtonState.BUTTON_DOWN,
        onAction: actions.add,
      );
      machine.handleHardwareButtonState(
        state: enums.ButtonState.BUTTON_UP,
        onAction: actions.add,
      );
      nowMs += 200;
    }

    expect(actions, <ButtonStateMachineAction>[
      ButtonStateMachineAction.toggleVolumeLock,
    ]);
    machine.dispose();
  });

  test('click then second hold emits disconnect', () {
    final _TimerHarness timerHarness = _TimerHarness();
    int nowMs = 1000;
    final List<ButtonStateMachineAction> actions = <ButtonStateMachineAction>[];
    final ButtonStateMachine machine = ButtonStateMachine(
      timerFactory: timerHarness.create,
      nowMsProvider: () => nowMs,
    );

    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_DOWN,
      onAction: actions.add,
    );
    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_UP,
      onAction: actions.add,
    );

    nowMs += 200;
    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_DOWN,
      onAction: actions.add,
    );
    expect(actions, isEmpty);

    timerHarness.trigger(buttonDisconnectHoldMs);
    expect(actions, <ButtonStateMachineAction>[
      ButtonStateMachineAction.disconnect,
    ]);

    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_UP,
      onAction: actions.add,
    );
    expect(actions, <ButtonStateMachineAction>[
      ButtonStateMachineAction.disconnect,
    ]);
    machine.dispose();
  });

  test('triple-click counter resets after gap', () {
    final _TimerHarness timerHarness = _TimerHarness();
    int nowMs = 1000;
    final List<ButtonStateMachineAction> actions = <ButtonStateMachineAction>[];
    final ButtonStateMachine machine = ButtonStateMachine(
      timerFactory: timerHarness.create,
      nowMsProvider: () => nowMs,
    );

    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_DOWN,
      onAction: actions.add,
    );
    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_UP,
      onAction: actions.add,
    );

    nowMs += 1000;
    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_DOWN,
      onAction: actions.add,
    );
    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_UP,
      onAction: actions.add,
    );

    nowMs += 200;
    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_DOWN,
      onAction: actions.add,
    );
    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_UP,
      onAction: actions.add,
    );

    expect(actions, isEmpty);

    nowMs += 200;
    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_DOWN,
      onAction: actions.add,
    );
    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_UP,
      onAction: actions.add,
    );

    expect(actions, <ButtonStateMachineAction>[
      ButtonStateMachineAction.toggleVolumeLock,
    ]);
    machine.dispose();
  });

  test('toggleMute and reset update mute/ramp state', () {
    final _TimerHarness timerHarness = _TimerHarness();
    final List<ButtonStateMachineAction> actions = <ButtonStateMachineAction>[];
    final ButtonStateMachine machine = ButtonStateMachine(
      timerFactory: timerHarness.create,
      nowMsProvider: () => 1000,
    );

    expect(machine.buttonHoldMuted, isFalse);
    expect(machine.buttonHoldRamp, 1.0);

    machine.toggleMute();
    expect(machine.buttonHoldMuted, isTrue);
    expect(machine.buttonHoldRamp, 0.0);

    machine.setButtonHoldRamp(0.35);
    expect(machine.buttonHoldRamp, 0.35);

    machine.handleHardwareButtonState(
      state: enums.ButtonState.BUTTON_DOWN,
      onAction: actions.add,
    );
    expect(timerHarness.callback, isNotNull);

    machine.reset(resetMute: true);
    expect(machine.buttonHoldMuted, isFalse);
    expect(machine.buttonHoldRamp, 1.0);

    timerHarness.callback!.call();
    expect(actions, isEmpty);
    machine.dispose();
  });
}
