import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/capture/audio_capture_platform_service.dart';
import '../../providers/connection_provider.dart';
import '../../services/media_control_service.dart';
import '../../widgets/embossed_media_icon.dart';
import '../../widgets/neumorphic_tile.dart';
import 'tile_button.dart';

class AudioTile extends StatelessWidget {
  const AudioTile({
    required this.onOpenDetail,
    required this.onPickAudioSource,
    super.key,
  });

  final VoidCallback onOpenDetail;
  final VoidCallback onPickAudioSource;

  @override
  Widget build(BuildContext context) {
    return Selector<ConnectionProvider, CapturableApp?>(
      selector: (_, ConnectionProvider c) => c.selectedCaptureApp,
      builder: (_, CapturableApp? app, _) {
        return NeumorphicTile(
          depth: 5,
          sunken: app == null,
          onTap: onOpenDetail,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'AUDIO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app?.appName ?? 'No source',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: app != null ? kAccentCyan : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (app != null) ...<Widget>[
                      _EmbossedMediaButton(
                        shape: MediaIconShape.rewind,
                        iconSize: 28,
                        onPressed: () => unawaited(MediaControlService.prev()),
                      ),
                      const SizedBox(width: 6),
                      _EmbossedMediaButton(
                        shape: MediaIconShape.playPause,
                        iconSize: 34,
                        onPressed: () =>
                            unawaited(MediaControlService.playPause()),
                      ),
                      const SizedBox(width: 6),
                      _EmbossedMediaButton(
                        shape: MediaIconShape.forward,
                        iconSize: 28,
                        onPressed: () => unawaited(MediaControlService.next()),
                      ),
                    ],
                  ],
                ),
              ),
              HomeTileButton(
                icon: Icons.more_horiz,
                size: 18,
                onPressed: onPickAudioSource,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmbossedMediaButton extends StatelessWidget {
  const _EmbossedMediaButton({
    required this.shape,
    this.iconSize = 24.0,
    required this.onPressed,
  });

  final MediaIconShape shape;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final double tapSize = iconSize + 14;
    return SizedBox(
      width: tapSize,
      height: tapSize,
      child: IconButton(
        icon: EmbossedMediaIcon(shape: shape, size: iconSize),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        constraints: BoxConstraints(minWidth: tapSize, minHeight: tapSize),
        splashRadius: iconSize,
        tooltip: '',
      ),
    );
  }
}
