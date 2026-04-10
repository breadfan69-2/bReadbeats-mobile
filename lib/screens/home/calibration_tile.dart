import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_models.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/neumorphic_tile.dart';
import 'tile_button.dart';

class CalibrationTile extends StatelessWidget {
  const CalibrationTile({required this.onOpenDetail, super.key});

  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Selector<ConnectionProvider, OutputModeSelection>(
      selector: (_, ConnectionProvider c) => c.outputMode,
      builder: (_, outputMode, _) {
        return NeumorphicTile(
          depth: 5,
          onTap: onOpenDetail,
          onLongPress: onOpenDetail,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.build, size: 20, color: kAccentCyan),
                  const Spacer(),
                  HomeTileButton(
                    icon: Icons.more_horiz,
                    size: 18,
                    onPressed: onOpenDetail,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'CALIBRATE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                outputMode == OutputModeSelection.threePhase
                    ? '3-Phase'
                    : '4-Phase',
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
