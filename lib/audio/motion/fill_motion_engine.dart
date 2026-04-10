import 'dart:math';

import '../../models/enums.dart';
import 'motion_math.dart';

class FillMotionEngine {
  final List<double> _fillDomFreqHistory = <double>[];
  final List<double> _fillBassFreqHistory = <double>[];

  (int fillSilenceStartMs, double fillTransition) updateFillTransitionState({
    required TriggerKind triggerKind,
    required int fillSilenceStartMs,
    required double fillTransition,
    required int nowMs,
    required double dtSec,
    double fillAttackSec = 0.8,
    double fillReleaseSec = 0.3,
  }) {
    int nextFillSilenceStartMs = fillSilenceStartMs;
    if (triggerKind == TriggerKind.fill && nextFillSilenceStartMs <= 0) {
      nextFillSilenceStartMs = nowMs;
    } else if (triggerKind != TriggerKind.fill) {
      nextFillSilenceStartMs = 0;
    }

    final double fillTarget = triggerKind == TriggerKind.fill ? 1.0 : 0.0;
    final double nextFillTransition = smoothValue(
      previous: fillTransition,
      target: fillTarget,
      dtSec: dtSec,
      attackSec: fillAttackSec,
      releaseSec: fillReleaseSec,
    );

    return (nextFillSilenceStartMs, nextFillTransition);
  }

  (
    double fillCenterY,
    double fillRadius,
    double fillAngle,
    double fillHhImpulse,
  )
  updateFillMicroMotion({
    required double dominantFullHz,
    required double dominantBassHz,
    required bool zScoreMid,
    required bool zScoreHigh,
    required int nowMs,
    required double dtSec,
    required double fillAngle,
    required double fillHhImpulse,
    required int fillSilenceStartMs,
    double fillBaseRadius = 0.06,
    double fillHhImpulseSize = 0.18,
    double fillHhDecayRate = 8.0,
    double fillRotOmega = 31.4,
  }) {
    final double fillCenterY = _fillDomFreqToY(dominantFullHz);
    final double fillRadius =
        fillBaseRadius * _fillBassFreqOrbitMult(dominantBassHz);

    double nextFillHhImpulse = fillHhImpulse;
    if (zScoreMid || zScoreHigh) {
      nextFillHhImpulse += fillHhImpulseSize;
    }
    nextFillHhImpulse *= exp(-fillHhDecayRate * dtSec);
    if (nextFillHhImpulse < 0.001) {
      nextFillHhImpulse = 0.0;
    }

    final double speedScale = _fillSilenceSpeedScale(
      nowMs: nowMs,
      fillSilenceStartMs: fillSilenceStartMs,
    );
    final double nextFillAngle = fillAngle + fillRotOmega * speedScale * dtSec;

    return (fillCenterY, fillRadius, nextFillAngle, nextFillHhImpulse);
  }

  double _fillDomFreqToY(double domHz) {
    if (domHz < 10.0) {
      return _fillDomFreqHistory.isEmpty
          ? 0.0
          : _fillDomFreqHistory.reduce((double a, double b) => a + b) /
                _fillDomFreqHistory.length;
    }

    final double clamped = domHz.clamp(80.0, 8000.0);
    final double t = (log(clamped) / ln2 - 6.32) / (12.97 - 6.32);
    final double y = 0.5 - t;
    _fillDomFreqHistory.add(y);
    if (_fillDomFreqHistory.length > 6) {
      _fillDomFreqHistory.removeAt(0);
    }
    return _fillDomFreqHistory.reduce((double a, double b) => a + b) /
        _fillDomFreqHistory.length;
  }

  double _fillBassFreqOrbitMult(double bassHz) {
    if (bassHz < 10.0) {
      return _fillBassFreqHistory.isEmpty
          ? 1.0
          : _fillBassFreqHistory.reduce((double a, double b) => a + b) /
                _fillBassFreqHistory.length;
    }

    final double clamped = bassHz.clamp(50.0, 200.0);
    final double t = (log(clamped) / ln2 - 5.64) / (7.64 - 5.64);
    final double mult = 2.0 - t;
    _fillBassFreqHistory.add(mult);
    if (_fillBassFreqHistory.length > 4) {
      _fillBassFreqHistory.removeAt(0);
    }
    return _fillBassFreqHistory.reduce((double a, double b) => a + b) /
        _fillBassFreqHistory.length;
  }

  double _fillSilenceSpeedScale({
    required int nowMs,
    required int fillSilenceStartMs,
  }) {
    if (fillSilenceStartMs <= 0) {
      return 1.0;
    }
    final double elapsedSec = (nowMs - fillSilenceStartMs) / 1000.0;
    if (elapsedSec >= 1.5) {
      return 1.0;
    }
    final double t = (elapsedSec / 1.5).clamp(0.0, 1.0);
    return 0.10 + 0.90 * t * t;
  }

  void reset() {
    _fillDomFreqHistory.clear();
    _fillBassFreqHistory.clear();
  }
}
