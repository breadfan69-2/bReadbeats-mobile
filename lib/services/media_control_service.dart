import 'package:flutter/services.dart';

/// Dispatches Android media key events to the active media session.
///
/// Uses [AudioManager.dispatchMediaKeyEvent] via a platform method channel.
/// No special permissions are required. Keys are routed by Android to
/// whichever app currently holds audio focus.
class MediaControlService {
  MediaControlService._();

  static const MethodChannel _channel = MethodChannel(
    'com.breadbeats.mobile/media/methods',
  );

  static Future<void> prev() => _channel.invokeMethod<void>('mediaPrev');

  static Future<void> playPause() =>
      _channel.invokeMethod<void>('mediaPlayPause');

  static Future<void> next() => _channel.invokeMethod<void>('mediaNext');

  static Future<bool> isPlaying() async =>
      await _channel.invokeMethod<bool>('mediaIsPlaying') ?? false;
}
