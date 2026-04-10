import 'dart:typed_data';

import '../processing/audio_signal_processor.dart';
import 'capture_controller.dart';

class AudioCaptureManager {
  final AudioSignalProcessor _signalProcessor = AudioSignalProcessor();

  int _lastPcmTimestampMs = 0;
  int _lastPcmNotifyMs = 0;
  AudioFeatures _lastAudioFeatures = AudioFeatures.zero;

  int _pcmFrameCount = 0;
  int _pcmSampleRate = 0;
  int _pcmChannels = 1;

  double _liveAudioLevel = 0.0;
  double _liveLowBand = 0.0;
  double _liveMidBand = 0.0;
  double _liveHighBand = 0.0;
  double _liveDominantBassHz = 0.0;
  double _liveFlux = 0.0;
  double _liveOnset = 0.0;
  double _liveBeat = 0.0;
  double _liveDb = -120.0;
  bool _liveGateOpen = false;

  int get lastPcmTimestampMs => _lastPcmTimestampMs;
  AudioFeatures get lastAudioFeatures => _lastAudioFeatures;

  int get pcmFrameCount => _pcmFrameCount;
  int get pcmSampleRate => _pcmSampleRate;
  int get pcmChannels => _pcmChannels;

  double get liveAudioLevel => _liveAudioLevel;
  double get liveLowBand => _liveLowBand;
  double get liveMidBand => _liveMidBand;
  double get liveHighBand => _liveHighBand;
  double get liveDominantBassHz => _liveDominantBassHz;
  double get liveFlux => _liveFlux;
  double get liveOnset => _liveOnset;
  double get liveBeat => _liveBeat;
  double get liveDb => _liveDb;
  bool get liveGateOpen => _liveGateOpen;

  void markCaptureStarted({
    required int nowMs,
    int? sampleRate,
    int? channels,
  }) {
    _lastPcmTimestampMs = nowMs;
    if (sampleRate != null && sampleRate > 0) {
      _pcmSampleRate = sampleRate;
    }
    if (channels != null && channels > 0) {
      _pcmChannels = channels;
    }
  }

  bool handlePcm16Event({
    required Pcm16CaptureEvent event,
    required double sensitivity,
    required double bassMonitorLowHz,
    required double bassMonitorHighHz,
    required double estimatedBpm,
  }) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    _lastPcmTimestampMs = nowMs;
    _pcmFrameCount += 1;

    final int sampleRate = event.sampleRate;
    if (sampleRate > 0) {
      _pcmSampleRate = sampleRate;
    }

    final int safeSampleRate = sampleRate > 0
        ? sampleRate
        : (_pcmSampleRate > 0 ? _pcmSampleRate : 48_000);
    final int frameSamples = event.frameSamples;
    final int channels = event.channels > 0 ? event.channels : _pcmChannels;
    final Uint8List? rawData = event.data;

    if (rawData is Uint8List) {
      final AudioFeatures features = _signalProcessor.processPcm16(
        bytes: rawData,
        frameSamples: frameSamples,
        sampleRate: safeSampleRate,
        sensitivity: sensitivity,
        timestampMs: nowMs,
        channels: channels,
        bassMonitorLowHz: bassMonitorLowHz,
        bassMonitorHighHz: bassMonitorHighHz,
        estimatedBpm: estimatedBpm,
      );
      _applyLiveFeatures(features);
    } else {
      _applyLiveFeatures(_fallbackFeatures(event.rms));
    }

    if ((nowMs - _lastPcmNotifyMs) >= 80) {
      _lastPcmNotifyMs = nowMs;
      return true;
    }
    return false;
  }

  void resetLiveState() {
    _pcmFrameCount = 0;
    _pcmSampleRate = 0;
    _pcmChannels = 1;
    _lastPcmNotifyMs = 0;
    _lastAudioFeatures = AudioFeatures.zero;
    _liveAudioLevel = 0.0;
    _liveLowBand = 0.0;
    _liveMidBand = 0.0;
    _liveHighBand = 0.0;
    _liveDominantBassHz = 0.0;
    _liveFlux = 0.0;
    _liveOnset = 0.0;
    _liveBeat = 0.0;
    _liveDb = -120.0;
    _liveGateOpen = false;
  }

  void _applyLiveFeatures(AudioFeatures features) {
    _lastAudioFeatures = features;
    _liveAudioLevel = features.mono;
    _liveLowBand = features.lowBand;
    _liveMidBand = features.midBand;
    _liveHighBand = features.highBand;
    _liveDominantBassHz = features.dominantBassHz;
    _liveFlux = features.flux;
    _liveOnset = features.onset;
    _liveBeat = features.beat;
    _liveDb = features.db;
    _liveGateOpen = features.gateOpen;
  }

  static AudioFeatures _fallbackFeatures(double? rms) {
    final double fallbackRms = (rms ?? 0.0).clamp(0.0, 1.0);
    return AudioFeatures(
      mono: fallbackRms,
      left: fallbackRms,
      right: fallbackRms,
      subBass: fallbackRms * 0.3,
      bass: fallbackRms * 0.3,
      lowMid: fallbackRms * 0.15,
      mid: fallbackRms * 0.1,
      upperMid: fallbackRms * 0.05,
      presence: fallbackRms * 0.05,
      brilliance: fallbackRms * 0.05,
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
      rms: fallbackRms,
      db: -120.0,
      gateOpen: fallbackRms > 0.015,
      energyFullness: 0.0,
    );
  }
}
