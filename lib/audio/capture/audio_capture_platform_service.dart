import 'dart:async';

import 'package:flutter/services.dart';

class CapturableApp {
  const CapturableApp({
    required this.packageName,
    required this.appName,
    required this.uid,
  });

  final String packageName;
  final String appName;
  final int uid;

  @override
  String toString() => '$appName ($packageName)';
}

class AudioCapturePlatformService {
  static const MethodChannel _methods = MethodChannel(
    'com.breadbeats.mobile/audio_capture/methods',
  );
  static const EventChannel _events = EventChannel(
    'com.breadbeats.mobile/audio_capture/events',
  );

  Stream<Map<String, dynamic>> events() {
    return _events.receiveBroadcastStream().map((dynamic event) {
      if (event is Map<dynamic, dynamic>) {
        return event.map(
          (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        );
      }
      return <String, dynamic>{};
    });
  }

  Future<List<CapturableApp>> listCapturableApps() async {
    final List<dynamic>? raw = await _methods.invokeMethod<List<dynamic>>(
      'listCapturableApps',
    );

    if (raw == null) {
      return <CapturableApp>[];
    }

    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> item) {
          return CapturableApp(
            packageName: (item['packageName'] ?? '').toString(),
            appName: (item['appName'] ?? '').toString(),
            uid: (item['uid'] is int)
                ? item['uid'] as int
                : int.tryParse((item['uid'] ?? '0').toString()) ?? 0,
          );
        })
        .where((CapturableApp app) => app.packageName.isNotEmpty)
        .toList();
  }

  Future<bool> requestProjectionConsent() async {
    final bool? granted = await _methods.invokeMethod<bool>(
      'requestProjectionConsent',
    );
    return granted ?? false;
  }

  Future<void> startCapture({
    required String packageName,
    required int uid,
    int channels = 2,
  }) async {
    final int safeChannels = channels >= 2 ? 2 : 1;
    await _methods.invokeMethod<void>('startCapture', <String, dynamic>{
      'packageName': packageName,
      'uid': uid,
      'channels': safeChannels,
    });
  }

  Future<void> stopCapture({bool releaseProjection = false}) async {
    final String method = releaseProjection
        ? 'stopCaptureAndReleaseProjection'
        : 'stopCapture';
    await _methods.invokeMethod<void>(method);
  }
}
