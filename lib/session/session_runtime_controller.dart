class SessionRuntimeController {
  double _sessionStartSec = 0.0;
  int _lastMotionOutputMs = 0;
  int _motionCommandTicks = 0;
  double _lastAmplitudeAmps = 0.0;

  int get motionCommandTicks => _motionCommandTicks;
  double get lastAmplitudeAmps => _lastAmplitudeAmps;

  void beginSession() {
    _motionCommandTicks = 0;
    _lastAmplitudeAmps = 0.0;
    _lastMotionOutputMs = 0;
    _sessionStartSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
  }

  void clearSessionClock() {
    _sessionStartSec = 0.0;
  }

  double startupRampAt({
    required double nowSec,
    required double startupRampDurationSec,
  }) {
    if (_sessionStartSec <= 0.0) {
      return 1.0;
    }
    final double elapsedSec = nowSec - _sessionStartSec;
    if (elapsedSec <= 0.0) {
      return 0.0;
    }
    return (elapsedSec / startupRampDurationSec).clamp(0.0, 1.0);
  }

  void resetMotionActivity({bool resetTicks = false}) {
    _lastAmplitudeAmps = 0.0;
    _lastMotionOutputMs = 0;
    if (resetTicks) {
      _motionCommandTicks = 0;
    }
  }

  void recordCalibrationOutput({
    required double amplitudeToSend,
    required int nowMs,
  }) {
    _lastAmplitudeAmps = amplitudeToSend;
    _motionCommandTicks += 1;
    _lastMotionOutputMs = nowMs;
  }

  void recordMotionOutput({
    required double amplitudeToSend,
    required double base,
    required double amplitudeAmps,
    required int nowMs,
  }) {
    _lastAmplitudeAmps = amplitudeToSend;
    if (base > 0.01 && amplitudeAmps > 0.0008) {
      _motionCommandTicks += 1;
      _lastMotionOutputMs = nowMs;
    }
  }

  bool isAudioMotionActive({
    required int nowMs,
    required bool sessionRunning,
    required bool captureRunning,
    required bool liveGateOpen,
    required double motionDriveLevel,
  }) {
    final bool recentMotion = (nowMs - _lastMotionOutputMs) <= 700;
    return sessionRunning &&
        captureRunning &&
        liveGateOpen &&
        recentMotion &&
        motionDriveLevel > 0.04 &&
        _lastAmplitudeAmps > 0.0008;
  }
}
