import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connection_provider.dart';
import '../../widgets/neumorphic_tile.dart';
import 'tile_button.dart';

class BeatIntelligenceTile extends StatelessWidget {
  const BeatIntelligenceTile({
    required this.onOpenDetail,
    required this.onToggleIntelligence,
    super.key,
  });

  final VoidCallback onOpenDetail;
  final VoidCallback onToggleIntelligence;

  @override
  Widget build(BuildContext context) {
    return Selector<
      ConnectionProvider,
      ({
        bool learningEnabled,
        bool tempoUnlockHoldEnabled,
        bool adaptiveLeadEnabled,
        bool hardFillGateEnabled,
      })
    >(
      selector: (_, ConnectionProvider c) => (
        learningEnabled: c.learningEnabled,
        tempoUnlockHoldEnabled: c.tempoUnlockHoldEnabled,
        adaptiveLeadEnabled: c.adaptiveLeadEnabled,
        hardFillGateEnabled: c.hardFillGateEnabled,
      ),
      builder: (_, data, _) {
        final bool anyActive =
            data.learningEnabled ||
            data.tempoUnlockHoldEnabled ||
            data.adaptiveLeadEnabled ||
            data.hardFillGateEnabled;

        final List<String> activeNames = <String>[
          if (data.learningEnabled) 'Learning',
          if (data.tempoUnlockHoldEnabled) 'Tempo Hold',
          if (data.adaptiveLeadEnabled) 'Adaptive Lead',
          if (data.hardFillGateEnabled) 'Hard Fill Gate',
        ];

        final String subtitle = activeNames.isNotEmpty
            ? activeNames.join(' · ')
            : 'Off';

        return NeumorphicTile(
          depth: 5,
          sunken: !anyActive,
          onTap: onToggleIntelligence,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.psychology,
                    size: 20,
                    color: anyActive ? kAccentCyan : Colors.white38,
                  ),
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
                'BRAIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: anyActive ? kAccentCyan : Colors.white38,
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
