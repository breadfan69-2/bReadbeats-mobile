import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:fftea/fftea.dart';

class AudioFeatures {
  const AudioFeatures({
    required this.mono,
    required this.left,
    required this.right,
    required this.subBass,
    required this.bass,
    required this.lowMid,
    required this.mid,
    required this.upperMid,
    required this.presence,
    required this.brilliance,
    required this.dominantBassHz,
    required this.dominantFullHz,
    required this.flux,
    required this.onset,
    required this.beat,
    required this.zScoreBeat,
    required this.zScoreMid,
    required this.zScoreHigh,
    required this.fluxDropActive,
    required this.spectrumFillRatio,
    required this.metronomeBpm,
    required this.metronomeConfidence,
    required this.metronomePhase,
    required this.metronomeBeatTick,
    required this.isDownbeat,
    required this.isSyncopated,
    required this.rms,
    required this.db,
    required this.gateOpen,
    required this.energyFullness,
  });

  final double mono;
  final double left;
  final double right;

  // 7-band spectral energy (XToys-style ranges)
  final double subBass; // 20–60 Hz
  final double bass; // 60–250 Hz
  final double lowMid; // 250–500 Hz
  final double mid; // 500–2000 Hz
  final double upperMid; // 2000–4000 Hz
  final double presence; // 4000–6000 Hz
  final double brilliance; // 6000–20000 Hz

  /// Peak frequency in the 20–250 Hz range (sub-bass + bass), in Hz.
  /// 0.0 when no meaningful bass content is detected.
  final double dominantBassHz;

  /// Peak frequency in the 80–8000 Hz range (full spectrum), in Hz.
  /// 0.0 when no meaningful content detected.
  final double dominantFullHz;

  final double flux;
  final double onset;
  final double beat;

  /// True when the z-score multi-band detector fired on the primary band.
  final bool zScoreBeat;

  /// True when the mid-band (500–4000 Hz) z-score detector fired.
  final bool zScoreMid;

  /// True when the high-band (2000–20000 Hz) z-score detector fired.
  final bool zScoreHigh;

  /// True when spectral flux has been suppressed for an extended period.
  final bool fluxDropActive;

  /// Fraction of FFT bins above dBFS threshold [0..1]. Gate chain input.
  final double spectrumFillRatio;

  /// ACF+PLL metronome BPM (0 when not locked).
  final double metronomeBpm;

  /// Current ACF confidence [0..1] used for tempo-lock decisions.
  final double metronomeConfidence;

  /// Metronome phase within current beat [0..1). 0 = on beat.
  final double metronomePhase;

  /// True on frames where the metronome crossed an integer beat boundary.
  final bool metronomeBeatTick;

  /// True when the metronome identifies this beat as measure position 1.
  final bool isDownbeat;

  /// True when an onset was detected near phase 0.5 (off-beat).
  final bool isSyncopated;

  final double rms;
  final double db;
  final bool gateOpen;

  /// Composite energy fullness [0..1]: smoothed mix of RMS + spectral bands.
  final double energyFullness;

  /// Combined low-frequency energy (sub-bass + bass), for backward compat.
  double get lowBand => (subBass + bass).clamp(0.0, 1.0);

  /// Combined mid energy (low-mid + mid + upper-mid).
  double get midBand => (lowMid + mid + upperMid).clamp(0.0, 1.0);

  /// Combined high energy (presence + brilliance).
  double get highBand => (presence + brilliance).clamp(0.0, 1.0);

  /// Ratio of low to high spectral content used for bass-dominance checks.
  double get bassLowHighRatio =>
      (subBass + lowMid + 1e-10) / (presence + brilliance + 1e-10);

  static const AudioFeatures zero = AudioFeatures(
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
}

/// Z-score peak detector (Brakel 2014).
///
/// Maintains a rolling window and fires when the current value exceeds the
/// rolling mean by [threshold] standard deviations.  Peaks barely influence
/// the rolling statistics ([influence] = 0.05) so the detector self-adapts
/// without being skewed by transients.
class ZScoreBandDetector {
  ZScoreBandDetector({
    this.lag = 30,
    this.threshold = 2.5,
    this.influence = 0.05,
  });

  final int lag;
  final double threshold;
  final double influence;

  final List<double> _buffer = <double>[];
  final List<double> _filtered = <double>[];
  double _mean = 0.0;
  double _std = 0.0;

  /// Returns `true` when the current [value] is a positive peak.
  bool update(double value) {
    if (_buffer.length < lag) {
      _buffer.add(value);
      _filtered.add(value);
      _updateStats();
      return false;
    }

    final double deviation = value - _mean;
    final bool peak = deviation > threshold * max(1e-8, _std);

    final double filteredValue = peak
        ? influence * value + (1.0 - influence) * _filtered.last
        : value;

    _buffer.add(value);
    _filtered.add(filteredValue);
    if (_buffer.length > lag) {
      _buffer.removeAt(0);
      _filtered.removeAt(0);
    }
    _updateStats();
    return peak;
  }

  void _updateStats() {
    if (_filtered.isEmpty) return;
    double sum = 0.0;
    for (final double v in _filtered) {
      sum += v;
    }
    _mean = sum / _filtered.length;
    double sumSq = 0.0;
    for (final double v in _filtered) {
      final double d = v - _mean;
      sumSq += d * d;
    }
    _std = sqrt(sumSq / _filtered.length);
  }

  void reset() {
    _buffer.clear();
    _filtered.clear();
    _mean = 0.0;
    _std = 0.0;
  }
}

class AudioSignalProcessor {
  AudioSignalProcessor({
    int fftSize = 2048,
    this.minDb = -58.0,
    this.maxDb = -12.0,
    this.noiseGateMinDb = -56.0,
    this.noiseGateMarginDb = 4.5,
    this.gateCloseHysteresisDb = 2.5,
    this.gateHoldMs = 220,
  }) : _fftSize = fftSize,
       _fft = FFT(fftSize),
       _window = _buildHannWindow(fftSize),
       _timeDomain = Float64List(fftSize),
       _monoBins = Float64List(fftSize ~/ 2 + 1);

