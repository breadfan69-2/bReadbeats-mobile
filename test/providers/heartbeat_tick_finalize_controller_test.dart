import 'dart:async';

import 'package:breadbeats_mobile/providers/heartbeat_tick_finalize_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatTickFinalizeController controller =
      HeartbeatTickFinalizeController();

  test('finalize awaits flush operations before recording output', () async {
    final Completer<void> first = Completer<void>();
    final Completer<void> second = Completer<void>();
    bool markCalled = false;
    bool recordCalled = false;

    bool finalizeCompleted = false;
    final Future<void> finalizeFuture = controller
        .finalize(
          operations: <Future<void>>[first.future, second.future],
          forceSync: true,
          nowSec: 9.5,
          markFullSync: (_) {
            markCalled = true;
          },
          recordMotionOutput:
              ({
                required double amplitudeToSend,
                required double base,
                required double amplitudeAmps,
                required int nowMs,
              }) {
                recordCalled = true;
              },
          amplitudeToSend: 0.6,
          base: 0.4,
          amplitudeAmps: 0.2,
          nowMs: 123,
        )
        .then((_) {
          finalizeCompleted = true;
        });

    await Future<void>.delayed(Duration.zero);
    expect(finalizeCompleted, isFalse);
    expect(markCalled, isFalse);
    expect(recordCalled, isFalse);

    first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(finalizeCompleted, isFalse);
    expect(markCalled, isFalse);
    expect(recordCalled, isFalse);

    second.complete();
    await finalizeFuture;

    expect(finalizeCompleted, isTrue);
    expect(markCalled, isTrue);
    expect(recordCalled, isTrue);
  });

  test('finalize skips full sync mark when forceSync is false', () async {
    int markCalls = 0;
    int recordCalls = 0;

    await controller.finalize(
      operations: <Future<void>>[Future<void>.value()],
      forceSync: false,
      nowSec: 7.25,
      markFullSync: (_) {
        markCalls++;
      },
      recordMotionOutput:
          ({
            required double amplitudeToSend,
            required double base,
            required double amplitudeAmps,
            required int nowMs,
          }) {
            recordCalls++;
          },
      amplitudeToSend: 0.8,
      base: 0.31,
      amplitudeAmps: 0.19,
      nowMs: 77,
    );

    expect(markCalls, 0);
    expect(recordCalls, 1);
  });

  test('finalize forwards full motion output payload to recorder', () async {
    double? observedAmplitudeToSend;
    double? observedBase;
    double? observedAmplitudeAmps;
    int? observedNowMs;
    double? observedNowSec;

    await controller.finalize(
      operations: const <Future<void>>[],
      forceSync: true,
      nowSec: 42.75,
      markFullSync: (double nowSec) {
        observedNowSec = nowSec;
      },
      recordMotionOutput:
          ({
            required double amplitudeToSend,
            required double base,
            required double amplitudeAmps,
            required int nowMs,
          }) {
            observedAmplitudeToSend = amplitudeToSend;
            observedBase = base;
            observedAmplitudeAmps = amplitudeAmps;
            observedNowMs = nowMs;
          },
      amplitudeToSend: 0.91,
      base: 0.27,
      amplitudeAmps: 0.18,
      nowMs: 888,
    );

    expect(observedNowSec, closeTo(42.75, 1e-12));
    expect(observedAmplitudeToSend, closeTo(0.91, 1e-12));
    expect(observedBase, closeTo(0.27, 1e-12));
    expect(observedAmplitudeAmps, closeTo(0.18, 1e-12));
    expect(observedNowMs, 888);
  });
}
