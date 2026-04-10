import 'dart:math';

import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/fill_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/gate_chain.dart';
import 'package:breadbeats_mobile/audio/motion/heartbeat_orchestrator.dart';
import 'package:breadbeats_mobile/audio/motion/onset_motion_engine.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/models/motion_constants.dart';
import 'package:flutter_test/flutter_test.dart';

AudioFeatures _features({
  double mono = 0.0,
  double subBass = 0.0,
  double bass = 0.0,
  double lowMid = 0.0,
  double mid = 0.0,
  double upperMid = 0.0,
  double presence = 0.0,
  double brilliance = 0.0,
  double flux = 0.0,
  double onset = 0.0,
  double beat = 0.0,
  bool zScoreBeat = false,
  bool fluxDropActive = false,
  double spectrumFillRatio = 0.0,
  double metronomeBpm = 0.0,
  double metronomeConfidence = 0.0,
  bool isDownbeat = false,
  bool isSyncopated = false,
  bool gateOpen = false,
}) {
  return AudioFeatures(
    mono: mono,
    left: mono,
    right: mono,
    subBass: subBass,
    bass: bass,
    lowMid: lowMid,
    mid: mid,
    upperMid: upperMid,
    presence: presence,
    brilliance: brilliance,
    dominantBassHz: 0.0,
    dominantFullHz: 0.0,
    flux: flux,
    onset: onset,
    beat: beat,
    zScoreBeat: zScoreBeat,
    zScoreMid: false,
    zScoreHigh: false,
    fluxDropActive: fluxDropActive,
    spectrumFillRatio: spectrumFillRatio,
    metronomeBpm: metronomeBpm,
    metronomeConfidence: metronomeConfidence,
    metronomePhase: 0.0,
    metronomeBeatTick: false,
    isDownbeat: isDownbeat,
    isSyncopated: isSyncopated,
    rms: mono,
    db: -40.0,
    gateOpen: gateOpen,
    energyFullness: 0.0,
  );
}

