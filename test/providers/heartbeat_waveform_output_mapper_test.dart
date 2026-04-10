import 'package:breadbeats_mobile/providers/heartbeat_waveform_output_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatWaveformOutputMapper mapper =
      HeartbeatWaveformOutputMapper();

  test('clamps carrier and applies unity derating when tau is zero', () {
    final HeartbeatWaveformOutput output = mapper.map(
      amplitudeAmps: 0.8,
      startupRamp: 0.5,
      carrierHz: 5000.0,
      carrierMinHz: 300.0,
      carrierMaxHz: 1200.0,
      tauMicros: 0.0,
    );

    expect(output.carrierToSend, closeTo(1200.0, 1e-12));
    expect(output.tauDerating, closeTo(1.0, 1e-12));
    expect(output.amplitudeToSend, closeTo(0.4, 1e-12));
  });

  test('derates amplitude proportionally for non-zero tau', () {
    final HeartbeatWaveformOutput output = mapper.map(
      amplitudeAmps: 2.0,
      startupRamp: 0.5,
      carrierHz: 600.0,
      carrierMinHz: 300.0,
      carrierMaxHz: 1200.0,
      tauMicros: 200.0,
    );

    // tauSec = 0.0002
    // numerator = 600 * 0.0002 + 0.5 = 0.62
    // denominator = 1200 * 0.0002 + 0.5 = 0.74
    // derating = 0.62 / 0.74
    const double expectedDerating = 0.62 / 0.74;
    expect(output.carrierToSend, closeTo(600.0, 1e-12));
    expect(output.tauDerating, closeTo(expectedDerating, 1e-12));
    expect(output.amplitudeToSend, closeTo(expectedDerating, 1e-12));
  });

  test('uses max carrier as reference for tau derating', () {
    final HeartbeatWaveformOutput atMaxCarrier = mapper.map(
      amplitudeAmps: 1.0,
      startupRamp: 1.0,
      carrierHz: 1200.0,
      carrierMinHz: 300.0,
      carrierMaxHz: 1200.0,
      tauMicros: 200.0,
    );
    final HeartbeatWaveformOutput belowMaxCarrier = mapper.map(
      amplitudeAmps: 1.0,
      startupRamp: 1.0,
      carrierHz: 700.0,
      carrierMinHz: 300.0,
      carrierMaxHz: 1200.0,
      tauMicros: 200.0,
    );

    expect(atMaxCarrier.tauDerating, closeTo(1.0, 1e-12));
    expect(belowMaxCarrier.tauDerating, lessThan(1.0));
    expect(belowMaxCarrier.amplitudeToSend, lessThan(atMaxCarrier.amplitudeToSend));
  });
}
