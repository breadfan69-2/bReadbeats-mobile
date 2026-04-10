import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/haptics.dart';
import '../../models/device_models.dart';
import '../../providers/connection_provider.dart';
import '../../widgets/neumorphic_tile.dart';
import 'tile_button.dart';

// Pages: 0=R(Ω), 1=X(Ω), 2=RMS(A), 3=Peak(A), 4=Power
const int _kPageCount = 5;

class TelemetryTile extends StatefulWidget {
  const TelemetryTile({required this.onOpenDetail, super.key});

  final VoidCallback onOpenDetail;

  @override
  State<TelemetryTile> createState() => _TelemetryTileState();
}

class _TelemetryTileState extends State<TelemetryTile> {
  int _telemetryPage = 0;

  @override
  Widget build(BuildContext context) {
    return Selector<
      ConnectionProvider,
      ({
        OutputModeSelection outputMode,
        double rA, double rB, double rC, double rD,
        double xA, double xB, double xC, double xD,
        double rmsA, double rmsB, double rmsC, double rmsD,
        double peakA, double peakB, double peakC, double peakD,
        double outputPowerW, double outputPowerSkinW,
        double peakCmd,
      })
    >(
      selector: (_, ConnectionProvider c) => (
        outputMode: c.outputMode,
        rA: c.telemetryResistanceA,
        rB: c.telemetryResistanceB,
        rC: c.telemetryResistanceC,
        rD: c.telemetryResistanceD,
        xA: c.telemetryReluctanceA,
        xB: c.telemetryReluctanceB,
        xC: c.telemetryReluctanceC,
        xD: c.telemetryReluctanceD,
        rmsA: c.telemetryRmsA,
        rmsB: c.telemetryRmsB,
        rmsC: c.telemetryRmsC,
        rmsD: c.telemetryRmsD,
        peakA: c.telemetryPeakA,
        peakB: c.telemetryPeakB,
        peakC: c.telemetryPeakC,
        peakD: c.telemetryPeakD,
        outputPowerW: c.telemetryOutputPowerW,
        outputPowerSkinW: c.telemetryOutputPowerSkinW,
        peakCmd: c.telemetryPeakCmd,
      ),
      builder: (_, data, _) {
        final bool fourPhase = data.outputMode == OutputModeSelection.fourPhase;
        final int channelCount = fourPhase ? 4 : 3;

        return NeumorphicTile(
          depth: 5,
          onTap: widget.onOpenDetail,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.show_chart, size: 20, color: kAccentCyan),
                  const Spacer(),
                  HomeTileButton(
                    icon: Icons.more_horiz,
                    size: 18,
                    onPressed: () {
                      Haptics.light();
                      setState(
                        () => _telemetryPage = (_telemetryPage + 1) % _kPageCount,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'TELEMETRY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              _buildPage(data, fourPhase, channelCount),
              const SizedBox(height: 4),
              // Page indicator dots
              Row(
                children: List<Widget>.generate(_kPageCount, (int i) {
                  return Container(
                    width: i == _telemetryPage ? 12 : 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == _telemetryPage ? kAccentCyan : Colors.white24,
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage(dynamic data, bool fourPhase, int channelCount) {
    switch (_telemetryPage) {
      case 0:
        return _ElectrodeRow(
          label: 'R',
          unit: 'Ω',
          values: <double>[data.rA, data.rB, data.rC, if (fourPhase) data.rD],
          decimals: 0,
          channelCount: channelCount,
        );
      case 1:
        return _ElectrodeRow(
          label: 'X',
          unit: 'Ω',
          values: <double>[data.xA, data.xB, data.xC, if (fourPhase) data.xD],
          decimals: 0,
          channelCount: channelCount,
        );
      case 2:
        return _ElectrodeRow(
          label: 'RMS',
          unit: 'A',
          values: <double>[
            data.rmsA, data.rmsB, data.rmsC, if (fourPhase) data.rmsD,
          ],
          decimals: 3,
          channelCount: channelCount,
        );
      case 3:
        return _ElectrodeRow(
          label: 'Pk',
          unit: 'A',
          values: <double>[
            data.peakA, data.peakB, data.peakC, if (fourPhase) data.peakD,
          ],
          decimals: 3,
          channelCount: channelCount,
        );
      case 4:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${(data.outputPowerW * 1000).toStringAsFixed(1)} mW  '
              '(${(data.outputPowerSkinW * 1000).toStringAsFixed(1)} mW skin)',
              style: const TextStyle(
                color: kAccentCyan,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'pk cmd ${data.peakCmd.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        );
    }
  }
}

/// A compact labeled row of color-coded per-electrode values.
class _ElectrodeRow extends StatelessWidget {
  const _ElectrodeRow({
    required this.label,
    required this.unit,
    required this.values,
    required this.decimals,
    required this.channelCount,
  });

  final String label;
  final String unit;
  final List<double> values;
  final int decimals;
  final int channelCount;

  static const List<String> _chLabels = <String>['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final int count = values.length.clamp(0, channelCount);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 26,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...List<Widget>.generate(count, (int i) {
          final Color color = kElectrodeColors[i];
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < count - 1 ? 4 : 0),
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: color.withValues(alpha: 0.28),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    _chLabels[i],
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    values[i].toStringAsFixed(decimals),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(width: 3),
        Text(
          unit,
          style: const TextStyle(color: Colors.white24, fontSize: 9),
        ),
      ],
    );
  }
}

