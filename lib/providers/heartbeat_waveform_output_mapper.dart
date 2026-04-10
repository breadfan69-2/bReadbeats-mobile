class HeartbeatWaveformOutput {
  const HeartbeatWaveformOutput({
    required this.carrierToSend,
    required this.tauDerating,
    required this.amplitudeToSend,
  });

  final double carrierToSend;
  final double tauDerating;
  final double amplitudeToSend;
}

class HeartbeatWaveformOutputMapper {
  const HeartbeatWaveformOutputMapper();

  HeartbeatWaveformOutput map({
    required double amplitudeAmps,
    required double startupRamp,
    required double carrierHz,
    required double carrierMinHz,
    required double carrierMaxHz,
    required double tauMicros,
  }) {
    final double carrierToSend = carrierHz.clamp(carrierMinHz, carrierMaxHz);
    final double tauDerating = _carrierTauDerating(
      carrierFrequencyHz: carrierToSend,
      carrierMaxHz: carrierMaxHz,
      tauMicros: tauMicros,
    );
    return HeartbeatWaveformOutput(
      carrierToSend: carrierToSend,
      tauDerating: tauDerating,
      amplitudeToSend: amplitudeAmps * startupRamp * tauDerating,
    );
  }

  static double _carrierTauDerating({
    required double carrierFrequencyHz,
    required double carrierMaxHz,
    required double tauMicros,
  }) {
    final double tauSec = tauMicros.clamp(0.0, 1000.0) * 1e-6;
    if (tauSec <= 0.0) {
      return 1.0;
    }
    final double maxCarrierHz = carrierMaxHz.clamp(1.0, 2000.0);
    final double numerator = carrierFrequencyHz * tauSec + 0.5;
    final double denominator = maxCarrierHz * tauSec + 0.5;
    if (denominator <= 0.0) {
      return 1.0;
    }
    return (numerator / denominator).clamp(0.0, 1.0);
  }
}