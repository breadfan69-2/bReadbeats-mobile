import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/providers/heartbeat_tick_prelude_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatTickPreludeMapper mapper = HeartbeatTickPreludeMapper();

  test('maps prelude context and passes nowSec to callbacks', () {
    final AudioFeatures features = AudioFeatures.zero;
    double? consumeNowSec;
    double? forceNowSec;

    final HeartbeatTickPrelude prelude = mapper.map(
      nowMs: 1710412345678,
      hdlcDroppedFrames: 7,
      lastPcmTimestampMs: 1710412344300,
      features: features,
      consumeDtSec: (double nowSec) {
        consumeNowSec = nowSec;
        return 0.033;
      },
      shouldForceSync: (double nowSec) {
        forceNowSec = nowSec;
        return true;
      },
    );

    expect(prelude.nowSec, closeTo(1710412345.678, 1e-6));
    expect(prelude.nowMs, 1710412345678);
    expect(prelude.hdlcDroppedFrames, 7);
    expect(prelude.hasRecentPcm, isTrue);
    expect(prelude.dtSec, closeTo(0.033, 1e-12));
    expect(prelude.forceSync, isTrue);
    expect(prelude.features, same(features));
    expect(consumeNowSec, closeTo(prelude.nowSec, 1e-6));
    expect(forceNowSec, closeTo(prelude.nowSec, 1e-6));
  });

  test('hasRecentPcm threshold is inclusive at 1500 ms', () {
    final HeartbeatTickPrelude atThreshold = mapper.map(
      nowMs: 5000,
      hdlcDroppedFrames: 0,
      lastPcmTimestampMs: 3500,
      features: AudioFeatures.zero,
      consumeDtSec: (_) => 0.0,
      shouldForceSync: (_) => false,
    );

    final HeartbeatTickPrelude beyondThreshold = mapper.map(
      nowMs: 5000,
      hdlcDroppedFrames: 0,
      lastPcmTimestampMs: 3499,
      features: AudioFeatures.zero,
      consumeDtSec: (_) => 0.0,
      shouldForceSync: (_) => false,
    );

    expect(atThreshold.hasRecentPcm, isTrue);
    expect(beyondThreshold.hasRecentPcm, isFalse);
  });
}
