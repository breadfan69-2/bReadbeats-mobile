import 'dart:async';

class HeartbeatLoopController {
  Timer? _timer;
  bool _inFlight = false;
  double _lastHeartbeatSec = 0.0;

  final Map<int, double> _lastSentAxis = <int, double>{};
  double _lastFullSyncSec = 0.0;

  bool get running => _timer != null;

  void start({required Duration interval, required void Function() onTick}) {
    stop();
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _inFlight = false;
  }

  bool tryBeginTick({required bool sessionRunning, required bool connected}) {
    if (_inFlight || !sessionRunning || !connected) {
      return false;
    }
    _inFlight = true;
    return true;
  }

  void endTick() {
    _inFlight = false;
  }

  double consumeDtSec(double nowSec) {
    final double dtSec = _lastHeartbeatSec > 0.0
        ? (nowSec - _lastHeartbeatSec).clamp(0.001, 0.5)
        : 0.033;
    _lastHeartbeatSec = nowSec;
    return dtSec;
  }

  bool shouldForceSync(double nowSec) {
    return (nowSec - _lastFullSyncSec) >= 1.0;
  }

  void markFullSync(double nowSec) {
    _lastFullSyncSec = nowSec;
  }

  bool shouldSendAxis({
    required int axisKey,
    required double value,
    required bool forceSync,
  }) {
    if (!forceSync && _lastSentAxis[axisKey] == value) {
      return false;
    }

    _lastSentAxis[axisKey] = value;
    return true;
  }

  void resetDeltaSyncState() {
    _lastSentAxis.clear();
    _lastFullSyncSec = 0.0;
  }

  void resetTickClock() {
    _lastHeartbeatSec = 0.0;
  }

  void dispose() {
    stop();
  }
}
