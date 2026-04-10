import 'dart:async';

import '../generated/protobuf/constants.pbenum.dart' as enums;
import '../models/motion_constants.dart';

enum ButtonStateMachineAction { toggleMute, toggleVolumeLock, disconnect }

typedef ButtonStateMachineActionCallback =
    void Function(ButtonStateMachineAction action);

typedef ButtonStateMachineTimerFactory =
    Timer Function(Duration duration, void Function() callback);

class ButtonStateMachine {
  ButtonStateMachine({
    int Function()? nowMsProvider,
    ButtonStateMachineTimerFactory? timerFactory,
  }) : _nowMsProvider =
           nowMsProvider ?? (() => DateTime.now().millisecondsSinceEpoch),
       _timerFactory = timerFactory ?? _defaultTimerFactory;

  static Timer _defaultTimerFactory(
    Duration duration,
    void Function() callback,
  ) {
    return Timer(duration, callback);
  }

  final int Function() _nowMsProvider;
  final ButtonStateMachineTimerFactory _timerFactory;

  bool buttonHoldMuted = false;
  double buttonHoldRamp = 1.0;

  bool _buttonIsDown = false;
  bool _buttonLongPressConsumed = false;
  Timer? _buttonHoldTimer;
  Timer? _buttonDisconnectTimer;

  int _clickCount = 0;
  int _lastClickUpMs = 0;

  void handleHardwareButtonState({
    required enums.ButtonState state,
    required ButtonStateMachineActionCallback onAction,
  }) {
    switch (state) {
      case enums.ButtonState.BUTTON_DOWN:
        if (_buttonIsDown) {
          return;
        }
        _buttonIsDown = true;
        _buttonLongPressConsumed = false;
        _buttonHoldTimer?.cancel();
        _buttonDisconnectTimer?.cancel();

        final int nowMs = _nowMsProvider();
        final bool isDisconnectHoldCandidate =
            _clickCount == 1 && (nowMs - _lastClickUpMs <= tripleClickMaxGapMs);

        if (isDisconnectHoldCandidate) {
          _buttonDisconnectTimer = _timerFactory(
            const Duration(milliseconds: buttonDisconnectHoldMs),
            () {
              if (!_buttonIsDown || _buttonLongPressConsumed) {
                return;
              }
              _buttonLongPressConsumed = true;
              _clickCount = 0;
              onAction(ButtonStateMachineAction.disconnect);
            },
          );
        } else {
          _buttonHoldTimer = _timerFactory(
            const Duration(milliseconds: buttonHoldThresholdMs),
            () {
              if (!_buttonIsDown || _buttonLongPressConsumed) {
                return;
              }
              _buttonLongPressConsumed = true;
              onAction(ButtonStateMachineAction.toggleMute);
            },
          );
        }
        break;
      case enums.ButtonState.BUTTON_UP:
        _buttonIsDown = false;
        final bool wasLongPress = _buttonLongPressConsumed;
        _buttonLongPressConsumed = false;
        _buttonHoldTimer?.cancel();
        _buttonHoldTimer = null;
        _buttonDisconnectTimer?.cancel();
        _buttonDisconnectTimer = null;

        if (!wasLongPress) {
          final int nowMs = _nowMsProvider();
          if (nowMs - _lastClickUpMs <= tripleClickMaxGapMs) {
            _clickCount++;
          } else {
            _clickCount = 1;
          }
          _lastClickUpMs = nowMs;

          if (_clickCount >= 3) {
            _clickCount = 0;
            onAction(ButtonStateMachineAction.toggleVolumeLock);
          }
        }
        break;
      case enums.ButtonState.BUTTON_UNKNOWN:
        break;
    }
  }

  void toggleMute() {
    buttonHoldMuted = !buttonHoldMuted;
    buttonHoldRamp = 0.0;
  }

  void setButtonHoldRamp(double value) {
    buttonHoldRamp = value;
  }

  void reset({required bool resetMute}) {
    _buttonIsDown = false;
    _buttonLongPressConsumed = false;
    _clickCount = 0;
    _lastClickUpMs = 0;
    _buttonHoldTimer?.cancel();
    _buttonHoldTimer = null;
    _buttonDisconnectTimer?.cancel();
    _buttonDisconnectTimer = null;
    if (resetMute) {
      buttonHoldMuted = false;
      buttonHoldRamp = 1.0;
    }
  }

  void dispose() {
    _buttonHoldTimer?.cancel();
    _buttonHoldTimer = null;
    _buttonDisconnectTimer?.cancel();
    _buttonDisconnectTimer = null;
  }
}
