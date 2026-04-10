import 'dart:math';

import 'motion_math.dart';

class OnsetMotionEngine {
  double onsetXtDrive = 0.0;
  double smoothedLeftLevel = 0.0;
  double smoothedRightLevel = 0.0;

  double shuttleProgress = 0.0;
  int shuttleDir = 1;
  double shuttleSpeed = 2.0;
  double shuttleArcBlend = 1.0;
  bool shuttleOnsetWasHigh = false;
  int lastShuttleFireMs = 0;
  double shuttleNImpulse = 0.0;
  int shuttleRotSign = 1;
  bool shuttleZMidWasHigh = false;
  bool shuttleZHighWasHigh = false;

  double updateOnsetDrive({
    required double targetDrive,
    required double dtSec,
    required double onsetSmoothing,
    required double onsetSensitivityMin,
    required double onsetSensitivityMax,
  }) {
    final double normalizedTarget = _normalizeOnsetWindow(
      value: targetDrive,
      minValue: onsetSensitivityMin,
      maxValue: onsetSensitivityMax,
    );

    onsetXtDrive = _applyXtSmoothingStep(
      previous: onsetXtDrive,
      target: normalizedTarget,
      dtSec: dtSec,
      smoothing: onsetSmoothing,
    );
    return onsetXtDrive;
  }

  void updateStereoLevels({
    required double leftLevel,
    required double rightLevel,
    required double sensitivity,
    required double dtSec,
    required double onsetSmoothing,
  }) {
    final double sensitivityGain = 0.50 + (sensitivity.clamp(0.0, 1.0) * 1.45);
    final double rawL = (leftLevel * sensitivityGain).clamp(0.0, 1.0);
    final double rawR = (rightLevel * sensitivityGain).clamp(0.0, 1.0);

    smoothedLeftLevel = _applyXtSmoothingStep(
      previous: smoothedLeftLevel,
      target: rawL,
      dtSec: dtSec,
      smoothing: onsetSmoothing,
    );
    smoothedRightLevel = _applyXtSmoothingStep(
      previous: smoothedRightLevel,
      target: rawR,
      dtSec: dtSec,
      smoothing: onsetSmoothing,
    );
  }

  void updateThreePhaseShuttle({
    required double onsetValue,
    required bool beatRisingEdge,
    required bool zScoreMid,
    required bool zScoreHigh,
    required int nowMs,
    required double dtSec,
    required double estimatedBpm,
    double onsetEdgeThreshold = 0.50,
    int shuttleDebounceMs = 120,
    double nImpulseOnset = 0.65,
    double nImpulseMid = 0.45,
    double nImpulseHigh = 0.35,
    double nImpulseMax = 1.2,
    double nImpulseDecayRate = 6.0,
    double arcCrossfadeRate = 16.0,
  }) {
    bool shuttleFired = false;

    if (onsetValue >= onsetEdgeThreshold &&
        !shuttleOnsetWasHigh &&
        (nowMs - lastShuttleFireMs) >= shuttleDebounceMs) {
      shuttleOnsetWasHigh = true;
      _fireShuttle(nowMs: nowMs, estimatedBpm: estimatedBpm);
      shuttleFired = true;
      if (zScoreMid || zScoreHigh) {
        shuttleNImpulse = (shuttleNImpulse + nImpulseOnset).clamp(
          0.0,
          nImpulseMax,
        );
      }
    } else if (onsetValue < onsetEdgeThreshold) {
      shuttleOnsetWasHigh = false;
    }

    if (!shuttleFired &&
        beatRisingEdge &&
        (nowMs - lastShuttleFireMs) >= shuttleDebounceMs) {
      _fireShuttle(nowMs: nowMs, estimatedBpm: estimatedBpm);
      shuttleFired = true;
    }

    if (zScoreMid && !shuttleZMidWasHigh) {
      shuttleRotSign = -shuttleRotSign;
      shuttleNImpulse = (shuttleNImpulse + nImpulseMid).clamp(0.0, nImpulseMax);
    }
    shuttleZMidWasHigh = zScoreMid;

    if (zScoreHigh && !shuttleZHighWasHigh) {
      shuttleRotSign = -shuttleRotSign;
      shuttleNImpulse = (shuttleNImpulse + nImpulseHigh).clamp(
        0.0,
        nImpulseMax,
      );
    }
    shuttleZHighWasHigh = zScoreHigh;

    if (shuttleProgress >= 0.98) {
      _fireShuttle(nowMs: nowMs, estimatedBpm: estimatedBpm);
    }

    shuttleNImpulse *= exp(-nImpulseDecayRate * dtSec);
    if (shuttleNImpulse < 0.01) {
      shuttleNImpulse = 0.0;
    }

    shuttleProgress = (shuttleProgress + shuttleSpeed * dtSec).clamp(0.0, 1.0);

    final double arcTarget = shuttleDir.toDouble() * shuttleRotSign;
    shuttleArcBlend +=
        (arcTarget - shuttleArcBlend) * (1.0 - exp(-arcCrossfadeRate * dtSec));
  }

