import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AudioFeatures.zero has expected defaults', () {
    const AudioFeatures zero = AudioFeatures.zero;

    expect(zero.mono, 0.0);
    expect(zero.left, 0.0);
    expect(zero.right, 0.0);
    expect(zero.subBass, 0.0);
    expect(zero.bass, 0.0);
    expect(zero.lowMid, 0.0);
    expect(zero.mid, 0.0);
    expect(zero.upperMid, 0.0);
    expect(zero.presence, 0.0);
    expect(zero.brilliance, 0.0);
    expect(zero.dominantBassHz, 0.0);
    expect(zero.dominantFullHz, 0.0);
    expect(zero.flux, 0.0);
    expect(zero.onset, 0.0);
    expect(zero.beat, 0.0);
    expect(zero.zScoreBeat, isFalse);
    expect(zero.zScoreMid, isFalse);
    expect(zero.zScoreHigh, isFalse);
    expect(zero.fluxDropActive, isFalse);
    expect(zero.spectrumFillRatio, 0.0);
    expect(zero.metronomeBpm, 0.0);
    expect(zero.metronomeConfidence, 0.0);
    expect(zero.metronomePhase, 0.0);
    expect(zero.metronomeBeatTick, isFalse);
    expect(zero.isDownbeat, isFalse);
    expect(zero.isSyncopated, isFalse);
    expect(zero.rms, 0.0);
    expect(zero.db, -120.0);
    expect(zero.gateOpen, isFalse);
    expect(zero.bassLowHighRatio, closeTo(1.0, 1e-12));
  });

  test('AudioFeatures bassLowHighRatio derives low-vs-high spectral ratio', () {
    const AudioFeatures features = AudioFeatures(
      mono: 0.0,
      left: 0.0,
      right: 0.0,
      subBass: 0.6,
      bass: 0.1,
      lowMid: 0.4,
      mid: 0.0,
      upperMid: 0.0,
      presence: 0.2,
      brilliance: 0.3,
      dominantBassHz: 0.0,
      dominantFullHz: 0.0,
      flux: 0.0,
      onset: 0.0,
      beat: 0.0,
      zScoreBeat: false,
      zScoreMid: false,
      zScoreHigh: false,
      fluxDropActive: false,
      spectrumFillRatio: 0.0,
      metronomeBpm: 0.0,
      metronomeConfidence: 0.0,
      metronomePhase: 0.0,
      metronomeBeatTick: false,
      isDownbeat: false,
      isSyncopated: false,
      rms: 0.0,
      db: -120.0,
      gateOpen: false,
      energyFullness: 0.0,
    );

    expect(
      features.bassLowHighRatio,
      closeTo((0.6 + 0.4 + 1e-10) / (0.2 + 0.3 + 1e-10), 1e-12),
    );
  });
}
