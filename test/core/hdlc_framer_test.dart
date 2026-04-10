import 'dart:typed_data';

import 'package:breadbeats_mobile/core/hdlc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HdlcFramer', () {
    test('round-trips payload bytes', () {
      final HdlcFramer framer = HdlcFramer();
      final Uint8List payload = Uint8List.fromList(<int>[
        0x01,
        0x02,
        HdlcFramer.escapeMarker,
        0x10,
        HdlcFramer.frameBoundaryMarker,
        0x33,
      ]);

      final Uint8List encoded = framer.encode(payload);
      final List<Uint8List> decoded = framer.parse(encoded);

      expect(decoded, hasLength(1));
      expect(decoded.single, orderedEquals(payload));
      expect(framer.droppedFrameCount, 0);
    });

    test('drops frame when CRC is corrupted', () {
      final HdlcFramer framer = HdlcFramer();
      final Uint8List payload = Uint8List.fromList(<int>[10, 20, 30, 40, 50]);
      final Uint8List encoded = framer.encode(payload);
      final Uint8List corrupted = Uint8List.fromList(encoded);

      int mutateIndex = 1;
      while (mutateIndex < (corrupted.length - 1) &&
          (corrupted[mutateIndex] == HdlcFramer.frameBoundaryMarker ||
              corrupted[mutateIndex] == HdlcFramer.escapeMarker)) {
        mutateIndex += 1;
      }
      corrupted[mutateIndex] ^= 0x01;

      final List<Uint8List> decoded = framer.parse(corrupted);

      expect(decoded, isEmpty);
      expect(framer.droppedFrameCount, 1);
    });
  });
}
