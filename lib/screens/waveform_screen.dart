import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../widgets/shared_widgets.dart';

/// Combined waveform + tuning + signal detail screen.
class WaveformScreen extends StatelessWidget {
  const WaveformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ConnectionProvider c = context.watch<ConnectionProvider>();

    return DetailScreenScaffold(
      title: 'Waveform',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          LabeledSlider(
            label: 'Carrier Frequency (Hz)',
            value: c.carrierHz,
            min: c.carrierMinHz,
            max: c.carrierMaxHz,
            divisions: ((c.carrierMaxHz - c.carrierMinHz) / 10).round().clamp(
              1,
              500,
            ),
            onChanged: c.setCarrierHz,
          ),
          const SizedBox(height: 4),
          Text(
            'Range: ${c.carrierMinHz.toStringAsFixed(0)} – ${c.carrierMaxHz.toStringAsFixed(0)} Hz\n'
            '(Adjust range in Calibration)',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 32),
          Row(
            children: <Widget>[
              const Text('Auto (music)', style: TextStyle(fontSize: 12)),
              Switch(value: c.manualPulseMode, onChanged: c.setManualPulseMode),
              const Text('Manual', style: TextStyle(fontSize: 12)),
            ],
          ),
          if (c.manualPulseMode)
            LabeledSlider(
              label: 'Pulse Frequency (Hz)',
              value: c.manualPulseHz,
              min: c.pulseMinHz,
              max: c.pulseMaxHz,
              divisions: ((c.pulseMaxHz - c.pulseMinHz)).round().clamp(1, 500),
              onChanged: c.setManualPulseHz,
            )
          else
            LabeledRangeSlider(
              label: 'Pulse Range (Hz)',
              values: RangeValues(c.pulseMinHz, c.pulseMaxHz),
              min: 5.0,
              max: 100.0,
              divisions: 95,
              onChanged: (RangeValues values) {
                c.setPulseRange(values.start, values.end);
              },
            ),
          if (c.sessionRunning)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Bass: ${c.liveDominantBassHz.toStringAsFixed(0)} Hz',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Pulse → ${c.liveEffectivePulseHz.toStringAsFixed(1)} Hz',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 32),
          LabeledSlider(
            label: 'Pulse Width (cycles)',
            value: c.pulseWidthCycles,
            min: 4.0,
            max: 100.0,
            divisions: 96,
            onChanged: c.setPulseWidthCycles,
          ),
          LabeledSlider(
            label: 'Pulse Rise Time (cycles)',
            value: c.pulseRiseTimeCycles,
            min: 2.0,
            max: (c.pulseWidthCycles * 0.9).clamp(2.0, 100.0),
            divisions:
                (((c.pulseWidthCycles * 0.9).clamp(2.0, 100.0) - 2.0) * 10)
                    .round()
                    .clamp(1, 980),
            onChanged: c.setPulseRiseTimeCycles,
          ),
          LabeledSlider(
            label: 'Pulse Interval Random (%)',
            value: c.pulseIntervalRandomPercent,
            min: 0.0,
            max: 100.0,
            divisions: 100,
            onChanged: c.setPulseIntervalRandomPercent,
          ),
        ],
      ),
    );
  }
}
