import 'dart:math';

import '../generated/protobuf/constants.pbenum.dart' as enums;
import '../models/device_models.dart';

typedef AxisMoveFn =
    Future<void> Function(enums.AxisType axis, double value, int intervalMs);

class SessionStartPrimer {
  const SessionStartPrimer();

  double initialPulseFrequencyHz({
    required double pulseMinHz,
    required double pulseMaxHz,
  }) {
    final double minHz = pulseMinHz.clamp(5.0, 100.0);
    final double maxHz = pulseMaxHz.clamp(5.0, 100.0);
    final double safeMaxHz = max(minHz, maxHz);
    return ((minHz + safeMaxHz) * 0.5).clamp(minHz, safeMaxHz);
  }

  double normalizePulseIntervalRandomPercent(double percent) {
    return percent.clamp(0.0, 100.0) / 100.0;
  }

  Future<void> primeAxes({
    required AxisMoveFn moveAxis,
    required OutputModeSelection outputMode,
    required double initialCarrierHz,
    required double initialPulseHz,
    required double pulseWidthCycles,
    required double pulseRiseTimeCycles,
    required double normalizedPulseIntervalRandom,
    required double cal3Neutral,
    required double cal3Right,
    required double cal3Center,
    required double cal4A,
    required double cal4B,
    required double cal4C,
    required double cal4D,
  }) async {
    final List<Future<void>> setupOps = <Future<void>>[
      moveAxis(enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS, 0.0, 0),
      moveAxis(enums.AxisType.AXIS_CARRIER_FREQUENCY_HZ, initialCarrierHz, 0),
      moveAxis(enums.AxisType.AXIS_PULSE_FREQUENCY_HZ, initialPulseHz, 0),
      moveAxis(enums.AxisType.AXIS_PULSE_WIDTH_IN_CYCLES, pulseWidthCycles, 0),
      moveAxis(
        enums.AxisType.AXIS_PULSE_RISE_TIME_CYCLES,
        pulseRiseTimeCycles,
        0,
      ),
      moveAxis(
        enums.AxisType.AXIS_PULSE_INTERVAL_RANDOM_PERCENT,
        normalizedPulseIntervalRandom,
        0,
      ),
    ];

    if (outputMode == OutputModeSelection.fourPhase) {
      setupOps.addAll(<Future<void>>[
        moveAxis(enums.AxisType.AXIS_ELECTRODE_1_POWER, 0.0, 0),
        moveAxis(enums.AxisType.AXIS_ELECTRODE_2_POWER, 0.0, 0),
        moveAxis(enums.AxisType.AXIS_ELECTRODE_3_POWER, 0.0, 0),
        moveAxis(enums.AxisType.AXIS_ELECTRODE_4_POWER, 0.0, 0),
        moveAxis(enums.AxisType.AXIS_CALIBRATION_4_A, cal4A, 0),
        moveAxis(enums.AxisType.AXIS_CALIBRATION_4_B, cal4B, 0),
        moveAxis(enums.AxisType.AXIS_CALIBRATION_4_C, cal4C, 0),
        moveAxis(enums.AxisType.AXIS_CALIBRATION_4_D, cal4D, 0),
      ]);
    } else {
      setupOps.addAll(<Future<void>>[
        moveAxis(enums.AxisType.AXIS_POSITION_ALPHA, 0.0, 0),
        moveAxis(enums.AxisType.AXIS_POSITION_BETA, 0.0, 0),
        moveAxis(enums.AxisType.AXIS_CALIBRATION_3_UP, cal3Neutral, 0),
        moveAxis(enums.AxisType.AXIS_CALIBRATION_3_LEFT, cal3Right, 0),
        moveAxis(enums.AxisType.AXIS_CALIBRATION_3_CENTER, cal3Center, 0),
      ]);
    }

    await Future.wait(setupOps);
  }
}
