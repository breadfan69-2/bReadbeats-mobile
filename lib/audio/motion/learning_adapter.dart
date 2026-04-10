import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/ring_buffer.dart';
import '../processing/audio_signal_processor.dart';

class LearningAdapter {
  static const int _historyLength = 600;
  static const int _minObservationsBeforeActive = 10;
  static const double _emaAlpha = 0.15;

  final RingBuffer _rmsHistory = RingBuffer(_historyLength);
  final RingBuffer _fluxHistory = RingBuffer(_historyLength);
  final RingBuffer _bassHistory = RingBuffer(_historyLength);

  List<String> _featureColumns = const <String>[];
  Map<String, double> _normMean = const <String, double>{};
  Map<String, double> _normStd = const <String, double>{};
  double _intercept = 0.5;
  Map<String, double> _coefficients = const <String, double>{};
  double _quietThreshold = 0.15;
  double _midThreshold = 0.45;
  bool _loaded = false;

  double learnedSpeedMult = 0.5;
  int cadenceHint = 2;
  int observationCount = 0;

  double learningStrength = 0.55;

  bool get isLoaded => _loaded;
  bool get isActive =>
      _loaded && observationCount >= _minObservationsBeforeActive;

  @visibleForTesting
  int get historyCount => _rmsHistory.count;

  Future<void> loadFromAsset(String assetPath) async {
    try {
      final String jsonStr = await rootBundle.loadString(assetPath);
      final Object decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        _loaded = false;
        return;
      }
      loadFromJsonMap(decoded);
    } catch (error, stackTrace) {
      debugPrint(
        '[LearningAdapter] Failed to load model asset "$assetPath": '
        '$error\n$stackTrace',
      );
      _loaded = false;
    }
  }

  @visibleForTesting
  void loadFromJsonMap(Map<String, dynamic> json) {
    try {
      if (json['status'] != 'ok') {
        _loaded = false;
        return;
      }

      final List<dynamic> featureColumnsRaw =
          json['feature_columns'] as List<dynamic>? ?? const <dynamic>[];
      _featureColumns = featureColumnsRaw
          .map((dynamic value) {
            return value.toString();
          })
          .toList(growable: false);

      final Map<String, dynamic> normalization =
          (json['normalization'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      _normMean = _toDoubleMap(normalization['mean']);
      _normStd = _toDoubleMap(normalization['std']);

      final Map<String, dynamic> models =
          (json['models'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final Map<String, dynamic> speedMultModel =
          (models['speed_mult'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      _intercept = (speedMultModel['intercept'] as num?)?.toDouble() ?? 0.5;
      _coefficients = _toDoubleMap(speedMultModel['coefficients']);

      final Map<String, dynamic> cadenceRule =
          (json['cadence_rule'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      _quietThreshold =
          (cadenceRule['quiet_threshold'] as num?)?.toDouble() ?? 0.15;
      _midThreshold =
          (cadenceRule['mid_threshold'] as num?)?.toDouble() ?? 0.45;

      _loaded = true;
    } catch (error, stackTrace) {
      debugPrint(
        '[LearningAdapter] Failed to parse learning model payload: '
        '$error\n$stackTrace',
      );
      _loaded = false;
    }
  }

  void pushFrame(AudioFeatures features) {
    _rmsHistory.add(features.rms);
    _fluxHistory.add(features.flux);
    _bassHistory.add(features.subBass);
  }

  void updateOnBeat(AudioFeatures features) {
    if (!_loaded) {
      return;
    }

    observationCount += 1;
    if (observationCount < _minObservationsBeforeActive) {
      return;
    }

    final Map<String, double> featureValues = _buildFeatureVector(features);
    final double rawPrediction = _predict(featureValues);

    final double strength = learningStrength.clamp(0.0, 1.0);
    final double blended = 0.5 + (rawPrediction - 0.5) * strength;

    learnedSpeedMult =
        learnedSpeedMult * (1.0 - _emaAlpha) + blended * _emaAlpha;

    if (learnedSpeedMult < _quietThreshold) {
      cadenceHint = 4;
    } else if (learnedSpeedMult < _midThreshold) {
      cadenceHint = 2;
    } else {
      cadenceHint = 1;
    }
  }

  void reset() {
    learnedSpeedMult = 0.5;
    cadenceHint = 2;
    observationCount = 0;
  }

  void fullReset() {
    reset();
    _rmsHistory.clear();
    _fluxHistory.clear();
    _bassHistory.clear();
  }

  Map<String, double> _buildFeatureVector(AudioFeatures features) {
    final double highEnergy = features.presence + features.brilliance;
    return <String, double>{
      'rms': features.rms,
      'spectral_flux': features.flux,
      'sub_bass_energy': features.subBass,
      'low_mid_energy': features.lowMid,
      'mid_energy': features.mid,
      'high_energy': highEnergy,
      'low_high_ratio': features.bassLowHighRatio,
      'spectral_centroid_hz':
          (80.0 +
                  3000.0 *
                      (highEnergy /
                          (features.subBass + features.lowMid + 1e-10)))
              .clamp(80.0, 8000.0),
      'spectral_flatness': (0.35 + 0.50 * (1.0 - features.energyFullness))
          .clamp(0.0, 1.0),
      'rms_mean_10s': _rmsHistory.mean(),
      'rms_std_10s': _rmsHistory.std(),
      'flux_mean_10s': _fluxHistory.mean(),
      'bass_mean_10s': _bassHistory.mean(),
      'energy_trend_10s': _rmsHistory.linearSlope(),
    };
  }

  double _predict(Map<String, double> featureValues) {
    double sum = _intercept;
    for (final String column in _featureColumns) {
      final double raw = featureValues[column] ?? 0.0;
      final double mean = _normMean[column] ?? 0.0;
      final double std = _normStd[column] ?? 1.0;
      final double zScore = std > 1e-12 ? (raw - mean) / std : 0.0;
      sum += zScore * (_coefficients[column] ?? 0.0);
    }
    return sum.clamp(0.0, 1.0);
  }

  Map<String, double> _toDoubleMap(Object? source) {
    if (source is! Map) {
      return const <String, double>{};
    }

    final Map<String, double> result = <String, double>{};
    source.forEach((Object? key, Object? value) {
      if (key is String && value is num) {
        result[key] = value.toDouble();
      }
    });
    return result;
  }
}
