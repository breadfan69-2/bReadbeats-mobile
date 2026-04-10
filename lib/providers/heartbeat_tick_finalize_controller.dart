import 'heartbeat_axis_flush_controller.dart';

typedef MotionOutputRecorder =
    void Function({
      required double amplitudeToSend,
      required double base,
      required double amplitudeAmps,
      required int nowMs,
    });

class HeartbeatTickFinalizeController {
  const HeartbeatTickFinalizeController({
    this.heartbeatAxisFlushController = const HeartbeatAxisFlushController(),
  });

  final HeartbeatAxisFlushController heartbeatAxisFlushController;

  Future<void> finalize({
    required List<Future<void>> operations,
    required bool forceSync,
    required double nowSec,
    required void Function(double nowSec) markFullSync,
    required MotionOutputRecorder recordMotionOutput,
    required double amplitudeToSend,
    required double base,
    required double amplitudeAmps,
    required int nowMs,
  }) async {
    await heartbeatAxisFlushController.flush(
      operations: operations,
      forceSync: forceSync,
      nowSec: nowSec,
      markFullSync: markFullSync,
    );

    recordMotionOutput(
      amplitudeToSend: amplitudeToSend,
      base: base,
      amplitudeAmps: amplitudeAmps,
      nowMs: nowMs,
    );
  }
}
