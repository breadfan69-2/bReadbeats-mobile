import 'dart:math';

import 'package:breadbeats_mobile/audio/motion/onset_motion_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OnsetMotionEngine updateOnsetDrive normalizes onset window', () {
    final OnsetMotionEngine engine = OnsetMotionEngine();

    final double drive = engine.updateOnsetDrive(
      targetDrive: 0.5,
      dtSec: 0.05,
      onsetSmoothing: 0.0,
      onsetSensitivityMin: 0.4,
      onsetSensitivityMax: 0.8,
    );

    expect(drive, closeTo(0.25, 1e-12));
    expect(engine.onsetXtDrive, closeTo(0.25, 1e-12));
  });

  test('OnsetMotionEngine updateStereoLevels applies XT slew', () {
    final OnsetMotionEngine engine = OnsetMotionEngine();

    engine.updateStereoLevels(
      leftLevel: 0.5,
      rightLevel: 0.25,
      sensitivity: 0.48,
      dtSec: 0.05,
      onsetSmoothing: 0.0,
    );

    expect(engine.smoothedLeftLevel, closeTo(0.5, 1e-12));
    expect(engine.smoothedRightLevel, closeTo(0.299, 1e-3));
  });

  test('OnsetMotionEngine updateThreePhaseShuttle fires on onset edge', () {
    final OnsetMotionEngine engine = OnsetMotionEngine();

    engine.updateThreePhaseShuttle(
      onsetValue: 0.6,
      beatRisingEdge: false,
      zScoreMid: false,
      zScoreHigh: false,
      nowMs: 1000,
      dtSec: 0.1,
      estimatedBpm: 120.0,
    );

    expect(engine.shuttleDir, -1);
    expect(engine.lastShuttleFireMs, 1000);
    expect(engine.shuttleSpeed, closeTo(1.84, 1e-12));
    expect(engine.shuttleProgress, closeTo(0.184, 1e-12));
  });

  test('OnsetMotionEngine z-score mid edge flips rotation once', () {
    final OnsetMotionEngine engine = OnsetMotionEngine();

    engine.updateThreePhaseShuttle(
      onsetValue: 0.0,
      beatRisingEdge: false,
      zScoreMid: true,
      zScoreHigh: false,
      nowMs: 1000,
      dtSec: 0.01,
      estimatedBpm: 120.0,
    );
    final int firstRotSign = engine.shuttleRotSign;
    final double firstImpulse = engine.shuttleNImpulse;

    engine.updateThreePhaseShuttle(
      onsetValue: 0.0,
      beatRisingEdge: false,
      zScoreMid: true,
      zScoreHigh: false,
      nowMs: 1010,
      dtSec: 0.01,
      estimatedBpm: 120.0,
    );

    expect(firstRotSign, -1);
    expect(engine.shuttleRotSign, firstRotSign);
    expect(firstImpulse, greaterThan(0.4));
    expect(engine.shuttleNImpulse, lessThan(firstImpulse));
  });

  test('OnsetMotionEngine computeThreePhasePosition respects silence fade', () {
    final OnsetMotionEngine engine = OnsetMotionEngine()
      ..smoothedLeftLevel = 0.2
      ..smoothedRightLevel = 0.8
      ..shuttleProgress = 0.5
      ..shuttleDir = 1
      ..shuttleArcBlend = 1.0
      ..shuttleNImpulse = 0.1;

    final (double alphaFull, double betaFull) = engine
        .computeThreePhasePosition(
          fillCenterY: 0.1,
          fillRadius: 0.2,
          fillAngle: pi / 2,
          fillHhImpulse: 0.05,
          silenceFade: 1.0,
          orbitRadius: 0.9,
        );

    final (double alphaFaded, double betaFaded) = engine
        .computeThreePhasePosition(
          fillCenterY: 0.1,
          fillRadius: 0.2,
          fillAngle: pi / 2,
          fillHhImpulse: 0.05,
          silenceFade: 0.2,
          orbitRadius: 0.9,
        );

    expect(alphaFull, inInclusiveRange(-1.0, 1.0));
    expect(betaFull, inInclusiveRange(-1.0, 1.0));
    expect(alphaFaded.abs(), lessThanOrEqualTo(alphaFull.abs() + 1e-12));
    expect(betaFaded.abs(), lessThanOrEqualTo(betaFull.abs() + 1e-12));
  });

  test(
    'OnsetMotionEngine computeThreePhasePosition expands arc with orbitRadius',
    () {
      final OnsetMotionEngine engine = OnsetMotionEngine()
        ..smoothedLeftLevel = 1.0
        ..smoothedRightLevel = 1.0
        ..shuttleProgress = 0.5
        ..shuttleDir = 1
        ..shuttleArcBlend = 1.0
        ..shuttleNImpulse = 0.0;

      final (double alphaLow, double betaLow) = engine
          .computeThreePhasePosition(
            fillCenterY: 0.0,
            fillRadius: 0.0,
            fillAngle: 0.0,
            fillHhImpulse: 0.0,
            silenceFade: 1.0,
            orbitRadius: 0.4,
          );
      final (double alphaHigh, double betaHigh) = engine
          .computeThreePhasePosition(
            fillCenterY: 0.0,
            fillRadius: 0.0,
            fillAngle: 0.0,
            fillHhImpulse: 0.0,
            silenceFade: 1.0,
            orbitRadius: 1.0,
          );

      final double lowMagnitude = sqrt(alphaLow * alphaLow + betaLow * betaLow);
      final double highMagnitude =
          sqrt(alphaHigh * alphaHigh + betaHigh * betaHigh);

      expect(highMagnitude, greaterThan(lowMagnitude));
    },
  );

  test('OnsetMotionEngine reset restores defaults', () {
    final OnsetMotionEngine engine = OnsetMotionEngine()
      ..onsetXtDrive = 0.7
      ..smoothedLeftLevel = 0.3
      ..smoothedRightLevel = 0.4
      ..shuttleProgress = 0.6
      ..shuttleDir = -1
      ..shuttleSpeed = 3.2
      ..shuttleArcBlend = -0.3
      ..shuttleOnsetWasHigh = true
      ..lastShuttleFireMs = 123
      ..shuttleNImpulse = 0.5
      ..shuttleRotSign = -1
      ..shuttleZMidWasHigh = true
      ..shuttleZHighWasHigh = true;

    engine.reset();

    expect(engine.onsetXtDrive, 0.0);
    expect(engine.smoothedLeftLevel, 0.0);
    expect(engine.smoothedRightLevel, 0.0);
    expect(engine.shuttleProgress, 0.0);
    expect(engine.shuttleDir, 1);
    expect(engine.shuttleSpeed, 2.0);
    expect(engine.shuttleArcBlend, 1.0);
    expect(engine.shuttleOnsetWasHigh, isFalse);
    expect(engine.lastShuttleFireMs, 0);
    expect(engine.shuttleNImpulse, 0.0);
    expect(engine.shuttleRotSign, 1);
    expect(engine.shuttleZMidWasHigh, isFalse);
    expect(engine.shuttleZHighWasHigh, isFalse);
  });
}
