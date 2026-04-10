import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/fill_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/gate_chain.dart';
import 'package:breadbeats_mobile/audio/motion/heartbeat_motion_state_controller.dart';
import 'package:breadbeats_mobile/audio/motion/onset_motion_engine.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/heartbeat_tick_precompute_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_tick_precompute_request_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatTickPrecomputeRequestMapper mapper =
      HeartbeatTickPrecomputeRequestMapper();

  test('maps provider tick inputs into a precompute request', () {
    final AudioFeatures features = AudioFeatures.zero;
    final HeartbeatMotionStateController motionState =
        HeartbeatMotionStateController(fillBaseRadius: 0.42);
    final BeatMotionEngine beatMotion = BeatMotionEngine();
    final FillMotionEngine fillMotion = FillMotionEngine();
    final GateChain gateChain = GateChain();
    final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

    double? observedConsumeNowSec;
    double? observedShouldForceSyncNowSec;
    double? observedStartupRampNowSec;

    final HeartbeatTickPrecomputeRequest request = mapper.map(
      input: HeartbeatTickPrecomputeRequestMapperInput(
        nowMs: 12345,
        hdlcDroppedFrames: 7,
        lastPcmTimestampMs: 12000,
        features: features,
        consumeDtSec: (double nowSec) {
          observedConsumeNowSec = nowSec;
          return 0.016;
        },
        shouldForceSync: (double nowSec) {
          observedShouldForceSyncNowSec = nowSec;
          return nowSec > 1.0;
        },
        mode: StimMode.beat,
        outputMode: OutputModeSelection.threePhase,
        sensitivity: 0.65,
        intensityCap: 4.2,
        onsetSensitivityMin: 0.11,
        onsetSensitivityMax: 0.87,
        onsetSmoothing: 30.0,
        motionState: motionState,
        fillBaseRadius: 0.5,
        fillHhImpulseSize: 0.15,
        fillHhDecayRate: 2.0,
        fillRotOmega: 1.3,
        buttonHoldMuted: true,
        buttonHoldRamp: 0.72,
        buttonResumeRampSec: 0.45,
        calibrationPattern: CalibrationPattern.circle,
        manualPulseMode: true,
        manualPulseHz: 18.0,
        pulseMinHz: 8.0,
        pulseMaxHz: 52.0,
        bassMonitorLowHz: 30.0,
        bassMonitorHighHz: 150.0,
        tempoUnlockHoldEnabled: true,
        energyResponseStrength: 1.3,
        latencyCompensationMs: -8.0,
        adaptiveLeadMs: 17.0,
        learningEnabled: true,
        committedCadenceHint: 1,
        hardFillGateEnabled: true,
        beatMotion: beatMotion,
        fillMotion: fillMotion,
        gateChain: gateChain,
        onsetMotion: onsetMotion,
        previousMotionDriveLevel: 0.57,
        startupRampAt: (double nowSec) {
          observedStartupRampNowSec = nowSec;
          return 0.8;
        },
        carrierHz: 550.0,
        carrierMinHz: 120.0,
        carrierMaxHz: 680.0,
        tauMicros: 300.0,
      ),
    );

    expect(request.nowMs, 12345);
    expect(request.hdlcDroppedFrames, 7);
    expect(request.lastPcmTimestampMs, 12000);
    expect(request.features, same(features));
    expect(request.mode, StimMode.beat);
    expect(request.outputMode, OutputModeSelection.threePhase);
    expect(request.sensitivity, closeTo(0.65, 1e-12));
    expect(request.intensityCap, closeTo(4.2, 1e-12));
    expect(request.onsetSensitivityMin, closeTo(0.11, 1e-12));
    expect(request.onsetSensitivityMax, closeTo(0.87, 1e-12));
    expect(request.onsetSmoothing, closeTo(30.0, 1e-12));
    expect(request.motionState, same(motionState));
    expect(request.fillBaseRadius, closeTo(0.5, 1e-12));
    expect(request.fillHhImpulseSize, closeTo(0.15, 1e-12));
    expect(request.fillHhDecayRate, closeTo(2.0, 1e-12));
    expect(request.fillRotOmega, closeTo(1.3, 1e-12));
    expect(request.buttonHoldMuted, isTrue);
    expect(request.buttonHoldRamp, closeTo(0.72, 1e-12));
    expect(request.buttonResumeRampSec, closeTo(0.45, 1e-12));
    expect(request.calibrationPattern, CalibrationPattern.circle);
    expect(request.manualPulseMode, isTrue);
    expect(request.manualPulseHz, closeTo(18.0, 1e-12));
    expect(request.pulseMinHz, closeTo(8.0, 1e-12));
    expect(request.pulseMaxHz, closeTo(52.0, 1e-12));
    expect(request.bassMonitorLowHz, closeTo(30.0, 1e-12));
    expect(request.bassMonitorHighHz, closeTo(150.0, 1e-12));
    expect(request.tempoUnlockHoldEnabled, isTrue);
    expect(request.energyResponseStrength, closeTo(1.3, 1e-12));
    expect(request.latencyCompensationMs, closeTo(-8.0, 1e-12));
    expect(request.adaptiveLeadMs, closeTo(17.0, 1e-12));
    expect(request.learningEnabled, isTrue);
    expect(request.committedCadenceHint, 1);
    expect(request.beatMotion, same(beatMotion));
    expect(request.fillMotion, same(fillMotion));
    expect(request.gateChain, same(gateChain));
    expect(request.onsetMotion, same(onsetMotion));
    expect(request.previousMotionDriveLevel, closeTo(0.57, 1e-12));
    expect(request.carrierHz, closeTo(550.0, 1e-12));
    expect(request.carrierMinHz, closeTo(120.0, 1e-12));
    expect(request.carrierMaxHz, closeTo(680.0, 1e-12));
    expect(request.tauMicros, closeTo(300.0, 1e-12));

    expect(request.consumeDtSec(2.5), closeTo(0.016, 1e-12));
    expect(observedConsumeNowSec, closeTo(2.5, 1e-12));

    expect(request.shouldForceSync(0.75), isFalse);
    expect(observedShouldForceSyncNowSec, closeTo(0.75, 1e-12));

    expect(request.startupRampAt(3.5), closeTo(0.8, 1e-12));
    expect(observedStartupRampNowSec, closeTo(3.5, 1e-12));
  });
}
