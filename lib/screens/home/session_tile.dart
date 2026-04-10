import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device_models.dart';
import '../../models/enums.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/neumorphic_tile.dart';
import 'tile_button.dart';

class SessionTile extends StatelessWidget {
  const SessionTile({
    required this.onToggleSession,
    required this.onOpenDetail,
    super.key,
  });

  final Future<void> Function() onToggleSession;
  final VoidCallback onOpenDetail;

  static String _calibrationPatternLabel(CalibrationPattern pattern) {
    switch (pattern) {
      case CalibrationPattern.circle:
        return 'CIRCLE (CW)';
      case CalibrationPattern.circleReverse:
        return 'CIRCLE (CCW)';
      case CalibrationPattern.sequential1234:
        return '1→2→3→4';
      case CalibrationPattern.sequential4321:
        return '4→3→2→1';
      case CalibrationPattern.manual:
        return 'MANUAL';
      case CalibrationPattern.none:
        return 'PATTERN';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<
      ConnectionProvider,
      ({
        bool sessionRunning,
        bool buttonHoldMuted,
        OutputModeSelection outputMode,
        StimMode stimMode,
        CalibrationPattern calibrationPattern,
        bool showElectrodeBars,
        List<double> visibleElectrodeLevels,
      })
    >(
      selector: (_, ConnectionProvider c) => (
        sessionRunning: c.sessionRunning,
        buttonHoldMuted: c.buttonHoldMuted,
        outputMode: c.outputMode,
        stimMode: c.stimMode,
        calibrationPattern: c.calibrationPattern,
        showElectrodeBars: c.showElectrodeBars,
        visibleElectrodeLevels: c.visibleElectrodeLevels,
      ),
      shouldRebuild: (previous, next) =>
          previous.sessionRunning != next.sessionRunning ||
          previous.buttonHoldMuted != next.buttonHoldMuted ||
          previous.outputMode != next.outputMode ||
          previous.stimMode != next.stimMode ||
          previous.calibrationPattern != next.calibrationPattern ||
          previous.showElectrodeBars != next.showElectrodeBars ||
          !listEquals(
            previous.visibleElectrodeLevels,
            next.visibleElectrodeLevels,
          ),
      builder: (_, data, _) {
        return NeumorphicTile(
          depth: 10,
          sunken: !data.sessionRunning,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: <Widget>[
              HomeTileButton(
                icon: data.sessionRunning
                    ? Icons.stop_circle
                    : Icons.play_circle,
                size: 34,
                onPressed: () => unawaited(onToggleSession()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: data.sessionRunning
                                ? (data.buttonHoldMuted
                                      ? 'PAUSED'
                                      : data.calibrationPattern !=
                                            CalibrationPattern.none
                                      ? SessionTile._calibrationPatternLabel(
                                          data.calibrationPattern,
                                        )
                                      : 'PLAYING')
                                : 'PATTERN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text:
                                '  ${data.outputMode == OutputModeSelection.fourPhase ? '4-P' : '3-P'} • ${data.stimMode == StimMode.beat ? 'Beat' : 'Onset'}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (data.sessionRunning && data.showElectrodeBars)
                SizedBox(
                  width: 60,
                  height: 32,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List<Widget>.generate(
                      data.visibleElectrodeLevels.length,
                      (int index) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: FractionallySizedBox(
                            heightFactor: data.visibleElectrodeLevels[index]
                                .clamp(0.0, 1.0),
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: kElectrodeColors[index],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              HomeTileButton(icon: Icons.more_horiz, onPressed: onOpenDetail),
            ],
          ),
        );
      },
    );
  }
}