  (double alpha, double beta) computeThreePhasePosition({
    required double fillCenterY,
    required double fillRadius,
    required double fillAngle,
    required double fillHhImpulse,
    required double silenceFade,
    required double orbitRadius,
  }) {
    final double eased = quinticSmoothstep(shuttleProgress);
    final double position = shuttleDir > 0 ? eased : 1.0 - eased;

    final double combinedLevel =
        ((smoothedLeftLevel + smoothedRightLevel) * 0.5).clamp(0.0, 1.0);
    const double baseRadius = 0.40;
    final double maxArcRadius = orbitRadius.clamp(baseRadius, 1.0);
    final double arcRadius =
        baseRadius +
        combinedLevel * (maxArcRadius - baseRadius) +
        shuttleNImpulse * 0.70;

    final double stereoBias = smoothedRightLevel - smoothedLeftLevel;
    final double arcDir = shuttleArcBlend + stereoBias * 0.15;
    final (double arcAlpha, double arcBeta) = shuttleArc(
      position,
      arcRadius,
      arcDir,
    );

    final double microX =
        fillCenterY + fillRadius * cos(fillAngle) - fillHhImpulse;
    final double microY = fillRadius * sin(fillAngle);

    const double fillMix = 0.15;
    final double fade = silenceFade.clamp(0.1, 1.0);
    final double alpha = ((arcAlpha + microX * fillMix) * fade).clamp(
      -1.0,
      1.0,
    );
    final double beta = ((arcBeta + microY * fillMix) * fade).clamp(-1.0, 1.0);

    return (alpha, beta);
  }

  void reset() {
    onsetXtDrive = 0.0;
    smoothedLeftLevel = 0.0;
    smoothedRightLevel = 0.0;

    shuttleProgress = 0.0;
    shuttleDir = 1;
    shuttleSpeed = 2.0;
    shuttleArcBlend = 1.0;
    shuttleOnsetWasHigh = false;
    lastShuttleFireMs = 0;
    shuttleNImpulse = 0.0;
    shuttleRotSign = 1;
    shuttleZMidWasHigh = false;
    shuttleZHighWasHigh = false;
  }

  void _fireShuttle({required int nowMs, required double estimatedBpm}) {
    shuttleDir *= -1;
    shuttleProgress = 0.0;
    lastShuttleFireMs = nowMs;
    final double beatPeriodSec = 60.0 / estimatedBpm.clamp(40.0, 220.0);
    shuttleSpeed = 0.92 / beatPeriodSec;
  }

  double _normalizeOnsetWindow({
    required double value,
    required double minValue,
    required double maxValue,
  }) {
    final double normalizedMin = minValue.clamp(0.0, 1.0);
    final double normalizedMax = maxValue.clamp(0.0, 1.0);
    if ((normalizedMax - normalizedMin).abs() <= 1e-6) {
      return value >= normalizedMax ? 1.0 : 0.0;
    }
    return ((value - normalizedMin) / (normalizedMax - normalizedMin)).clamp(
      0.0,
      1.0,
    );
  }

  double _applyXtSmoothingStep({
    required double previous,
    required double target,
    required double dtSec,
    required double smoothing,
  }) {
    final double smoothingClamped = smoothing.clamp(0.0, 100.0);
    final double maxDeltaPer10ms =
        0.095 * ((100.0 - smoothingClamped) / 100.0) + 0.005;
    final double stepScale = (dtSec / 0.01).clamp(0.1, 30.0);
    final double maxDeltaThisStep = maxDeltaPer10ms * stepScale;

    final double delta = target - previous;
    if (delta > maxDeltaThisStep) {
      return (previous + maxDeltaThisStep).clamp(0.0, 1.0);
    }
    if (delta < -maxDeltaThisStep) {
      return (previous - maxDeltaThisStep).clamp(0.0, 1.0);
    }
    return target.clamp(0.0, 1.0);
  }
}
