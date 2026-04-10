import 'package:breadbeats_mobile/audio/motion/learning_adapter.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LearningAdapter loadFromJsonMap parses model payload', () {
    final LearningAdapter adapter = LearningAdapter();

    adapter.loadFromJsonMap(
      _model(
        intercept: 0.5,
        featureColumns: const <String>['rms'],
        means: const <String, double>{'rms': 0.0},
        stds: const <String, double>{'rms': 1.0},
        coefficients: const <String, double>{'rms': 0.25},
      ),
    );

    expect(adapter.isLoaded, isTrue);
    expect(adapter.isActive, isFalse);
  });

  test('LearningAdapter pushFrame updates rolling history count', () {
    final LearningAdapter adapter = LearningAdapter();

    adapter.pushFrame(AudioFeatures.zero);
    adapter.pushFrame(AudioFeatures.zero);

    expect(adapter.historyCount, 2);
  });

  test('LearningAdapter updateOnBeat is no-op when model is not loaded', () {
    final LearningAdapter adapter = LearningAdapter();

    for (int i = 0; i < 20; i += 1) {
      adapter.updateOnBeat(AudioFeatures.zero);
    }

    expect(adapter.observationCount, 0);
    expect(adapter.learnedSpeedMult, closeTo(0.5, 1e-12));
    expect(adapter.cadenceHint, 2);
  });

  test('LearningAdapter waits for minimum observations before activation', () {
    final LearningAdapter adapter = LearningAdapter()
      ..learningStrength = 1.0
      ..loadFromJsonMap(_model(intercept: 1.0));

    for (int i = 0; i < 9; i += 1) {
      adapter.updateOnBeat(AudioFeatures.zero);
    }

    expect(adapter.observationCount, 9);
    expect(adapter.learnedSpeedMult, closeTo(0.5, 1e-12));
    expect(adapter.cadenceHint, 2);
  });

  test('LearningAdapter converges to cadenceHint 4 for quiet predictions', () {
    final LearningAdapter adapter = LearningAdapter()
      ..learningStrength = 1.0
      ..loadFromJsonMap(_model(intercept: 0.0));

    for (int i = 0; i < 30; i += 1) {
      adapter.updateOnBeat(AudioFeatures.zero);
    }

    expect(adapter.isActive, isTrue);
    expect(adapter.learnedSpeedMult, lessThan(0.15));
    expect(adapter.cadenceHint, 4);
  });

  test('LearningAdapter converges to cadenceHint 1 for loud predictions', () {
    final LearningAdapter adapter = LearningAdapter()
      ..learningStrength = 1.0
      ..loadFromJsonMap(_model(intercept: 1.0));

    for (int i = 0; i < 12; i += 1) {
      adapter.updateOnBeat(AudioFeatures.zero);
    }

    expect(adapter.isActive, isTrue);
    expect(adapter.learnedSpeedMult, greaterThan(0.45));
    expect(adapter.cadenceHint, 1);
  });

  test('LearningAdapter reset keeps history and fullReset clears it', () {
    final LearningAdapter adapter = LearningAdapter()
      ..learningStrength = 1.0
      ..loadFromJsonMap(_model(intercept: 1.0));

    adapter.pushFrame(AudioFeatures.zero);
    adapter.pushFrame(AudioFeatures.zero);
    adapter.updateOnBeat(AudioFeatures.zero);

    adapter.reset();
    expect(adapter.historyCount, 2);
    expect(adapter.learnedSpeedMult, closeTo(0.5, 1e-12));
    expect(adapter.cadenceHint, 2);
    expect(adapter.observationCount, 0);

    adapter.fullReset();
    expect(adapter.historyCount, 0);
    expect(adapter.learnedSpeedMult, closeTo(0.5, 1e-12));
    expect(adapter.cadenceHint, 2);
  });
}

Map<String, dynamic> _model({
  required double intercept,
  List<String> featureColumns = const <String>[],
  Map<String, double> means = const <String, double>{},
  Map<String, double> stds = const <String, double>{},
  Map<String, double> coefficients = const <String, double>{},
  double quietThreshold = 0.15,
  double midThreshold = 0.45,
}) {
  return <String, dynamic>{
    'status': 'ok',
    'feature_columns': featureColumns,
    'normalization': <String, dynamic>{'mean': means, 'std': stds},
    'models': <String, dynamic>{
      'speed_mult': <String, dynamic>{
        'intercept': intercept,
        'coefficients': coefficients,
      },
    },
    'cadence_rule': <String, dynamic>{
      'quiet_threshold': quietThreshold,
      'mid_threshold': midThreshold,
    },
  };
}
