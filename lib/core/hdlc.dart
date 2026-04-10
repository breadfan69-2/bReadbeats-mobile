import 'dart:typed_data';

class HdlcFramer {
  static const int frameBoundaryMarker = 0x7E;
  static const int escapeMarker = 0x7D;
  static const int escapeXor = 0x20;

  final List<int> _frameBuffer = <int>[];
  bool _inFrame = false;
  bool _escapeNext = false;
  int _droppedFrameCount = 0;

  int get droppedFrameCount => _droppedFrameCount;

  Uint8List encode(List<int> payload) {
    final int crc = _crc16X25(payload);
    final List<int> frameData = <int>[
      ...payload,
      crc & 0xFF,
      (crc >> 8) & 0xFF,
    ];

    final List<int> encoded = <int>[frameBoundaryMarker];
    for (final int value in frameData) {
      if (value == frameBoundaryMarker || value == escapeMarker) {
        encoded
          ..add(escapeMarker)
          ..add(value ^ escapeXor);
      } else {
        encoded.add(value);
      }
    }
    encoded.add(frameBoundaryMarker);

    return Uint8List.fromList(encoded);
  }

  List<Uint8List> parse(Uint8List data) {
    final List<Uint8List> frames = <Uint8List>[];

    for (final int value in data) {
      if (value == frameBoundaryMarker) {
        if (_inFrame && _frameBuffer.isNotEmpty) {
          final Uint8List? frame = _finalizeFrame();
          if (frame != null) {
            frames.add(frame);
          }
        }

        _inFrame = true;
        _escapeNext = false;
        _frameBuffer.clear();
        continue;
      }

      if (!_inFrame) {
        continue;
      }

      if (_escapeNext) {
        _frameBuffer.add(value ^ escapeXor);
        _escapeNext = false;
        continue;
      }

      if (value == escapeMarker) {
        _escapeNext = true;
        continue;
      }

      _frameBuffer.add(value);
    }

    return frames;
  }

  void reset() {
    _frameBuffer.clear();
    _inFrame = false;
    _escapeNext = false;
  }

  void clearDroppedFrameCount() {
    _droppedFrameCount = 0;
  }

  Uint8List? _finalizeFrame() {
    if (_frameBuffer.length < 3) {
      _droppedFrameCount += 1;
      return null;
    }

    final int crcOffset = _frameBuffer.length - 2;
    final List<int> payload = _frameBuffer.sublist(0, crcOffset);
    final int expectedCrc =
        _frameBuffer[crcOffset] | (_frameBuffer[crcOffset + 1] << 8);
    final int computedCrc = _crc16X25(payload);

    if (expectedCrc != computedCrc) {
      _droppedFrameCount += 1;
      return null;
    }

    return Uint8List.fromList(payload);
  }

  int _crc16X25(List<int> data) {
    int crc = 0xFFFF;
    for (final int value in data) {
      crc ^= value & 0xFF;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x0001) != 0) {
          crc = (crc >> 1) ^ 0x8408;
        } else {
          crc >>= 1;
        }
      }
    }

    crc = ~crc;
    return crc & 0xFFFF;
  }
}
