import 'package:breadbeats_mobile/audio/motion/gate_chain.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/models/motion_constants.dart';
import 'package:flutter_test/flutter_test.dart';

AudioFeatures _features({
  double spectrumFillRatio = 0.0,
  bool fluxDropActive = false,
  double metronomeBpm = 0.0,
  double metronomeConfidence = 0.0,
}) {
  return AudioFeatures(
    mono: 0.0,
    left: 0.0,
    right: 0.0,
    subBass: 0.0,
    bass: 0.0,
    lowMid: 0.0,
    mid: 0.0,
    upperMid: 0.0,
    presence: 0.0,
    brilliance: 0.0,
    dominantBassHz: 0.0,
    dominantFullHz: 0.0,
    flux: 0.0,
    onset: 0.0,
    beat: 0.0,
    zScoreBeat: false,
    zScoreMid: false,
    zScoreHigh: false,
    fluxDropActive: fluxDropActive,
    spectrumFillRatio: spectrumFillRatio,
    metronomeBpm: metronomeBpm,
    metronomeConfidence: metronomeConfidence,
    metronomePhase: 0.0,
    metronomeBeatTick: false,
    isDownbeat: false,
    isSyncopated: false,
    rms: 0.0,
    db: -120.0,
    gateOpen: true,
    energyFullness: 0.0,
  );
}

void main() {
  test('GateChain updateTempoLock applies enter/exit hysteresis', () {
    final GateChain chain = GateChain();

    expect(
      chain.updateTempoLock(
        _features(metronomeBpm: 0.0, metronomeConfidence: 0.9),
        tempoUnlockHoldEnabled: false,
      ),
      isFalse,
    );
    expect(
      chain.updateTempoLock(
        _features(
          metronomeBpm: 120.0,
          metronomeConfidence: tempoLockEnterConfidence,
        ),
        tempoUnlockHoldEnabled: false,
      ),
      isTrue,
    );
    expect(
      chain.updateTempoLock(
        _features(metronomeBpm: 120.0, metronomeConfidence: 0.16),
        tempoUnlockHoldEnabled: false,
      ),
      isTrue,
    );
    expect(
      chain.updateTempoLock(
        _features(metronomeBpm: 120.0, metronomeConfidence: 0.14),
        tempoUnlockHoldEnabled: false,
      ),
      isFalse,
    );
  });

  test(
    'GateChain updateStrokeReadiness applies grace and block hysteresis',
    () {
      final GateChain chain = GateChain();

      chain.updateStrokeReadiness(tempoLocked: true, nowMs: 100);
      chain.updateStrokeReadiness(tempoLocked: true, nowMs: 200);
      expect(chain.strokeReady, isFalse);

      chain.updateStrokeReadiness(tempoLocked: true, nowMs: 300);
      expect(chain.strokeReady, isTrue);

      chain.updateStrokeReadiness(tempoLocked: false, nowMs: 400);
      chain.updateStrokeReadiness(tempoLocked: false, nowMs: 500);
      chain.updateStrokeReadiness(tempoLocked: false, nowMs: 600);
      chain.updateStrokeReadiness(tempoLocked: false, nowMs: 700);
      expect(chain.strokeReady, isTrue);

      chain.updateStrokeReadiness(tempoLocked: false, nowMs: 1200);
      chain.updateStrokeReadiness(tempoLocked: false, nowMs: 1300);
      expect(chain.strokeReady, isTrue);

      chain.updateStrokeReadiness(tempoLocked: false, nowMs: 1400);
      expect(chain.strokeReady, isFalse);
    },
  );

  test(
    'GateChain evaluateBeatGates enforces spectral sustain by trigger kind',
    () {
      final GateChain chain = GateChain();

      chain.updateStrokeReadiness(tempoLocked: true, nowMs: 100);
      chain.updateStrokeReadiness(tempoLocked: true, nowMs: 200);
      chain.updateStrokeReadiness(tempoLocked: true, nowMs: 300);
      expect(chain.strokeReady, isTrue);

      final bool first = chain.evaluateBeatGates(
        features: _features(spectrumFillRatio: specFillThresholdBeat),
        dtSec: 0.10,
        triggerKind: TriggerKind.beat,
      );
      final bool second = chain.evaluateBeatGates(
        features: _features(spectrumFillRatio: specFillThresholdBeat),
        dtSec: 0.10,
        triggerKind: TriggerKind.beat,
      );

      expect(first, isTrue);
      expect(second, isTrue);
      expect(chain.gateFailCount, 0);
      expect(
        chain.specFillPassSeconds,
        greaterThanOrEqualTo(specFillSustainBeatSec),
      );
    },
  );

  test('GateChain evaluateBeatGates demotes after fail threshold', () {
    final GateChain chain = GateChain();

    for (int i = 0; i < gateFailThreshold - 1; i += 1) {
      final bool keepPromoted = chain.evaluateBeatGates(
        features: _features(fluxDropActive: true),
        dtSec: 0.05,
        triggerKind: TriggerKind.beat,
      );
      expect(keepPromoted, isTrue);
    }

    final bool demote = chain.evaluateBeatGates(
      features: _features(fluxDropActive: true),
      dtSec: 0.05,
      triggerKind: TriggerKind.beat,
    );
    expect(demote, isFalse);
    expect(chain.gateFailCount, gateFailThreshold);
  });

  test('GateChain resetFillTracking clears fill-demotion counters', () {
    final GateChain chain = GateChain()
      ..gateFailCount = 5
      ..specFillPassSeconds = 0.7
      ..specFillKind = TriggerKind.downbeat;

    chain.resetFillTracking();

    expect(chain.gateFailCount, 0);
    expect(chain.specFillPassSeconds, 0.0);
    expect(chain.specFillKind, TriggerKind.fill);
  });
}