  final int _fftSize;
  final FFT _fft;
  final Float64List _window;
  final Float64List _timeDomain;
  final Float64List _monoBins;

  final double minDb;
  final double maxDb;
  final double noiseGateMinDb;
  final double noiseGateMarginDb;
  final double gateCloseHysteresisDb;
  final int gateHoldMs;

  Float64List? _prevSpectrum;
  double _noiseFloorDb = -72.0;
  double _monoSmoothed = 0.0;
  double _leftSmoothed = 0.0;
  double _rightSmoothed = 0.0;
  double _fluxSmoothed = 0.0;
  double _fluxBaseline = 0.0;
  double _onsetPulse = 0.0;
  double _bassSmoothed = 0.0;
  double _bassBaseline = 0.0;
  double _bassDeltaBaseline = 0.0;
  double _beatPulse = 0.0;
  int _lastOnsetMs = 0;
  int _lastBeatMs = 0;
  bool _gateIsOpen = false;
  int _gateHoldUntilMs = 0;

  // ── Z-score multi-band peak detection ──
  final ZScoreBandDetector _zSubBass = ZScoreBandDetector();
  final ZScoreBandDetector _zLowMid = ZScoreBandDetector();
  final ZScoreBandDetector _zMid = ZScoreBandDetector();
  final ZScoreBandDetector _zHigh = ZScoreBandDetector();

  /// Rolling fire-counts per band over the last ~60 frames (~1 s).
  final List<int> _zBandFireCounts = <int>[
    0,
    0,
    0,
    0,
  ]; // sub_bass, low_mid, mid, high
  final List<List<bool>> _zBandFireHistory = <List<bool>>[
    <bool>[],
    <bool>[],
    <bool>[],
    <bool>[],
  ];
  static const int _zBandWindowSize = 60;
  int _primaryBand = 0; // index into the four bands

  // ── Flux-drop tracker ──
  double _fluxDropEma = 0.0;
  double _fluxDropPeak = 0.0;
  int _fluxDropFrames = 0; // consecutive frames below 40% of peak
  bool _fluxDropActive = false;
  static const int _fluxDropThresholdFrames = 27; // ~0.45 s at ~60 fps

  // ── Spectrum fill ratio (dBFS-referenced) ──
  double _dbfsRefMax = 0.0; // decaying peak for dBFS reference

  // ── ACF tempo estimation + metronome PLL ──
  static const int _onsetBufferMax = 260; // ~6 s at ~43 fps
  static const int _fpsCalibrationWindow = 128;
  static const double _acfMinConfidence = 0.08;
  static const double _metronomePllWindow = 0.35;
  static const int _beatsPerMeasure = 4;
  static const double _acfIntervalMs = 250.0;

  final List<double> _onsetBuffer = <double>[];
  final List<double> _callbackTimestamps = <double>[];
  double _fps = 43.0;

  // ACF state
  double _acfBpmSmoothed = 0.0;
  double _acfConfidence = 0.0;
  double _lastAcfRunMs = 0.0;

  // Metronome PLL state
  double _metronomeBpm = 0.0;
  double _metronomePhase = 0.0;
  double _metronomeConfHoldStart = 0.0;
  bool _metronomeCoasting = false;

  // Downbeat detection
  int _beatPositionInMeasure = 0; // 0-3
  final List<double> _measureEnergyAccum = <double>[0, 0, 0, 0];
  final List<int> _measureBeatCounts = <int>[0, 0, 0, 0];
  int _downbeatPosition = 0;
  int _totalMeasureBeats = 0; // total beats tracked for minimum threshold

  // Syncopation detection
  bool _syncoArmed = false;
  int _syncoStreak = 0;
  bool _hadOffbeat = false;
  bool _isSyncopated = false;

  // Energy fullness EMA
  double _energyFullnessEma = 0.0;

  // Transient density tracking for syncopation texture scaling
  int _transientFireCount = 0;
  double _transientWindowStartMs = 0.0;
  double _transientDensity = 0.0; // fires per second over ~1s window

  // Onset dedup
  double _lastAcceptedOnsetMs = 0.0;

