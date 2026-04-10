import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_models.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/neumorphic_tile.dart';
import 'tile_button.dart';

class ManualModeTile extends StatelessWidget {
  const ManualModeTile({required this.onOpenManual, super.key});

  final VoidCallback onOpenManual;

  @override
  Widget build(BuildContext context) {
    return Selector<ConnectionProvider, OutputModeSelection>(
      selector: (_, ConnectionProvider c) => c.outputMode,
      builder: (_, OutputModeSelection outputMode, _) {
        final String phaseLabel = outputMode == OutputModeSelection.fourPhase
            ? '4-Phase'
            : '3-Phase';

        return NeumorphicTile(
          depth: 5,
          onTap: onOpenManual,
          onLongPress: onOpenManual,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.touch_app, size: 20, color: kAccentCyan),
                  const Spacer(),
                  HomeTileButton(
                    icon: Icons.more_horiz,
                    size: 18,
                    onPressed: onOpenManual,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'MANUAL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Direct touch control • $phaseLabel',
                style: const TextStyle(
                  color: kAccentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
