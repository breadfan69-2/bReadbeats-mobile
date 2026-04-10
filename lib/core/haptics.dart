import 'dart:async';

import 'package:flutter/services.dart';

class Haptics {
  static const Duration _cooldown = Duration(milliseconds: 250);
  static const Duration _doublePulseGap = Duration(milliseconds: 100);
  static DateTime _lastPulseAt = DateTime.fromMillisecondsSinceEpoch(0);

  static void selection() => _trigger(HapticFeedback.selectionClick);
  static void light() => _trigger(HapticFeedback.lightImpact);
  static void medium() => _trigger(HapticFeedback.mediumImpact);
  static void heavy() => _trigger(HapticFeedback.heavyImpact);

  static void disconnectDouble() {
    _triggerDouble(first: HapticFeedback.mediumImpact, second: HapticFeedback.mediumImpact);
  }

  static void errorDouble() {
    _triggerDouble(first: HapticFeedback.heavyImpact, second: HapticFeedback.heavyImpact);
  }

  static void _trigger(Future<void> Function() pulse) {
    unawaited(_emit(pulse));
  }

  static void _triggerDouble({
    required Future<void> Function() first,
    required Future<void> Function() second,
  }) {
    unawaited(_emitDouble(first: first, second: second));
  }

  static Future<void> _emit(
    Future<void> Function() pulse, {
    bool bypassCooldown = false,
  }) async {
    final DateTime now = DateTime.now();
    if (!bypassCooldown && now.difference(_lastPulseAt) < _cooldown) {
      return;
    }
    _lastPulseAt = now;
    await pulse();
  }

  static Future<void> _emitDouble({
    required Future<void> Function() first,
    required Future<void> Function() second,
  }) async {
    await _emit(first);
    await Future<void>.delayed(_doublePulseGap);
    await _emit(second, bypassCooldown: true);
  }
}