  AudioFeatures processPcm16({
    required Uint8List bytes,
    required int frameSamples,
    required int sampleRate,
    required double sensitivity,
    required int timestampMs,
    int channels = 1,
    double bassMonitorLowHz = 20.0,
    double bassMonitorHighHz = 250.0,
    double estimatedBpm = 0.0,
  }) {
    if (sampleRate <= 0 || bytes.isEmpty) {
      return AudioFeatures.zero;
    }

    // Total interleaved samples in the buffer.
    final int totalSamples = bytes.lengthInBytes ~/ 2;
    // Per-channel sample count.
    final int perChannel = channels >= 2
        ? (frameSamples > 0
              ? min(totalSamples ~/ 2, frameSamples)
              : totalSamples ~/ 2)
        : (frameSamples > 0 ? min(totalSamples, frameSamples) : totalSamples);

    if (perChannel <= 0) {
      return AudioFeatures.zero;
    }

    final ByteData input = ByteData.sublistView(bytes);
    final bool isStereo = channels >= 2;
    final int stride = isStereo ? 2 : 1;
    final int count = perChannel; // per-channel frame count
    final int requiredBytes = count * stride * 2;

    if (bytes.lengthInBytes < requiredBytes) {
      debugPrint(
        '[AudioSignalProcessor] Buffer underrun: '
        'need $requiredBytes bytes, got ${bytes.lengthInBytes}',
      );
      return AudioFeatures.zero;
    }

    // Compute per-channel and mono RMS.
    double sumSquaresMono = 0.0;
    double sumSquaresL = 0.0;
    double sumSquaresR = 0.0;

    for (int i = 0; i < count; i += 1) {
      final int baseIdx = i * stride;
      final int sampleL = input.getInt16(baseIdx * 2, Endian.little);
      final double normL = sampleL / 32768.0;
      sumSquaresL += normL * normL;

      if (isStereo) {
        final int sampleR = input.getInt16((baseIdx + 1) * 2, Endian.little);
        final double normR = sampleR / 32768.0;
        sumSquaresR += normR * normR;
        final double mono = (normL + normR) * 0.5;
        sumSquaresMono += mono * mono;
      } else {
        sumSquaresMono += normL * normL;
      }
    }

    final double rms = sqrt(sumSquaresMono / count).clamp(0.0, 1.0);
    final double rmsL = sqrt(sumSquaresL / count).clamp(0.0, 1.0);
    final double rmsR = isStereo
        ? sqrt(sumSquaresR / count).clamp(0.0, 1.0)
        : rmsL;
    final double db = 20.0 * log(max(rms, 1e-6)) / ln10;
    final double dtSec = (count / sampleRate).clamp(0.001, 0.2);

    // Only update the noise floor while the gate is closed so the tracker
    // follows actual ambient noise, not the music level.
    if (!_gateIsOpen) {
      _noiseFloorDb = _smoothValue(
        previous: _noiseFloorDb,
        target: db,
        dtSec: dtSec,
        attackSec: 4.8,
        releaseSec: 8.0,
      );
    }

    final double gateDb = max(
      noiseGateMinDb,
      _noiseFloorDb + noiseGateMarginDb,
    );
    final double sensitivityBiasDb = sensitivity.clamp(0.0, 1.0) * 2.0;
    final double openThresholdDb = gateDb - sensitivityBiasDb;
    final double closeThresholdDb = openThresholdDb - gateCloseHysteresisDb;

    if (_gateIsOpen) {
      if (db < closeThresholdDb && timestampMs >= _gateHoldUntilMs) {
        _gateIsOpen = false;
      } else if (db >= closeThresholdDb) {
        // Only extend hold while signal is above the close threshold.
        _gateHoldUntilMs = timestampMs + gateHoldMs;
      }
    } else if (db >= openThresholdDb) {
      _gateIsOpen = true;
      _gateHoldUntilMs = timestampMs + gateHoldMs;
    }

    final bool gateOpen = _gateIsOpen;

    final double normalizedDb = ((db - minDb) / (maxDb - minDb)).clamp(
      0.0,
      1.0,
    );
    final double gain = 0.55 + sensitivity.clamp(0.0, 1.0) * 1.45;
    final double gatedLevel = gateOpen ? normalizedDb : 0.0;
    final double monoTarget = (pow(gatedLevel, 0.82).toDouble() * gain).clamp(
      0.0,
      1.0,
    );

    _monoSmoothed = _smoothValue(
      previous: _monoSmoothed,
      target: monoTarget,
      dtSec: dtSec,
      attackSec: 0.03,
      releaseSec: 0.22,
    ).clamp(0.0, 1.0);

    // Smoothed L/R levels.
    final double dbL = 20.0 * log(max(rmsL, 1e-6)) / ln10;
    final double dbR = 20.0 * log(max(rmsR, 1e-6)) / ln10;
    final double normL = ((dbL - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    final double normR = ((dbR - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    final double leftTarget = gateOpen
        ? (pow(normL, 0.82).toDouble() * gain).clamp(0.0, 1.0)
        : 0.0;
    final double rightTarget = gateOpen
        ? (pow(normR, 0.82).toDouble() * gain).clamp(0.0, 1.0)
        : 0.0;

    _leftSmoothed = _smoothValue(
      previous: _leftSmoothed,
      target: leftTarget,
      dtSec: dtSec,
      attackSec: 0.03,
      releaseSec: 0.22,
    ).clamp(0.0, 1.0);

    _rightSmoothed = _smoothValue(
      previous: _rightSmoothed,
      target: rightTarget,
      dtSec: dtSec,
      attackSec: 0.03,
      releaseSec: 0.22,
    ).clamp(0.0, 1.0);

    // FFT on mono-mixed signal.
    final List<double> spectrum = _computeSpectrum(
      input: input,
      sampleCount: count,
      sampleRate: sampleRate,
      channels: channels,
    );

    final List<double> normalizedSpectrum = _normalizeSpectrum(spectrum);

    // 7-band spectral energy (XToys-style Hz ranges)
    final double subBass = _bandEnergy(
      normalizedSpectrum,
      sampleRate,
      20.0,
      60.0,
    );
    final double bass = _bandEnergy(
      normalizedSpectrum,
      sampleRate,
      60.0,
      250.0,
    );
    final double lowMid = _bandEnergy(
      normalizedSpectrum,
      sampleRate,
      250.0,
      500.0,
    );
    final double midBand = _bandEnergy(
      normalizedSpectrum,
      sampleRate,
      500.0,
      2000.0,
    );
    final double upperMid = _bandEnergy(
      normalizedSpectrum,
      sampleRate,
      2000.0,
      4000.0,
    );
    final double presenceBand = _bandEnergy(
      normalizedSpectrum,
      sampleRate,
      4000.0,
      6000.0,
    );
    final double brilliance = _bandEnergy(
      normalizedSpectrum,
      sampleRate,
      6000.0,
      20000.0,
    );

    // Combined low-band for beat detection (matches old lowBand role)
    final double lowBand = (subBass + bass).clamp(0.0, 1.0);

    // Dominant bass frequency from raw (un-normalized) magnitudes
    final double dominantBassHz = _dominantFrequency(
      spectrum,
      sampleRate,
      bassMonitorLowHz,
      bassMonitorHighHz,
    );

    // Full-spectrum dominant frequency (80–8000 Hz) for fill center-Y mapping
    final double dominantFullHz = _dominantFrequency(
      spectrum,
      sampleRate,
      80.0,
      8000.0,
    );

    // Spectrum fill ratio: fraction of bins above dBFS threshold (gate chain input).
    final double spectrumFillRatio = _computeSpectrumFillRatio(
      spectrum,
      sampleRate,
    );

    _bassSmoothed = _smoothValue(
      previous: _bassSmoothed,
      target: lowBand,
      dtSec: dtSec,
      attackSec: 0.05,
      releaseSec: 0.28,
    ).clamp(0.0, 1.0);

    _bassBaseline = _smoothValue(
      previous: _bassBaseline,
      target: _bassSmoothed,
      dtSec: dtSec,
      attackSec: 1.2,
      releaseSec: 1.2,
    ).clamp(0.0, 1.0);

    final double bassDelta = (_bassSmoothed - _bassBaseline).clamp(0.0, 1.0);
    _bassDeltaBaseline = _smoothValue(
      previous: _bassDeltaBaseline,
      target: bassDelta,
      dtSec: dtSec,
      attackSec: 1.4,
      releaseSec: 1.4,
    ).clamp(0.0, 1.0);

    final double flux = _spectralFlux(normalizedSpectrum);
    _prevSpectrum = Float64List.fromList(normalizedSpectrum);

    _fluxSmoothed = _smoothValue(
      previous: _fluxSmoothed,
      target: flux,
      dtSec: dtSec,
      attackSec: 0.04,
      releaseSec: 0.24,
    ).clamp(0.0, 1.0);

    _fluxBaseline = _smoothValue(
      previous: _fluxBaseline,
      target: _fluxSmoothed,
      dtSec: dtSec,
      attackSec: 1.0,
      releaseSec: 1.0,
    ).clamp(0.0, 1.0);

    // ── Flux-drop tracker ──
    const double fluxDropAlpha = 0.15;
    _fluxDropEma += fluxDropAlpha * (flux - _fluxDropEma);
    _fluxDropPeak = max(_fluxDropEma, _fluxDropPeak * 0.998); // ~5 s half-life
    if (_fluxDropPeak > 1e-6 && _fluxDropEma < _fluxDropPeak * 0.40) {
      _fluxDropFrames += 1;
    } else {
      _fluxDropFrames = 0;
    }
    _fluxDropActive = _fluxDropFrames >= _fluxDropThresholdFrames;

    // ── Z-score multi-band peak detection ──
    final bool zSubBass = _zSubBass.update(subBass + bass);
    final bool zLowMid = _zLowMid.update(lowMid);
    final bool zMid = _zMid.update(midBand);
    final bool zHigh = _zHigh.update(upperMid + presenceBand + brilliance);
    final List<bool> zFires = <bool>[zSubBass, zLowMid, zMid, zHigh];

    // Track fire counts over a rolling window (~1 s).
    for (int b = 0; b < 4; b += 1) {
      _zBandFireHistory[b].add(zFires[b]);
      if (_zBandFireHistory[b].length > _zBandWindowSize) {
        if (_zBandFireHistory[b].removeAt(0)) {
          _zBandFireCounts[b] -= 1;
        }
      }
      if (zFires[b]) _zBandFireCounts[b] += 1;
    }

    // Primary band auto-selection (hysteresis: new needs 2+ more fires).
    int maxFires = _zBandFireCounts[_primaryBand];
    for (int b = 0; b < 4; b += 1) {
      if (b != _primaryBand && _zBandFireCounts[b] > maxFires + 2) {
        _primaryBand = b;
        maxFires = _zBandFireCounts[b];
      }
    }

    final bool primaryBandFired = zFires[_primaryBand];
    final bool anyBandFired = zSubBass || zLowMid || zMid || zHigh;
    final double totalEnergy =
        (subBass +
        bass +
        lowMid +
        midBand +
        upperMid +
        presenceBand +
        brilliance);
    final bool zScoreBeatFired =
        gateOpen && (primaryBandFired || anyBandFired) && totalEnergy > 0.01;

    final double onsetThreshold = (_fluxBaseline * 1.35) + 0.015;
    final bool onsetDetected =
        _fluxSmoothed > onsetThreshold && (timestampMs - _lastOnsetMs) >= 160;

    if (onsetDetected) {
      _lastOnsetMs = timestampMs;
      _onsetPulse = 1.0;
    }

    final double pulseDecay = exp(-dtSec / 0.12);
    _onsetPulse = max(0.0, _onsetPulse * pulseDecay);

    // ── Adaptive refractory ──
    // Default 220 ms, but shorten to 70% of beat period if BPM is known.
    // Prefer metronome BPM (ACF) over IBI BPM from connection provider.
    final double refractoryBpm = _metronomeBpm > 0.0
        ? _metronomeBpm
        : estimatedBpm;
    double beatRefractoryMs = 220.0;
    if (refractoryBpm > 0.0) {
      final double beatPeriodMs = 60000.0 / refractoryBpm;
      beatRefractoryMs = min(beatRefractoryMs, beatPeriodMs * 0.70);
    }
    beatRefractoryMs = beatRefractoryMs.clamp(80.0, 600.0);

    final double beatThreshold = (_bassDeltaBaseline * 1.55) + 0.018;
    final bool bassBeatDetected =
        bassDelta > beatThreshold &&
        (timestampMs - _lastBeatMs) >= beatRefractoryMs;

    // Combined beat: classic bass-delta OR z-score primary band fire,
    // gated by gate + flux-drop suppression.
    final bool beatDetected =
        gateOpen &&
        !_fluxDropActive &&
        (bassBeatDetected ||
            (zScoreBeatFired &&
                (timestampMs - _lastBeatMs) >= beatRefractoryMs) ||
            (onsetDetected && lowBand > ((presenceBand + brilliance) * 0.70)));

    if (beatDetected) {
      _lastBeatMs = timestampMs;
      _beatPulse = 1.0;
    }

    final double beatDecay = exp(-dtSec / 0.24);
    _beatPulse = max(0.0, _beatPulse * beatDecay);

    // ── ACF tempo estimation + metronome PLL ──
    if (gateOpen) {
      _feedOnsetBuffer(flux, timestampMs.toDouble());
    }

    // Run ACF periodically (~4 Hz).
    double targetBpm = 0.0;
    if (timestampMs - _lastAcfRunMs >= _acfIntervalMs && !_fluxDropActive) {
      _lastAcfRunMs = timestampMs.toDouble();
      final (double rawBpm, double conf) = _estimateTempoAcf();
      if (rawBpm > 0.0) {
        _acfBpmSmoothed = _smoothAcfBpm(rawBpm, conf);
        _acfConfidence = conf;
      }
    }

    // Use ACF BPM only. Keep metronome lock confidence tied to ACF quality,
    // not to the provider's IBI fallback estimate.
    if (_acfBpmSmoothed > 0.0) {
      targetBpm = _acfBpmSmoothed;
    }

    // Advance metronome (handles coasting).
    final (bool mBeatTick, bool mIsDownbeat) = _advanceMetronome(
      dtSec,
      targetBpm,
      lowBand,
      timestampMs.toDouble(),
    );

    // Nudge metronome phase on accepted onsets (dedup'd).
    if (onsetDetected && _metronomeBpm > 0.0) {
      final double bpmRef = _metronomeBpm;
      final double dedupWindow = bpmRef > 0.0
          ? 0.22 * (60000.0 / bpmRef)
          : 100.0;
      if (timestampMs - _lastAcceptedOnsetMs >= dedupWindow) {
        _lastAcceptedOnsetMs = timestampMs.toDouble();
        _nudgeMetronomePhase(min(1.0, _fluxSmoothed * 3.0));
      }
    }

    // Syncopation detection.
    final bool anyFired = zSubBass || zLowMid || zMid || zHigh;
    _updateTransientDensity(anyFired, timestampMs.toDouble());
    _detectSyncopation(anyFired);

    // Energy fullness composite (absolute levels, no P5/P95 normalization).
    final double rmsRelative = rms.clamp(0.0, 1.0);
    final double rawFullness = pow(
      (0.45 * rmsRelative +
          0.25 * subBass.clamp(0.0, 1.0) +
          0.15 * lowMid.clamp(0.0, 1.0) +
          0.15 * midBand.clamp(0.0, 1.0)),
      0.6,
    ).toDouble().clamp(0.0, 1.0);
    _energyFullnessEma += (rawFullness - _energyFullnessEma) * 0.08;

    final double bandScale = gateOpen ? _monoSmoothed : 0.0;

    return AudioFeatures(
      mono: _monoSmoothed,
      left: _leftSmoothed,
      right: _rightSmoothed,
      subBass: (subBass * bandScale).clamp(0.0, 1.0),
      bass: (bass * bandScale).clamp(0.0, 1.0),
      lowMid: (lowMid * bandScale).clamp(0.0, 1.0),
      mid: (midBand * bandScale).clamp(0.0, 1.0),
      upperMid: (upperMid * bandScale).clamp(0.0, 1.0),
      presence: (presenceBand * bandScale).clamp(0.0, 1.0),
      brilliance: (brilliance * bandScale).clamp(0.0, 1.0),
      dominantBassHz: gateOpen ? dominantBassHz : 0.0,
      dominantFullHz: gateOpen ? dominantFullHz : 0.0,
      flux: _fluxSmoothed,
      onset: _onsetPulse,
      beat: _beatPulse,
      zScoreBeat: zScoreBeatFired,
      zScoreMid: zMid,
      zScoreHigh: zHigh,
      fluxDropActive: _fluxDropActive,
      spectrumFillRatio: spectrumFillRatio,
      metronomeBpm: _metronomeBpm,
      metronomeConfidence: _acfConfidence.clamp(0.0, 1.0),
      metronomePhase: _metronomePhase % 1.0,
      metronomeBeatTick: mBeatTick,
      isDownbeat: mIsDownbeat,
      isSyncopated: _isSyncopated,
      rms: rms,
      db: db,
      gateOpen: gateOpen,
      energyFullness: _energyFullnessEma.clamp(0.0, 1.0),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ACF Tempo Estimation
  // ════════════════════════════════════════════════════════════════════════

  /// Feed a flux value into the onset buffer and calibrate FPS.
  void _feedOnsetBuffer(double flux, double timestampMs) {
    _onsetBuffer.add(flux);
    if (_onsetBuffer.length > _onsetBufferMax) {
      _onsetBuffer.removeAt(0);
    }
    _callbackTimestamps.add(timestampMs);
    if (_callbackTimestamps.length > _fpsCalibrationWindow) {
      _callbackTimestamps.removeAt(0);
    }
    if (_callbackTimestamps.length >= 60) {
      final double elapsed =
          (_callbackTimestamps.last - _callbackTimestamps.first) / 1000.0;
      if (elapsed > 0.01) {
        _fps = (_callbackTimestamps.length - 1) / elapsed;
      }
    }
  }

  /// Compute autocorrelation-based tempo estimate.
  /// Returns (bpm, confidence) or (0, 0) if insufficient data.
  (double bpm, double confidence) _estimateTempoAcf() {
    final int n = _onsetBuffer.length;
    if (n < 80) return (0.0, 0.0);

    // Zero-mean the buffer.
    double mean = 0.0;
    for (int i = 0; i < n; i++) {
      mean += _onsetBuffer[i];
    }
    mean /= n;

    final int nfft = _nextPowerOf2(2 * n);
    final Float64List signal = Float64List(nfft);
    for (int i = 0; i < n; i++) {
      signal[i] = _onsetBuffer[i] - mean;
    }

    // ACF via Wiener-Khinchin: IFFT(|FFT(x)|²)
    final FFT acfFft = FFT(nfft);
    final Float64x2List freqDomain = acfFft.realFft(signal);

    // Multiply each complex bin by its conjugate (power spectrum).
    for (int i = 0; i < freqDomain.length; i++) {
      final double re = freqDomain[i].x;
      final double im = freqDomain[i].y;
      freqDomain[i] = Float64x2(re * re + im * im, 0.0);
    }

    final Float64List acf = acfFft.realInverseFft(freqDomain);

    // Normalize so lag-0 = 1.0.
    if (acf[0] <= 0.0) return (0.0, 0.0);
    final double norm = acf[0];
    for (int i = 0; i < n; i++) {
      acf[i] /= norm;
    }

    // Search range: BPM 55–200.
    final int minLag = max(1, (_fps * 60.0 / 200.0).floor());
    final int maxLag = min(n - 1, (_fps * 60.0 / 55.0).floor());
    if (minLag >= maxLag) return (0.0, 0.0);

    // Find peak in search range.
    int peakIdx = 0;
    double peakVal = -1.0;
    for (int i = minLag; i <= maxLag; i++) {
      if (acf[i] > peakVal) {
        peakVal = acf[i];
        peakIdx = i;
      }
    }

    if (peakVal < _acfMinConfidence) {
      _acfConfidence = max(0.05, _acfConfidence * 0.9);
      return (0.0, _acfConfidence);
    }

    // Parabolic interpolation for sub-sample resolution.
    double refinedLag = peakIdx.toDouble();
    if (peakIdx > minLag && peakIdx < maxLag) {
      final double a = acf[peakIdx - 1];
      final double b = acf[peakIdx];
      final double c = acf[peakIdx + 1];
      final double denom = a - 2.0 * b + c;
      if (denom.abs() > 1e-10) {
        refinedLag += 0.5 * (a - c) / denom;
      }
    }

    double bpm = 60.0 * _fps / refinedLag;
    if (bpm < 55.0 || bpm > 185.0) return (0.0, _acfConfidence);

    // ── Octave disambiguation ──
    // Check half-lag (double tempo) and double-lag (half tempo).
    final int halfLag = peakIdx ~/ 2;
    final int doubleLag = peakIdx * 2;

    double bestBpm = bpm;
    double bestConf = peakVal;

    if (halfLag >= minLag && halfLag < n) {
      final double halfVal = acf[halfLag];
      final double halfBpm = 60.0 * _fps / halfLag;
      if (halfVal > peakVal * 0.60 && halfBpm >= 55.0 && halfBpm <= 200.0) {
        // Prefer half-lag (faster tempo) if it's strong enough.
        if (halfVal > peakVal * 0.75) {
          bestBpm = halfBpm;
          bestConf = halfVal;
        }
      }
    }

    if (doubleLag <= maxLag && doubleLag < n) {
      final double doubleVal = acf[doubleLag];
      final double doubleBpm = 60.0 * _fps / doubleLag;
      if (doubleVal > peakVal * 0.60 &&
          doubleBpm >= 55.0 &&
          doubleBpm <= 200.0) {
        // Only prefer double-lag if we have a target and it's closer.
        if (_acfBpmSmoothed > 0.0) {
          final double distCurrent = (bestBpm - _acfBpmSmoothed).abs();
          final double distDouble = (doubleBpm - _acfBpmSmoothed).abs();
          if (distDouble < distCurrent && _acfConfidence < 0.35) {
            bestBpm = doubleBpm;
            bestConf = doubleVal;
          }
        }
      }
    }

    return (bestBpm, bestConf);
  }

  /// Smooth ACF BPM with jump gating.
  double _smoothAcfBpm(double candidate, double conf) {
    if (_acfBpmSmoothed <= 0.0) return candidate;
    final double ratio = (candidate - _acfBpmSmoothed).abs() / _acfBpmSmoothed;
    if (ratio < 0.15) {
      // Small change — smooth.
      return 0.85 * _acfBpmSmoothed + 0.15 * candidate;
    } else if (conf > 0.25) {
      // Large change with high confidence — accept.
      return candidate;
    } else {
      // Large change with low confidence — reject.
      return _acfBpmSmoothed;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  Metronome PLL
  // ════════════════════════════════════════════════════════════════════════

  /// Advance the metronome and return (beatTick, isDownbeat).
  (bool beatTick, bool isDownbeat) _advanceMetronome(
    double dtSec,
    double targetBpm,
    double bandEnergy,
    double timestampMs,
  ) {
    bool beatTick = false;
    bool isDownbeat = false;

    // ── Confidence hold / coasting ──
    if (targetBpm <= 0.0 && _metronomeBpm > 0.0) {
      if (!_metronomeCoasting) {
        _metronomeCoasting = true;
        _metronomeConfHoldStart = timestampMs;
      }
      final double elapsed = (timestampMs - _metronomeConfHoldStart) / 1000.0;
      if (elapsed < 1.5) {
        final double decay = max(0.0, 1.0 - elapsed * 0.10);
        targetBpm = _metronomeBpm * decay;
      } else {
        _metronomeBpm = 0.0;
        _metronomeCoasting = false;
        return (false, false);
      }
    } else if (targetBpm > 0.0) {
      _metronomeCoasting = false;
    }

    if (targetBpm <= 0.0) return (false, false);

    // ── BPM tracking (EMA) ──
    if (_metronomeBpm <= 0.0) {
      _metronomeBpm = targetBpm;
    } else {
      final double smoothConf = _acfConfidence > 0 ? _acfConfidence : 0.20;
      final double alpha = 0.08 + (0.40 - 0.08) * smoothConf.clamp(0.0, 1.0);
      _metronomeBpm = (1.0 - alpha) * _metronomeBpm + alpha * targetBpm;
    }

    // ── Phase accumulation ──
    if (dtSec <= 0.0 || dtSec > 0.5) return (false, false);
    final double phaseStep = (_metronomeBpm / 60.0) * dtSec;
    final double oldPhase = _metronomePhase;
    _metronomePhase += phaseStep;

    // Check for integer crossings (beat ticks).
    final int crossings = max(0, _metronomePhase.floor() - oldPhase.floor());
    if (crossings > 0) {
      beatTick = true;
      _metronomePhase = _metronomePhase % 1.0;

      // ── Downbeat tracking ──
      for (int c = 0; c < crossings; c++) {
        // Decay all positions.
        for (int i = 0; i < _beatsPerMeasure; i++) {
          _measureEnergyAccum[i] *= 0.85;
        }
        // Accumulate energy at current position.
        _measureEnergyAccum[_beatPositionInMeasure] += bandEnergy;
        _measureBeatCounts[_beatPositionInMeasure] += 1;
        _totalMeasureBeats += 1;

        // Check if this is the downbeat.
        if (_totalMeasureBeats >= _beatsPerMeasure * 2) {
          _updateDownbeatPosition();
        }
        if (_beatPositionInMeasure == _downbeatPosition &&
            _totalMeasureBeats >= _beatsPerMeasure * 2) {
          isDownbeat = true;
        }

        // Syncopation: on metric tick, update streak.
        if (_hadOffbeat) {
          _syncoStreak += 1;
        } else {
          _syncoStreak = 0;
          _syncoArmed = false;
        }
        _hadOffbeat = false;

        _beatPositionInMeasure =
            (_beatPositionInMeasure + 1) % _beatsPerMeasure;
      }
    }

    return (beatTick, isDownbeat);
  }

  void _updateDownbeatPosition() {
    double maxAvg = 0.0;
    for (int i = 0; i < _beatsPerMeasure; i++) {
      final double avg = _measureBeatCounts[i] > 0
          ? _measureEnergyAccum[i] / _measureBeatCounts[i]
          : 0.0;
      if (avg > maxAvg) {
        maxAvg = avg;
        _downbeatPosition = i;
      }
    }
  }

  /// Nudge metronome phase when an onset is detected.
  void _nudgeMetronomePhase(double onsetStrength) {
    if (_metronomeBpm <= 0.0) return;

    final double phaseFrac = _metronomePhase % 1.0;
    final double error = phaseFrac < 0.5 ? -phaseFrac : 1.0 - phaseFrac;

    if (error.abs() >= _metronomePllWindow) return;

    final double gain = 0.25 + 0.18 * _acfConfidence;
    final double errorScale = 0.65 + 0.35 * min(1.0, error.abs() / 0.20);
    double correction = error * gain * min(1.0, onsetStrength) * errorScale;
    correction = correction.clamp(-0.22, 0.22);
    _metronomePhase += correction;
  }

  /// Track transient density: z-score fire rate over a ~1 s sliding window.
  void _updateTransientDensity(bool anyZScoreFired, double timestampMs) {
    if (anyZScoreFired) {
      _transientFireCount += 1;
    }
    final double elapsed = timestampMs - _transientWindowStartMs;
    if (elapsed >= 1000.0) {
      _transientDensity = _transientFireCount / (elapsed / 1000.0);
      _transientFireCount = 0;
      _transientWindowStartMs = timestampMs;
    }
  }

  /// Detect syncopation: onset near phase 0.5 (the "and").
  /// Window is texture-scaled: shrinks when transient density is high
  /// (busy passages) and expands when sparse.
  bool _detectSyncopation(bool anyZScoreFired) {
    if (_metronomeBpm <= 0.0) return false;
    final double phaseFrac = _metronomePhase % 1.0;

    // Texture scaling: density < 4/s → factor 1.0; > 12/s → factor 0.5.
    final double textureFactor =
        (1.0 - ((_transientDensity - 4.0) / 8.0).clamp(0.0, 1.0) * 0.5).clamp(
          0.5,
          1.0,
        );
    final double window = 0.18 * textureFactor;

    if ((phaseFrac - 0.5).abs() < window && anyZScoreFired) {
      _hadOffbeat = true;
      if (_syncoStreak >= 1) {
        _isSyncopated = true;
        return true;
      } else if (_syncoArmed) {
        _syncoStreak = 1;
        _isSyncopated = true;
        return true;
      } else {
        _syncoArmed = true;
      }
    }

    // Predictive drop-off: past the window with no offbeat.
    if (phaseFrac > 0.5 + window && !_hadOffbeat) {
      _syncoStreak = 0;
      _syncoArmed = false;
    }

    _isSyncopated = false;
    return false;
  }

  static int _nextPowerOf2(int n) {
    int p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }

  List<double> _computeSpectrum({
    required ByteData input,
    required int sampleCount,
    required int sampleRate,
    int channels = 1,
  }) {
    final bool isStereo = channels >= 2;
    final int stride = isStereo ? 2 : 1;
    final int usable = min(sampleCount, _fftSize);
    final int start = sampleCount - usable;

    for (int i = 0; i < _fftSize; i += 1) {
      _timeDomain[i] = 0.0;
    }

    int outIndex = _fftSize - usable;
    for (int i = start; i < sampleCount; i += 1) {
      final int baseIdx = i * stride;
      final int sampleL = input.getInt16(baseIdx * 2, Endian.little);
      double value;
      if (isStereo) {
        final int sampleR = input.getInt16((baseIdx + 1) * 2, Endian.little);
        value = ((sampleL + sampleR) / 2.0) / 32768.0;
      } else {
        value = sampleL / 32768.0;
      }
      _timeDomain[outIndex] = value * _window[outIndex];
      outIndex += 1;
    }

    final Float64x2List spectrum = _fft.realFft(_timeDomain);
    final Float64List mags = spectrum.discardConjugates().magnitudes();

    final double scale = 2.0 / _fftSize;
    for (int i = 0; i < _monoBins.length; i += 1) {
      _monoBins[i] = mags[i] * scale;
    }

    return _monoBins;
  }

  List<double> _normalizeSpectrum(List<double> spectrum) {
    double total = 0.0;
    for (int i = 1; i < spectrum.length; i += 1) {
      total += spectrum[i];
    }

    if (total <= 1e-9) {
      return List<double>.filled(spectrum.length, 0.0);
    }

    final List<double> normalized = List<double>.filled(spectrum.length, 0.0);
    for (int i = 1; i < spectrum.length; i += 1) {
      normalized[i] = (spectrum[i] / total).clamp(0.0, 1.0);
    }
    return normalized;
  }

  double _bandEnergy(
    List<double> spectrum,
    int sampleRate,
    double lowHz,
    double highHz,
  ) {
    if (spectrum.isEmpty || sampleRate <= 0) {
      return 0.0;
    }

    final double binHz = sampleRate / _fftSize;
    int start = (lowHz / binHz).floor();
    int end = (highHz / binHz).ceil();

    start = start.clamp(1, spectrum.length - 1);
    end = end.clamp(1, spectrum.length - 1);

    if (end < start) {
      return 0.0;
    }

    double sum = 0.0;
    for (int i = start; i <= end; i += 1) {
      sum += spectrum[i];
    }

    // Use summed normalized energy so bands represent spectral share, not bin count.
    return sum.clamp(0.0, 1.0);
  }

  /// Returns the frequency (Hz) of the strongest bin in [lowHz..highHz]
  /// using raw (un-normalized) magnitudes. Returns 0.0 if no energy.
  double _dominantFrequency(
    List<double> spectrum,
    int sampleRate,
    double lowHz,
    double highHz,
  ) {
    if (spectrum.isEmpty || sampleRate <= 0) {
      return 0.0;
    }

    final double binHz = sampleRate / _fftSize;
    int start = (lowHz / binHz).floor().clamp(1, spectrum.length - 1);
    int end = (highHz / binHz).ceil().clamp(1, spectrum.length - 1);

    if (end < start) {
      return 0.0;
    }

    double maxMag = 0.0;
    int maxBin = start;
    for (int i = start; i <= end; i += 1) {
      if (spectrum[i] > maxMag) {
        maxMag = spectrum[i];
        maxBin = i;
      }
    }

    if (maxMag <= 1e-9) {
      return 0.0;
    }

    // Parabolic interpolation for sub-bin accuracy.
    if (maxBin > start && maxBin < end) {
      final double a = spectrum[maxBin - 1];
      final double b = spectrum[maxBin];
      final double c = spectrum[maxBin + 1];
      final double denom = a - 2.0 * b + c;
      if (denom.abs() > 1e-12) {
        final double delta = 0.5 * (a - c) / denom;
        return (maxBin + delta) * binHz;
      }
    }

    return maxBin * binHz;
  }

  /// Spectrum fill ratio: fraction of FFT bins (60–6000 Hz) above a dBFS
  /// threshold relative to a decaying peak reference.  Ported from desktop
  /// bREadbeats `_get_spectrum_fill_ratio()`.
  double _computeSpectrumFillRatio(List<double> spectrum, int sampleRate) {
    if (spectrum.isEmpty || sampleRate <= 0) return 0.0;

    final double binHz = sampleRate / _fftSize;
    final int loIdx = (60.0 / binHz).floor().clamp(1, spectrum.length - 1);
    final int hiIdx = (6000.0 / binHz).ceil().clamp(1, spectrum.length - 1);
    if (hiIdx <= loIdx) return 0.0;

    // Find peak magnitude in range for dBFS reference tracking.
    double peakMag = 0.0;
    for (int i = loIdx; i <= hiIdx; i++) {
      if (spectrum[i] > peakMag) peakMag = spectrum[i];
    }
    // Track decaying peak reference (~5 s half-life).
    _dbfsRefMax = max(peakMag, _dbfsRefMax * 0.998);
    if (_dbfsRefMax < 1e-9) return 0.0;

    // dBFS threshold: -30 dB below the reference peak.
    final double thresholdMag = _dbfsRefMax * 0.0316; // 10^(-30/20)

    int aboveCount = 0;
    final int totalBins = hiIdx - loIdx + 1;
    for (int i = loIdx; i <= hiIdx; i++) {
      if (spectrum[i] > thresholdMag) aboveCount++;
    }
    return aboveCount / totalBins;
  }

  /// SuperFlux spectral flux (Böck & Widmer, DAFx-2013).
  /// Applies a 3-wide max filter on the previous spectrum before diffing,
  /// suppressing vibrato/tremolo false positives by ~60%.
  double _spectralFlux(List<double> current) {
    final Float64List? previous = _prevSpectrum;
    if (previous == null || previous.length != current.length) {
      return 0.0;
    }

    final int len = current.length;
    double flux = 0.0;
    for (int i = 1; i < len; i += 1) {
      // max-filter: max(prev[i-1], prev[i], prev[i+1])
      double prevMax = previous[i];
      if (i > 1 && previous[i - 1] > prevMax) prevMax = previous[i - 1];
      if (i < len - 1 && previous[i + 1] > prevMax) prevMax = previous[i + 1];
      final double delta = current[i] - prevMax;
      if (delta > 0) {
        flux += delta;
      }
    }

    return (flux * 8.0).clamp(0.0, 1.0);
  }

  double _smoothValue({
    required double previous,
    required double target,
    required double dtSec,
    required double attackSec,
    required double releaseSec,
  }) {
    if (dtSec <= 0.0) {
      return target;
    }

    final double tau = target > previous ? attackSec : releaseSec;
    if (tau <= 0.0) {
      return target;
    }

    final double alpha = 1.0 - exp(-dtSec / tau);
    return previous + alpha * (target - previous);
  }

  static Float64List _buildHannWindow(int size) {
    final Float64List window = Float64List(size);
    if (size <= 1) {
      if (size == 1) {
        window[0] = 1.0;
      }
      return window;
    }

    for (int i = 0; i < size; i += 1) {
      window[i] = 0.5 * (1.0 - cos((2.0 * pi * i) / (size - 1)));
    }
    return window;
  }
}
