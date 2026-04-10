import 'dart:async';

import 'package:breadbeats_mobile/providers/heartbeat_axis_flush_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatAxisFlushController controller =
      HeartbeatAxisFlushController();

  test('flush awaits all operations before completing', () async {
    final Completer<void> first = Completer<void>();
    final Completer<void> second = Completer<void>();
    int markCallCount = 0;

    bool flushCompleted = false;
    final Future<void> flushFuture = controller
        .flush(
          operations: <Future<void>>[first.future, second.future],
          forceSync: true,
          nowSec: 12.5,
          markFullSync: (_) {
            markCallCount++;
          },
        )
        .then((_) {
          flushCompleted = true;
        });

    await Future<void>.delayed(Duration.zero);
    expect(flushCompleted, isFalse);

    first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(flushCompleted, isFalse);

    second.complete();
    await flushFuture;

    expect(flushCompleted, isTrue);
    expect(markCallCount, 1);
  });

  test('flush skips full-sync mark when forceSync is false', () async {
    int markCallCount = 0;

    await controller.flush(
      operations: <Future<void>>[Future<void>.value()],
      forceSync: false,
      nowSec: 99.0,
      markFullSync: (_) {
        markCallCount++;
      },
    );

    expect(markCallCount, 0);
  });

  test('flush passes through nowSec to mark callback', () async {
    double? observedNowSec;

    await controller.flush(
      operations: const <Future<void>>[],
      forceSync: true,
      nowSec: 42.75,
      markFullSync: (double nowSec) {
        observedNowSec = nowSec;
      },
    );

    expect(observedNowSec, closeTo(42.75, 1e-12));
  });
}
