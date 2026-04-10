class AdaptiveLead {
  AdaptiveLead({required this.baseLead, this.correctionGain = 0.35})
      : _currentLead = baseLead;

  final double baseLead;

  static const double _emaAlpha = 0.25;
  double correctionGain;
  static const double _maxLead = 200.0;
  static const double _minLead = -50.0;
  static const int _minObservations = 3;
  static const double _noiseFloorMs = 30.0;

  double _currentLead;
  double _errorEma = 0.0;
  int _observationCount = 0;

  double get leadMs => _currentLead;
  int get observationCount => _observationCount;

  void observe(double phaseErrorMs) {
    final double clampedError = phaseErrorMs.abs() < _noiseFloorMs
        ? 0.0
        : phaseErrorMs;

    _errorEma = _errorEma * (1.0 - _emaAlpha) + clampedError * _emaAlpha;
    _observationCount += 1;

    if (_observationCount >= _minObservations) {
      _currentLead = (_currentLead + _errorEma * correctionGain).clamp(
        _minLead,
        _maxLead,
      );
    }
  }

  void reset() {
    _currentLead = baseLead;
    _errorEma = 0.0;
    _observationCount = 0;
  }
}