void main() {
  test('HeartbeatOrchestrator tick computes beat-mode drive and beat edge', () {
    const HeartbeatOrchestrator orchestrator = HeartbeatOrchestrator();
    final BeatMotionEngine beatMotion = BeatMotionEngine();
    final FillMotionEngine fillMotion = FillMotionEngine();
    final GateChain gateChain = GateChain();
    final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

    final HeartbeatOrchestratorOutput output = orchestrator.tick(
      input: HeartbeatOrchestratorInput(
        features: _features(
          mono: 0.5,
          subBass: 0.2,
          bass: 0.3,
          lowMid: 0.1,
          mid: 0.2,
          upperMid: 0.1,
          presence: 0.1,
          brilliance: 0.1,
          onset: 0.5,
          beat: 0.6,
          gateOpen: true,
        ),
        mode: StimMode.beat,
        outputMode: OutputModeSelection.fourPhase,
        sensitivity: 0.48,
        intensityCap: 20.0,
        dtSec: 0.033,
        nowMs: 1234,
        hasRecentPcm: true,
        onsetSensitivityMin: 0.0,
        onsetSensitivityMax: 1.0,
        onsetSmoothing: 0.0,
        fluxEmaPhrase: 0.0,
        phraseCommitted: false,
        phraseBeatCount: 0,
        phraseFluxAtStart: 0.0,
        lastBeatTriggerMs: 0,
        fillSilenceStartMs: 0,
        fillTransition: 0.0,
        fillAngle: 0.0,
        fillHhImpulse: 0.0,
        fillBaseRadius: fillBaseRadius,
        fillHhImpulseSize: fillHhImpulseSize,
        fillHhDecayRate: fillHhDecayRate,
        fillRotOmega: fillRotOmega,
        buttonHoldMuted: false,
        buttonHoldRamp: 1.0,
        buttonResumeRampSec: buttonResumeRampSec,
        calibrationPattern: CalibrationPattern.none,
        smoothedDominantBassHz: 0.0,
        manualPulseMode: true,
        manualPulseHz: 37.0,
        pulseMinHz: 5.0,
        pulseMaxHz: 80.0,
        bassMonitorLowHz: 20.0,
        bassMonitorHighHz: 250.0,
        tempoUnlockHoldEnabled: true,
        energyResponseStrength: 1.0,
        latencyCompensationMs: 0.0,
      ),
      beatMotion: beatMotion,
      fillMotion: fillMotion,
      gateChain: gateChain,
      onsetMotion: onsetMotion,
      previousMotionDriveLevel: 0.0,
    );

    final double expectedMotionDrive = 1.0 - exp(-0.033 / 0.045);
    expect(output.motionDriveLevel, closeTo(expectedMotionDrive, 1e-12));
    expect(output.effectivePulseHz, closeTo(37.0, 1e-12));
    expect(output.triggerKind, TriggerKind.beat);
    expect(output.estimatedBpm, closeTo(120.0, 1e-12));
    expect(output.silenceFade, closeTo(0.033 / 1.8, 1e-12));
    expect(output.beatRisingEdge, isTrue);
    expect(output.fluxEmaPhrase, closeTo(0.0, 1e-12));
    expect(output.tempoLocked, isFalse);
    expect(output.effectiveBpm, closeTo(120.0, 1e-12));
    expect(output.phraseCommitted, isTrue);
    expect(output.phraseBeatCount, 1);
    expect(output.phraseFluxAtStart, closeTo(0.0, 1e-12));
    expect(output.lastBeatTriggerMs, 1234);
    expect(output.fillSilenceStartMs, 0);
    expect(output.fillTransition, closeTo(0.0, 1e-12));
    expect(output.fillCenterY, closeTo(0.0, 1e-12));
    expect(output.fillRadius, closeTo(fillBaseRadius, 1e-12));
    expect(output.fillAngle, closeTo(fillRotOmega * 0.033, 1e-12));
    expect(output.fillHhImpulse, closeTo(0.0, 1e-12));
    expect(output.blendX.isFinite, isTrue);
    expect(output.blendY.isFinite, isTrue);
    expect(output.blendedAngle.isFinite, isTrue);
    expect(output.buttonHoldRamp, closeTo(1.0, 1e-12));
    expect(output.outputDrive, closeTo(expectedMotionDrive, 1e-12));
    expect(output.base, closeTo(0.2 * expectedMotionDrive, 1e-12));
    expect(
      output.amplitudeAmps,
      closeTo(0.12 * 0.2 * expectedMotionDrive, 1e-12),
    );
    expect(output.smoothedDominantBassHz, closeTo(0.0, 1e-12));
  });

  test(
    'HeartbeatOrchestrator tick applies adaptive lead to beat edge timestamp compensation',
    () {
      const HeartbeatOrchestrator orchestrator = HeartbeatOrchestrator();
      final BeatMotionEngine beatMotion = BeatMotionEngine()
        ..lastBeatEdgeMs = 1000
        ..beatIntervals.add(0.5);
      final FillMotionEngine fillMotion = FillMotionEngine();
      final GateChain gateChain = GateChain();
      final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

      orchestrator.tick(
        input: HeartbeatOrchestratorInput(
          features: _features(mono: 0.4, beat: 0.7, gateOpen: true),
          mode: StimMode.beat,
          outputMode: OutputModeSelection.fourPhase,
          sensitivity: 0.5,
          intensityCap: 20.0,
          dtSec: 0.033,
          nowMs: 2000,
          hasRecentPcm: true,
          onsetSensitivityMin: 0.0,
          onsetSensitivityMax: 1.0,
          onsetSmoothing: 0.0,
          fluxEmaPhrase: 0.0,
          phraseCommitted: false,
          phraseBeatCount: 0,
          phraseFluxAtStart: 0.0,
          lastBeatTriggerMs: 0,
          fillSilenceStartMs: 0,
          fillTransition: 0.0,
          fillAngle: 0.0,
          fillHhImpulse: 0.0,
          fillBaseRadius: fillBaseRadius,
          fillHhImpulseSize: fillHhImpulseSize,
          fillHhDecayRate: fillHhDecayRate,
          fillRotOmega: fillRotOmega,
          buttonHoldMuted: false,
          buttonHoldRamp: 1.0,
          buttonResumeRampSec: buttonResumeRampSec,
          calibrationPattern: CalibrationPattern.none,
          smoothedDominantBassHz: 0.0,
          manualPulseMode: true,
          manualPulseHz: 30.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 80.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.0,
          latencyCompensationMs: 25.0,
          adaptiveLeadMs: 15.0,
        ),
        beatMotion: beatMotion,
        fillMotion: fillMotion,
        gateChain: gateChain,
        onsetMotion: onsetMotion,
        previousMotionDriveLevel: 0.0,
      );

      expect(beatMotion.lastBeatEdgeMs, 2040);
    },
  );

  test(
    'HeartbeatOrchestrator tick computes onset-mode drive via OnsetMotion',
    () {
      const HeartbeatOrchestrator orchestrator = HeartbeatOrchestrator();
      final BeatMotionEngine beatMotion = BeatMotionEngine();
      final FillMotionEngine fillMotion = FillMotionEngine();
      final GateChain gateChain = GateChain();
      final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

      final HeartbeatOrchestratorOutput output = orchestrator.tick(
        input: HeartbeatOrchestratorInput(
          features: _features(mono: 0.2, onset: 0.0, beat: 0.0, gateOpen: true),
          mode: StimMode.onset,
          outputMode: OutputModeSelection.threePhase,
          sensitivity: 0.0,
          intensityCap: 20.0,
          dtSec: 0.05,
          nowMs: 5000,
          hasRecentPcm: true,
          onsetSensitivityMin: 0.0,
          onsetSensitivityMax: 1.0,
          onsetSmoothing: 0.0,
          fluxEmaPhrase: 0.2,
          phraseCommitted: true,
          phraseBeatCount: 4,
          phraseFluxAtStart: 0.5,
          lastBeatTriggerMs: 4500,
          fillSilenceStartMs: 0,
          fillTransition: 0.0,
          fillAngle: 0.0,
          fillHhImpulse: 0.0,
          fillBaseRadius: fillBaseRadius,
          fillHhImpulseSize: fillHhImpulseSize,
          fillHhDecayRate: fillHhDecayRate,
          fillRotOmega: fillRotOmega,
          buttonHoldMuted: false,
          buttonHoldRamp: 1.0,
          buttonResumeRampSec: buttonResumeRampSec,
          calibrationPattern: CalibrationPattern.none,
          smoothedDominantBassHz: 0.0,
          manualPulseMode: true,
          manualPulseHz: 22.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 80.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.0,
          latencyCompensationMs: 0.0,
        ),
        beatMotion: beatMotion,
        fillMotion: fillMotion,
        gateChain: gateChain,
        onsetMotion: onsetMotion,
        previousMotionDriveLevel: 0.7,
      );

      expect(output.motionDriveLevel, closeTo(0.1, 1e-12));
      expect(output.effectivePulseHz, closeTo(22.0, 1e-12));
      expect(output.triggerKind, TriggerKind.fill);
      expect(output.estimatedBpm, closeTo(120.0, 1e-12));
      expect(output.silenceFade, closeTo(0.05 / 1.8, 1e-12));
      expect(output.beatRisingEdge, isFalse);
      final double expectedFluxEma =
          0.2 + (0.0 - 0.2) * (1.0 - exp(-0.05 / 0.3));
      expect(output.fluxEmaPhrase, closeTo(expectedFluxEma, 1e-12));
      expect(output.tempoLocked, isFalse);
      expect(output.effectiveBpm, closeTo(120.0, 1e-12));
      expect(output.phraseCommitted, isTrue);
      expect(output.phraseBeatCount, 4);
      expect(output.phraseFluxAtStart, closeTo(0.5, 1e-12));
      expect(output.lastBeatTriggerMs, 4500);
      expect(output.fillSilenceStartMs, 5000);
      expect(output.fillTransition, closeTo(1.0 - exp(-0.05 / 0.8), 1e-12));
      expect(output.fillCenterY, closeTo(0.0, 1e-12));
      expect(output.fillRadius, closeTo(fillBaseRadius, 1e-12));
      expect(output.fillAngle, closeTo(fillRotOmega * 0.10 * 0.05, 1e-12));
      expect(output.fillHhImpulse, closeTo(0.0, 1e-12));
      expect(output.blendX.isFinite, isTrue);
      expect(output.blendY.isFinite, isTrue);
      expect(output.blendedAngle.isFinite, isTrue);
      expect(output.buttonHoldRamp, closeTo(1.0, 1e-12));
      expect(output.outputDrive, closeTo(0.1, 1e-12));
      expect(output.base, closeTo(0.02, 1e-12));
      expect(output.amplitudeAmps, closeTo(0.0024, 1e-12));
      expect(output.smoothedDominantBassHz, closeTo(0.0, 1e-12));
    },
  );

  test(
    'HeartbeatOrchestrator tick demotes to fill when gate threshold trips',
    () {
      const HeartbeatOrchestrator orchestrator = HeartbeatOrchestrator();
      final BeatMotionEngine beatMotion = BeatMotionEngine();
      final FillMotionEngine fillMotion = FillMotionEngine();
      final GateChain gateChain = GateChain()..gateFailCount = 11;
      final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

      final HeartbeatOrchestratorOutput output = orchestrator.tick(
        input: HeartbeatOrchestratorInput(
          features: _features(mono: 0.3, onset: 0.2, beat: 0.7, gateOpen: true),
          mode: StimMode.beat,
          outputMode: OutputModeSelection.fourPhase,
          sensitivity: 0.4,
          intensityCap: 20.0,
          dtSec: 0.05,
          nowMs: 7000,
          hasRecentPcm: true,
          onsetSensitivityMin: 0.0,
          onsetSensitivityMax: 1.0,
          onsetSmoothing: 0.0,
          fluxEmaPhrase: 0.1,
          phraseCommitted: false,
          phraseBeatCount: 0,
          phraseFluxAtStart: 0.0,
          lastBeatTriggerMs: 0,
          fillSilenceStartMs: 0,
          fillTransition: 0.0,
          fillAngle: 0.0,
          fillHhImpulse: 0.0,
          fillBaseRadius: fillBaseRadius,
          fillHhImpulseSize: fillHhImpulseSize,
          fillHhDecayRate: fillHhDecayRate,
          fillRotOmega: fillRotOmega,
          buttonHoldMuted: false,
          buttonHoldRamp: 1.0,
          buttonResumeRampSec: buttonResumeRampSec,
          calibrationPattern: CalibrationPattern.none,
          smoothedDominantBassHz: 0.0,
          manualPulseMode: true,
          manualPulseHz: 33.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 80.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.0,
          latencyCompensationMs: 0.0,
        ),
        beatMotion: beatMotion,
        fillMotion: fillMotion,
        gateChain: gateChain,
        onsetMotion: onsetMotion,
        previousMotionDriveLevel: 0.0,
      );

      expect(output.triggerKind, TriggerKind.fill);
      expect(output.fillSilenceStartMs, 7000);
      expect(output.fillTransition, closeTo(1.0 - exp(-0.05 / 0.8), 1e-12));
      expect(output.fillCenterY, closeTo(0.0, 1e-12));
      expect(output.fillRadius, closeTo(fillBaseRadius, 1e-12));
      expect(output.fillAngle, closeTo(fillRotOmega * 0.10 * 0.05, 1e-12));
      expect(output.fillHhImpulse, closeTo(0.0, 1e-12));
      expect(output.buttonHoldRamp, closeTo(1.0, 1e-12));
      expect(output.outputDrive, greaterThan(0.0));
      expect(output.base, greaterThan(0.0));
      expect(output.amplitudeAmps, greaterThan(0.0));
      expect(output.smoothedDominantBassHz, closeTo(0.0, 1e-12));
      expect(gateChain.gateFailCount, 0);
    },
  );

  test(
    'HeartbeatOrchestrator tick promotes fill to beat during committed phrase when gate did not demote',
    () {
      const HeartbeatOrchestrator orchestrator = HeartbeatOrchestrator();
      final BeatMotionEngine beatMotion = BeatMotionEngine()
        ..triggerKind = TriggerKind.fill;
      final FillMotionEngine fillMotion = FillMotionEngine();
      final GateChain gateChain = GateChain();
      final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

      final HeartbeatOrchestratorOutput output = orchestrator.tick(
        input: HeartbeatOrchestratorInput(
          features: _features(mono: 0.2, beat: 0.0, gateOpen: true),
          mode: StimMode.beat,
          outputMode: OutputModeSelection.fourPhase,
          sensitivity: 0.4,
          intensityCap: 20.0,
          dtSec: 0.05,
          nowMs: 8000,
          hasRecentPcm: true,
          onsetSensitivityMin: 0.0,
          onsetSensitivityMax: 1.0,
          onsetSmoothing: 0.0,
          fluxEmaPhrase: 0.2,
          phraseCommitted: true,
          phraseBeatCount: 3,
          phraseFluxAtStart: 0.4,
          lastBeatTriggerMs: 0,
          fillSilenceStartMs: 0,
          fillTransition: 0.0,
          fillAngle: 0.0,
          fillHhImpulse: 0.0,
          fillBaseRadius: fillBaseRadius,
          fillHhImpulseSize: fillHhImpulseSize,
          fillHhDecayRate: fillHhDecayRate,
          fillRotOmega: fillRotOmega,
          buttonHoldMuted: false,
          buttonHoldRamp: 1.0,
          buttonResumeRampSec: buttonResumeRampSec,
          calibrationPattern: CalibrationPattern.none,
          smoothedDominantBassHz: 0.0,
          manualPulseMode: true,
          manualPulseHz: 33.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 80.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.0,
          latencyCompensationMs: 0.0,
        ),
        beatMotion: beatMotion,
        fillMotion: fillMotion,
        gateChain: gateChain,
        onsetMotion: onsetMotion,
        previousMotionDriveLevel: 0.0,
      );

      expect(output.beatRisingEdge, isFalse);
      expect(output.triggerKind, TriggerKind.beat);
    },
  );

  test(
    'HeartbeatOrchestrator tick keeps fill during committed phrase when gates demote',
    () {
      const HeartbeatOrchestrator orchestrator = HeartbeatOrchestrator();
      final BeatMotionEngine beatMotion = BeatMotionEngine();
      final FillMotionEngine fillMotion = FillMotionEngine();
      final GateChain gateChain = GateChain()..gateFailCount = 11;
      final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

      final HeartbeatOrchestratorOutput output = orchestrator.tick(
        input: HeartbeatOrchestratorInput(
          features: _features(mono: 0.3, onset: 0.2, beat: 0.7, gateOpen: true),
          mode: StimMode.beat,
          outputMode: OutputModeSelection.fourPhase,
          sensitivity: 0.4,
          intensityCap: 20.0,
          dtSec: 0.05,
          nowMs: 9000,
          hasRecentPcm: true,
          onsetSensitivityMin: 0.0,
          onsetSensitivityMax: 1.0,
          onsetSmoothing: 0.0,
          fluxEmaPhrase: 0.3,
          phraseCommitted: true,
          phraseBeatCount: 2,
          phraseFluxAtStart: 0.2,
          lastBeatTriggerMs: 0,
          fillSilenceStartMs: 0,
          fillTransition: 0.0,
          fillAngle: 0.0,
          fillHhImpulse: 0.0,
          fillBaseRadius: fillBaseRadius,
          fillHhImpulseSize: fillHhImpulseSize,
          fillHhDecayRate: fillHhDecayRate,
          fillRotOmega: fillRotOmega,
          buttonHoldMuted: false,
          buttonHoldRamp: 1.0,
          buttonResumeRampSec: buttonResumeRampSec,
          calibrationPattern: CalibrationPattern.none,
          smoothedDominantBassHz: 0.0,
          manualPulseMode: true,
          manualPulseHz: 33.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 80.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.0,
          latencyCompensationMs: 0.0,
        ),
        beatMotion: beatMotion,
        fillMotion: fillMotion,
        gateChain: gateChain,
        onsetMotion: onsetMotion,
        previousMotionDriveLevel: 0.0,
      );

      expect(output.beatRisingEdge, isTrue);
      expect(output.triggerKind, TriggerKind.fill);
    },
  );

  test(
    'HeartbeatOrchestrator tick keeps fill during committed phrase when gate is closed',
    () {
      const HeartbeatOrchestrator orchestrator = HeartbeatOrchestrator();
      final BeatMotionEngine beatMotion = BeatMotionEngine()
        ..triggerKind = TriggerKind.fill;
      final FillMotionEngine fillMotion = FillMotionEngine();
      final GateChain gateChain = GateChain();
      final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

      final HeartbeatOrchestratorOutput output = orchestrator.tick(
        input: HeartbeatOrchestratorInput(
          features: _features(mono: 0.2, beat: 0.0, gateOpen: false),
          mode: StimMode.beat,
          outputMode: OutputModeSelection.fourPhase,
          sensitivity: 0.4,
          intensityCap: 20.0,
          dtSec: 0.05,
          nowMs: 10000,
          hasRecentPcm: true,
          onsetSensitivityMin: 0.0,
          onsetSensitivityMax: 1.0,
          onsetSmoothing: 0.0,
          fluxEmaPhrase: 0.2,
          phraseCommitted: true,
          phraseBeatCount: 3,
          phraseFluxAtStart: 0.4,
          lastBeatTriggerMs: 0,
          fillSilenceStartMs: 0,
          fillTransition: 0.0,
          fillAngle: 0.0,
          fillHhImpulse: 0.0,
          fillBaseRadius: fillBaseRadius,
          fillHhImpulseSize: fillHhImpulseSize,
          fillHhDecayRate: fillHhDecayRate,
          fillRotOmega: fillRotOmega,
          buttonHoldMuted: false,
          buttonHoldRamp: 1.0,
          buttonResumeRampSec: buttonResumeRampSec,
          calibrationPattern: CalibrationPattern.none,
          smoothedDominantBassHz: 0.0,
          manualPulseMode: true,
          manualPulseHz: 33.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 80.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.0,
          latencyCompensationMs: 0.0,
        ),
        beatMotion: beatMotion,
        fillMotion: fillMotion,
        gateChain: gateChain,
        onsetMotion: onsetMotion,
        previousMotionDriveLevel: 0.0,
      );

      expect(output.triggerKind, TriggerKind.fill);
    },
  );

  test(
    'HeartbeatOrchestrator tick captures wasInFill before classification for phrase entry',
    () {
      const HeartbeatOrchestrator orchestrator = HeartbeatOrchestrator();
      final BeatMotionEngine beatMotion = BeatMotionEngine()
        ..triggerKind = TriggerKind.fill;
      final FillMotionEngine fillMotion = FillMotionEngine();
      final GateChain gateChain = GateChain();
      final OnsetMotionEngine onsetMotion = OnsetMotionEngine();

      final HeartbeatOrchestratorOutput output = orchestrator.tick(
        input: HeartbeatOrchestratorInput(
          features: _features(mono: 0.3, onset: 0.2, beat: 0.7, gateOpen: true),
          mode: StimMode.beat,
          outputMode: OutputModeSelection.fourPhase,
          sensitivity: 0.4,
          intensityCap: 20.0,
          dtSec: 0.05,
          nowMs: 11000,
          hasRecentPcm: true,
          onsetSensitivityMin: 0.0,
          onsetSensitivityMax: 1.0,
          onsetSmoothing: 0.0,
          fluxEmaPhrase: 0.3,
          phraseCommitted: false,
          phraseBeatCount: 0,
          phraseFluxAtStart: 0.0,
          lastBeatTriggerMs: 0,
          fillSilenceStartMs: 0,
          fillTransition: 0.0,
          fillAngle: 0.0,
          fillHhImpulse: 0.0,
          fillBaseRadius: fillBaseRadius,
          fillHhImpulseSize: fillHhImpulseSize,
          fillHhDecayRate: fillHhDecayRate,
          fillRotOmega: fillRotOmega,
          buttonHoldMuted: false,
          buttonHoldRamp: 1.0,
          buttonResumeRampSec: buttonResumeRampSec,
          calibrationPattern: CalibrationPattern.none,
          smoothedDominantBassHz: 0.0,
          manualPulseMode: true,
          manualPulseHz: 33.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 80.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.0,
          latencyCompensationMs: 0.0,
        ),
        beatMotion: beatMotion,
        fillMotion: fillMotion,
        gateChain: gateChain,
        onsetMotion: onsetMotion,
        previousMotionDriveLevel: 0.0,
      );

      expect(output.beatRisingEdge, isTrue);
      expect(output.phraseCommitted, isTrue);
      expect(output.phraseBeatCount, 1);
    },
  );

  test(
    'HeartbeatOrchestrator tick attenuates subBass bloom for neutral transient profile under tempo lock',
    () {
      const HeartbeatOrchestrator orchestrator = HeartbeatOrchestrator();

      final BeatMotionEngine neutralBeatMotion = BeatMotionEngine();
      final FillMotionEngine neutralFillMotion = FillMotionEngine();
      final GateChain neutralGateChain = GateChain();
      final OnsetMotionEngine neutralOnsetMotion = OnsetMotionEngine();

      orchestrator.tick(
        input: HeartbeatOrchestratorInput(
          features: _features(
            mono: 0.4,
            subBass: 0.15,
            lowMid: 0.10,
            presence: 0.60,
            brilliance: 0.35,
            flux: 0.25,
            gateOpen: true,
            metronomeBpm: 128.0,
            metronomeConfidence: 0.9,
          ),
          mode: StimMode.beat,
          outputMode: OutputModeSelection.fourPhase,
          sensitivity: 0.5,
          intensityCap: 20.0,
          dtSec: 0.1,
          nowMs: 12000,
          hasRecentPcm: true,
          onsetSensitivityMin: 0.0,
          onsetSensitivityMax: 1.0,
          onsetSmoothing: 0.0,
          fluxEmaPhrase: 0.0,
          phraseCommitted: false,
          phraseBeatCount: 0,
          phraseFluxAtStart: 0.0,
          lastBeatTriggerMs: 0,
          fillSilenceStartMs: 0,
          fillTransition: 0.0,
          fillAngle: 0.0,
          fillHhImpulse: 0.0,
          fillBaseRadius: fillBaseRadius,
          fillHhImpulseSize: fillHhImpulseSize,
          fillHhDecayRate: fillHhDecayRate,
          fillRotOmega: fillRotOmega,
          buttonHoldMuted: false,
          buttonHoldRamp: 1.0,
          buttonResumeRampSec: buttonResumeRampSec,
          calibrationPattern: CalibrationPattern.none,
          smoothedDominantBassHz: 0.0,
          manualPulseMode: true,
          manualPulseHz: 30.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 80.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.0,
          latencyCompensationMs: 0.0,
        ),
        beatMotion: neutralBeatMotion,
        fillMotion: neutralFillMotion,
        gateChain: neutralGateChain,
        onsetMotion: neutralOnsetMotion,
        previousMotionDriveLevel: 0.0,
      );

      final BeatMotionEngine dominantBeatMotion = BeatMotionEngine();
      final FillMotionEngine dominantFillMotion = FillMotionEngine();
      final GateChain dominantGateChain = GateChain();
      final OnsetMotionEngine dominantOnsetMotion = OnsetMotionEngine();

      orchestrator.tick(
        input: HeartbeatOrchestratorInput(
          features: _features(
            mono: 0.4,
            subBass: 0.60,
            lowMid: 0.45,
            presence: 0.10,
            brilliance: 0.05,
            flux: 0.25,
            gateOpen: true,
            metronomeBpm: 128.0,
            metronomeConfidence: 0.9,
          ),
          mode: StimMode.beat,
          outputMode: OutputModeSelection.fourPhase,
          sensitivity: 0.5,
          intensityCap: 20.0,
          dtSec: 0.1,
          nowMs: 12000,
          hasRecentPcm: true,
          onsetSensitivityMin: 0.0,
          onsetSensitivityMax: 1.0,
          onsetSmoothing: 0.0,
          fluxEmaPhrase: 0.0,
          phraseCommitted: false,
          phraseBeatCount: 0,
          phraseFluxAtStart: 0.0,
          lastBeatTriggerMs: 0,
          fillSilenceStartMs: 0,
          fillTransition: 0.0,
          fillAngle: 0.0,
          fillHhImpulse: 0.0,
          fillBaseRadius: fillBaseRadius,
          fillHhImpulseSize: fillHhImpulseSize,
          fillHhDecayRate: fillHhDecayRate,
          fillRotOmega: fillRotOmega,
          buttonHoldMuted: false,
          buttonHoldRamp: 1.0,
          buttonResumeRampSec: buttonResumeRampSec,
          calibrationPattern: CalibrationPattern.none,
          smoothedDominantBassHz: 0.0,
          manualPulseMode: true,
          manualPulseHz: 30.0,
          pulseMinHz: 5.0,
          pulseMaxHz: 80.0,
          bassMonitorLowHz: 20.0,
          bassMonitorHighHz: 250.0,
          tempoUnlockHoldEnabled: true,
          energyResponseStrength: 1.0,
          latencyCompensationMs: 0.0,
        ),
        beatMotion: dominantBeatMotion,
        fillMotion: dominantFillMotion,
        gateChain: dominantGateChain,
        onsetMotion: dominantOnsetMotion,
        previousMotionDriveLevel: 0.0,
      );

      expect(
        neutralBeatMotion.subBassBloom,
        lessThan(dominantBeatMotion.subBassBloom),
      );
    },
  );
}
