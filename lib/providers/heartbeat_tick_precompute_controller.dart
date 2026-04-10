import '../audio/motion/beat_motion_engine.dart';
import '../audio/motion/fill_motion_engine.dart';
import '../audio/motion/gate_chain.dart';
import '../audio/motion/heartbeat_motion_state_controller.dart';
import '../audio/motion/heartbeat_orchestrator.dart';
import '../audio/motion/onset_motion_engine.dart';
import '../audio/processing/audio_signal_processor.dart';
import '../models/device_models.dart';
import '../models/enums.dart';
import 'heartbeat_orchestrator_input_mapper.dart';
import 'heartbeat_tick_prelude_mapper.dart';
import 'heartbeat_waveform_output_mapper.dart';

class HeartbeatTickPrecompute {
  const HeartbeatTickPrecompute({
    required this.hdlcDroppedFrames,
    required this.nowSec,
    required this.nowMs,
    required this.dtSec,
    required this.forceSync,
    required this.features,
    required this.heartbeatPrelude,
    required this.carrierToSend,
    required this.amplitudeToSend,
  });

  final int hdlcDroppedFrames;
  final double nowSec;
  final int nowMs;
  final double dtSec;
  final bool forceSync;
  final AudioFeatures features;
  final HeartbeatOrchestratorOutput heartbeatPrelude;
  final double carrierToSend;
  final double amplitudeToSend;
}

class HeartbeatTickPrecomputeRequest {
  const HeartbeatTickPrecomputeRequest({
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

class HeartbeatTickPrecomputeController {
  const HeartbeatTickPrecomputeController({
    this.heartbeatTickPreludeMapper = const HeartbeatTickPreludeMapper(),
    this.heartbeatOrchestratorInputMapper =
        const HeartbeatOrchestratorInputMapper(),
    this.heartbeatOrchestrator = const HeartbeatOrchestrator(),
    this.heartbeatWaveformOutputMapper = const HeartbeatWaveformOutputMapper(),
  });

  final HeartbeatTickPreludeMapper heartbeatTickPreludeMapper;
  final HeartbeatOrchestratorInputMapper heartbeatOrchestratorInputMapper;
  final HeartbeatOrchestrator heartbeatOrchestrator;
  final HeartbeatWaveformOutputMapper heartbeatWaveformOutputMapper;

  HeartbeatTickPrecompute compute({
    required HeartbeatTickPrecomputeRequest request,
  }) {
    final HeartbeatTickPrelude tickPrelude = heartbeatTickPreludeMapper.map(
      nowMs: request.nowMs,
      hdlcDroppedFrames: request.hdlcDroppedFrames,
      lastPcmTimestampMs: request.lastPcmTimestampMs,
      features: request.features,
      consumeDtSec: request.consumeDtSec,
      shouldForceSync: request.shouldForceSync,
    );

    final HeartbeatOrchestratorInput orchestratorInput =
        heartbeatOrchestratorInputMapper.map(
          features: tickPrelude.features,
          mode: request.mode,
          outputMode: request.outputMode,
          sensitivity: request.sensitivity,
          intensityCap: request.intensityCap,
          dtSec: tickPrelude.dtSec,
          nowMs: tickPrelude.nowMs,
          hasRecentPcm: tickPrelude.hasRecentPcm,
          onsetSensitivityMin: request.onsetSensitivityMin,
          onsetSensitivityMax: request.onsetSensitivityMax,
          onsetSmoothing: request.onsetSmoothing,
          motionState: request.motionState,
          fillBaseRadius: request.fillBaseRadius,
          fillHhImpulseSize: request.fillHhImpulseSize,
          fillHhDecayRate: request.fillHhDecayRate,
          fillRotOmega: request.fillRotOmega,
          buttonHoldMuted: request.buttonHoldMuted,
          buttonHoldRamp: request.buttonHoldRamp,
          buttonResumeRampSec: request.buttonResumeRampSec,
          calibrationPattern: request.calibrationPattern,
          manualPulseMode: request.manualPulseMode,
          manualPulseHz: request.manualPulseHz,
          pulseMinHz: request.pulseMinHz,
          pulseMaxHz: request.pulseMaxHz,
          bassMonitorLowHz: request.bassMonitorLowHz,
          bassMonitorHighHz: request.bassMonitorHighHz,
          tempoUnlockHoldEnabled: request.tempoUnlockHoldEnabled,
          energyResponseStrength: request.energyResponseStrength,
          latencyCompensationMs: request.latencyCompensationMs,
          adaptiveLeadMs: request.adaptiveLeadMs,
          learningEnabled: request.learningEnabled,
          committedCadenceHint: request.committedCadenceHint,
          hardFillGateEnabled: request.hardFillGateEnabled,
        );

    final HeartbeatOrchestratorOutput heartbeatPrelude = heartbeatOrchestrator
        .tick(
          input: orchestratorInput,
          beatMotion: request.beatMotion,
          fillMotion: request.fillMotion,
          gateChain: request.gateChain,
          onsetMotion: request.onsetMotion,
          previousMotionDriveLevel: request.previousMotionDriveLevel,
        );

    final HeartbeatWaveformOutput waveformOutput = heartbeatWaveformOutputMapper
        .map(
          amplitudeAmps: heartbeatPrelude.amplitudeAmps,
          startupRamp: request.startupRampAt(tickPrelude.nowSec),
          carrierHz: request.carrierHz,
          carrierMinHz: request.carrierMinHz,
          carrierMaxHz: request.carrierMaxHz,
          tauMicros: request.tauMicros,
        );

    return HeartbeatTickPrecompute(
      hdlcDroppedFrames: tickPrelude.hdlcDroppedFrames,
      nowSec: tickPrelude.nowSec,
      nowMs: tickPrelude.nowMs,
      dtSec: tickPrelude.dtSec,
      forceSync: tickPrelude.forceSync,
      features: tickPrelude.features,
      heartbeatPrelude: heartbeatPrelude,
      carrierToSend: waveformOutput.carrierToSend,
      amplitudeToSend: waveformOutput.amplitudeToSend,
    );
  }
}
