import '../audio/processing/audio_signal_processor.dart';

class HeartbeatTickPrelude {
  const HeartbeatTickPrelude({
    required this.nowSec,
    required this.nowMs,
    required this.hdlcDroppedFrames,
    required this.hasRecentPcm,
    required this.dtSec,
    required this.forceSync,
    required this.features,
  });

  final double nowSec;
  final int nowMs;
  final int hdlcDroppedFrames;
  final bool hasRecentPcm;
  final double dtSec;
  final bool forceSync;
  final AudioFeatures features;
}

class HeartbeatTickPreludeMapper {
  const HeartbeatTickPreludeMapper();

  HeartbeatTickPrelude map({
    required int nowMs,
    required int hdlcDroppedFrames,
    required int lastPcmTimestampMs,
    required AudioFeatures features,
    required double Function(double nowSec) consumeDtSec,
    required bool Function(double nowSec) shouldForceSync,
  }) {
    final double nowSec = nowMs / 1000.0;
    final bool hasRecentPcm = (nowMs - lastPcmTimestampMs) <= 1500;
    final double dtSec = consumeDtSec(nowSec);
    final bool forceSync = shouldForceSync(nowSec);

    return HeartbeatTickPrelude(
      nowSec: nowSec,
      nowMs: nowMs,
      hdlcDroppedFrames: hdlcDroppedFrames,
      hasRecentPcm: hasRecentPcm,
      dtSec: dtSec,
      forceSync: forceSync,
      features: features,
    );
  }
}