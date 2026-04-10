import 'heartbeat_orchestrator.dart';

class HeartbeatMotionStateController {
  HeartbeatMotionStateController({required double fillBaseRadius})
    : _fillRadius = fillBaseRadius;

  double _motionDriveLevel = 0.0;
  double _liveEffectivePulseHz = 50.0;
  double _smoothedDominantBassHz = 0.0;
  double _effectivePulseHz = 50.0;

  bool _phraseCommitted = false;
  int _phraseBeatCount = 0;
  double _fluxEmaPhrase = 0.0;
  double _phraseFluxAtStart = 0.0;

  double _fillAngle = 0.0;
  double _fillRadius;
  double _fillCenterY = 0.0;
  int _lastBeatTriggerMs = 0;
  double _fillTransition = 0.0;
  double _fillHhImpulse = 0.0;
  int _fillSilenceStartMs = 0;

  double get motionDriveLevel => _motionDriveLevel;
  double get liveEffectivePulseHz => _liveEffectivePulseHz;
  double get smoothedDominantBassHz => _smoothedDominantBassHz;
  double get effectivePulseHz => _effectivePulseHz;

  bool get phraseCommitted => _phraseCommitted;
  int get phraseBeatCount => _phraseBeatCount;
  double get fluxEmaPhrase => _fluxEmaPhrase;
  double get phraseFluxAtStart => _phraseFluxAtStart;

  double get fillAngle => _fillAngle;
  double get fillRadius => _fillRadius;
  double get fillCenterY => _fillCenterY;
  int get lastBeatTriggerMs => _lastBeatTriggerMs;
  double get fillTransition => _fillTransition;
  double get fillHhImpulse => _fillHhImpulse;
  int get fillSilenceStartMs => _fillSilenceStartMs;

  void setMotionDriveLevel(double value) {
    _motionDriveLevel = value;
  }

  void setInitialPulseFrequency(double pulseHz) {
    _effectivePulseHz = pulseHz;
    _liveEffectivePulseHz = pulseHz;
  }

  void resetPulseTracking({
    required double pulseMinHz,
    required double pulseMaxHz,
  }) {
    final double pulseHz = (pulseMinHz + pulseMaxHz) / 2.0;
    _liveEffectivePulseHz = pulseHz;
    _smoothedDominantBassHz = 0.0;
    _effectivePulseHz = pulseHz;
  }

  void resetOrbitState({required double fillBaseRadius}) {
    _phraseCommitted = false;
    _phraseBeatCount = 0;
    _fluxEmaPhrase = 0.0;
    _phraseFluxAtStart = 0.0;
    _fillAngle = 0.0;
    _fillRadius = fillBaseRadius;
    _fillCenterY = 0.0;
    _lastBeatTriggerMs = 0;
    _fillTransition = 0.0;
  }

  void applyOrchestratorOutput(HeartbeatOrchestratorOutput output) {
    _motionDriveLevel = output.motionDriveLevel;
    _fluxEmaPhrase = output.fluxEmaPhrase;
    _phraseCommitted = output.phraseCommitted;
    _phraseBeatCount = output.phraseBeatCount;
    _phraseFluxAtStart = output.phraseFluxAtStart;
    _lastBeatTriggerMs = output.lastBeatTriggerMs;
    _fillSilenceStartMs = output.fillSilenceStartMs;
    _fillTransition = output.fillTransition;
    _fillCenterY = output.fillCenterY;
    _fillRadius = output.fillRadius;
    _fillAngle = output.fillAngle;
    _fillHhImpulse = output.fillHhImpulse;
    _smoothedDominantBassHz = output.smoothedDominantBassHz;
    _effectivePulseHz = output.effectivePulseHz;
    _liveEffectivePulseHz = output.effectivePulseHz;
  }
}
