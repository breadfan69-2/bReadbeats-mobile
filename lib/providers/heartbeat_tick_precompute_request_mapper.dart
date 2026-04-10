import '../audio/motion/beat_motion_engine.dart';
import '../audio/motion/fill_motion_engine.dart';
import '../audio/motion/gate_chain.dart';
import '../audio/motion/heartbeat_motion_state_controller.dart';
import '../audio/motion/onset_motion_engine.dart';
import '../audio/processing/audio_signal_processor.dart';
import '../models/device_models.dart';
import '../models/enums.dart';
import 'heartbeat_tick_precompute_controller.dart';

class HeartbeatTickPrecomputeRequestMapperInput {
  const HeartbeatTickPrecomputeRequestMapperInput({
    required this.nowMs,
    required this.hdlcDroppedFrames,
    required this.lastPcmTimestampMs,
    required this.features,
    required this.consumeDtSec,
    required this.shouldForceSync,
    required this.mode,
    required this.outputMode,
    required this.sensitivity,
    required this.intensityCap,
    required this.onsetSensitivityMin,
    required this.onsetSensitivityMax,
    required this.onsetSmoothing,
    required this.motionState,
    required this.fillBaseRadius,
    required this.fillHhImpulseSize,
    required this.fillHhDecayRate,
    required this.fillRotOmega,
    required this.buttonHoldMuted,
    required this.buttonHoldRamp,
    required this.buttonResumeRampSec,
    required this.calibrationPattern,
    required this.manualPulseMode,
    required this.manualPulseHz,
    required this.pulseMinHz,
    required this.pulseMaxHz,
    required this.bassMonitorLowHz,
    required this.bassMonitorHighHz,
    required this.tempoUnlockHoldEnabled,
    required this.energyResponseStrength,
    required this.latencyCompensationMs,
    required this.adaptiveLeadMs,
    required this.learningEnabled,
    required this.committedCadenceHint,
    required this.hardFillGateEnabled,
    required this.beatMotion,
    required this.fillMotion,
    required this.gateChain,
    required this.onsetMotion,
    required this.previousMotionDriveLevel,
    required this.startupRampAt,
    required this.carrierHz,
    required this.carrierMinHz,
    required this.carrierMaxHz,
    required this.tauMicros,
  });

  final int nowMs;
  final int hdlcDroppedFrames;
  final int lastPcmTimestampMs;
  final AudioFeatures features;
  final double Function(double nowSec) consumeDtSec;
  final bool Function(double nowSec) shouldForceSync;
  final StimMode mode;
  final OutputModeSelection outputMode;
  final double sensitivity;
  final double intensityCap;
  final double onsetSensitivityMin;
  final double onsetSensitivityMax;
  final double onsetSmoothing;
  final HeartbeatMotionStateController motionState;
  final double fillBaseRadius;
  final double fillHhImpulseSize;
  final double fillHhDecayRate;
  final double fillRotOmega;
  final bool buttonHoldMuted;
  final double buttonHoldRamp;
  final double buttonResumeRampSec;
  final CalibrationPattern calibrationPattern;
  final bool manualPulseMode;
  final double manualPulseHz;
  final double pulseMinHz;
  final double pulseMaxHz;
  final double bassMonitorLowHz;
  final double bassMonitorHighHz;
  final bool tempoUnlockHoldEnabled;
  final double energyResponseStrength;
  final double latencyCompensationMs;
  final double adaptiveLeadMs;
  final bool learningEnabled;
  final int committedCadenceHint;
  final bool hardFillGateEnabled;
  final BeatMotionEngine beatMotion;
  final FillMotionEngine fillMotion;
  final GateChain gateChain;
  final OnsetMotionEngine onsetMotion;
  final double previousMotionDriveLevel;
  final double Function(double nowSec) startupRampAt;
  final double carrierHz;
  final double carrierMinHz;
  final double carrierMaxHz;
  final double tauMicros;
}

class HeartbeatTickPrecomputeRequestMapper {
  const HeartbeatTickPrecomputeRequestMapper();

  HeartbeatTickPrecomputeRequest map({
    required HeartbeatTickPrecomputeRequestMapperInput input,
  }) {
    return HeartbeatTickPrecomputeRequest(
      nowMs: input.nowMs,
      hdlcDroppedFrames: input.hdlcDroppedFrames,
      lastPcmTimestampMs: input.lastPcmTimestampMs,
      features: input.features,
      consumeDtSec: input.consumeDtSec,
      shouldForceSync: input.shouldForceSync,
      mode: input.mode,
      outputMode: input.outputMode,
      sensitivity: input.sensitivity,
      intensityCap: input.intensityCap,
      onsetSensitivityMin: input.onsetSensitivityMin,
      onsetSensitivityMax: input.onsetSensitivityMax,
      onsetSmoothing: input.onsetSmoothing,
      motionState: input.motionState,
      fillBaseRadius: input.fillBaseRadius,
      fillHhImpulseSize: input.fillHhImpulseSize,
      fillHhDecayRate: input.fillHhDecayRate,
      fillRotOmega: input.fillRotOmega,
      buttonHoldMuted: input.buttonHoldMuted,
      buttonHoldRamp: input.buttonHoldRamp,
      buttonResumeRampSec: input.buttonResumeRampSec,
      calibrationPattern: input.calibrationPattern,
      manualPulseMode: input.manualPulseMode,
      manualPulseHz: input.manualPulseHz,
      pulseMinHz: input.pulseMinHz,
      pulseMaxHz: input.pulseMaxHz,
      bassMonitorLowHz: input.bassMonitorLowHz,
      bassMonitorHighHz: input.bassMonitorHighHz,
      tempoUnlockHoldEnabled: input.tempoUnlockHoldEnabled,
      energyResponseStrength: input.energyResponseStrength,
      latencyCompensationMs: input.latencyCompensationMs,
      adaptiveLeadMs: input.adaptiveLeadMs,
      learningEnabled: input.learningEnabled,
      committedCadenceHint: input.committedCadenceHint,
      hardFillGateEnabled: input.hardFillGateEnabled,
      beatMotion: input.beatMotion,
      fillMotion: input.fillMotion,
      gateChain: input.gateChain,
      onsetMotion: input.onsetMotion,
      previousMotionDriveLevel: input.previousMotionDriveLevel,
      startupRampAt: input.startupRampAt,
      carrierHz: input.carrierHz,
      carrierMinHz: input.carrierMinHz,
      carrierMaxHz: input.carrierMaxHz,
      tauMicros: input.tauMicros,
    );
  }
}
