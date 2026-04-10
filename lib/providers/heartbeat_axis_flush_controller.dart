class HeartbeatAxisFlushController {
  const HeartbeatAxisFlushController();

  Future<void> flush({
    required List<Future<void>> operations,
    required bool forceSync,
    required double nowSec,
    required void Function(double nowSec) markFullSync,
  }) async {
    await Future.wait(operations);
    if (forceSync) {
      markFullSync(nowSec);
    }
  }
}
