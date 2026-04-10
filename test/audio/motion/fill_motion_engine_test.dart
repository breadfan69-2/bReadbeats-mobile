import 'dart:math';

import 'package:breadbeats_mobile/audio/motion/fill_motion_engine.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'FillMotionEngine updateFillTransitionState starts fill silence timer and ramps in',
    () {
      final FillMotionEngine engine = FillMotionEngine();

      final (int fillSilenceStartMs, double fillTransition) = engine
          .updateFillTransitionState(
            triggerKind: TriggerKind.fill,
            fillSilenceStartMs: 0,
            fillTransition: 0.0,
            nowMs: 1000,
            dtSec: 0.8,
          );

      expect(fillSilenceStartMs, 1000);
      expect(fillTransition, closeTo(1.0 - exp(-1.0), 1e-12));
    },
  );

  test(
    'FillMotionEngine updateFillTransitionState clears timer and ramps out',
    () {
      final FillMotionEngine engine = FillMotionEngine();

      final (int fillSilenceStartMs, double fillTransition) = engine
          .updateFillTransitionState(
            triggerKind: TriggerKind.beat,
            fillSilenceStartMs: 900,
            fillTransition: 1.0,
            nowMs: 1000,
            dtSec: 0.3,
          );

      expect(fillSilenceStartMs, 0);
      expect(fillTransition, closeTo(exp(-1.0), 1e-12));
    },
  );

  test(
    'FillMotionEngine updateFillMicroMotion maps frequencies and applies silence ramp',
    () {
      final FillMotionEngine engine = FillMotionEngine();

      final (
        double fillCenterY,
        double fillRadius,
        double fillAngle,
        double fillHhImpulse,
      ) = engine.updateFillMicroMotion(
        dominantFullHz: 80.0,
        dominantBassHz: 50.0,
        zScoreMid: false,
        zScoreHigh: false,
        nowMs: 1000,
        dtSec: 0.1,
        fillAngle: 0.0,
        fillHhImpulse: 0.0,
        fillSilenceStartMs: 0,
      );

      expect(fillCenterY, closeTo(0.5, 5e-4));
      expect(fillRadius, closeTo(0.12, 2e-4));
      expect(fillAngle, closeTo(3.14, 1e-12));
      expect(fillHhImpulse, closeTo(0.0, 1e-12));
    },
  );

  test(
    'FillMotionEngine updateFillMicroMotion reuses history and decays hi-hat impulse',
    () {
      final FillMotionEngine engine = FillMotionEngine();

      engine.updateFillMicroMotion(
        dominantFullHz: 80.0,
        dominantBassHz: 50.0,
        zScoreMid: false,
        zScoreHigh: false,
        nowMs: 1000,
        dtSec: 0.1,
        fillAngle: 0.0,
        fillHhImpulse: 0.0,
        fillSilenceStartMs: 0,
      );

      final (
        double fillCenterY,
        double fillRadius,
        double fillAngle,
        double fillHhImpulse,
      ) = engine.updateFillMicroMotion(
        dominantFullHz: 0.0,
        dominantBassHz: 0.0,
        zScoreMid: true,
        zScoreHigh: false,
        nowMs: 1000,
        dtSec: 0.1,
        fillAngle: 0.0,
        fillHhImpulse: 0.0,
        fillSilenceStartMs: 500,
      );

      expect(fillCenterY, closeTo(0.5, 5e-4));
      expect(fillRadius, closeTo(0.12, 2e-4));
      expect(fillAngle, closeTo(0.628, 1e-12));
      expect(fillHhImpulse, closeTo(0.18 * exp(-0.8), 1e-12));
    },
  );

  test('FillMotionEngine reset clears history state', () {
    final FillMotionEngine engine = FillMotionEngine();

    engine.updateFillMicroMotion(
      dominantFullHz: 80.0,
      dominantBassHz: 50.0,
      zScoreMid: false,
      zScoreHigh: false,
      nowMs: 1000,
      dtSec: 0.1,
      fillAngle: 0.0,
      fillHhImpulse: 0.0,
      fillSilenceStartMs: 0,
    );

    engine.reset();

    final (
      double fillCenterY,
      double fillRadius,
      double fillAngle,
      double fillHhImpulse,
    ) = engine.updateFillMicroMotion(
      dominantFullHz: 0.0,
      dominantBassHz: 0.0,
      zScoreMid: false,
      zScoreHigh: false,
      nowMs: 1000,
      dtSec: 0.1,
      fillAngle: 0.0,
      fillHhImpulse: 0.0,
      fillSilenceStartMs: 0,
    );

    expect(fillCenterY, closeTo(0.0, 1e-12));
    expect(fillRadius, closeTo(0.06, 1e-12));
    expect(fillAngle, closeTo(3.14, 1e-12));
    expect(fillHhImpulse, closeTo(0.0, 1e-12));
  });
}
