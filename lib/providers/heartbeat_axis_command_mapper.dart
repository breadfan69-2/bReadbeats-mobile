import '../audio/motion/four_phase_electrode_mapper.dart';
import '../generated/protobuf/constants.pbenum.dart' as enums;
import '../models/device_models.dart';
import 'calibration_pattern_tick_mapper.dart';

class HeartbeatAxisCommand {
  const HeartbeatAxisCommand({required this.axis, required this.value});

  final enums.AxisType axis;
  final double value;
}

class HeartbeatAxisCommandMapper {
  const HeartbeatAxisCommandMapper();

  List<HeartbeatAxisCommand> mapBaseAndCalibrationAxes({
    required double amplitudeToSend,
    required double carrierToSend,
    required double effectivePulseHz,
    required double pulseWidthCycles,
    required double pulseRiseTimeCycles,
    required double normalizedPulseIntervalRandom,
    required OutputModeSelection outputMode,
    required double cal3Neutral,
    required double cal3Right,
    required double cal3Center,
    required double cal4A,
    required double cal4B,
    required double cal4C,
    required double cal4D,
  }) {
    final List<HeartbeatAxisCommand> commands = <HeartbeatAxisCommand>[
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS,
        value: amplitudeToSend,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_CARRIER_FREQUENCY_HZ,
        value: carrierToSend,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_PULSE_FREQUENCY_HZ,
        value: effectivePulseHz,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_PULSE_WIDTH_IN_CYCLES,
        value: pulseWidthCycles,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_PULSE_RISE_TIME_CYCLES,
        value: pulseRiseTimeCycles,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_PULSE_INTERVAL_RANDOM_PERCENT,
        value: normalizedPulseIntervalRandom,
      ),
    ];

    if (outputMode == OutputModeSelection.fourPhase) {
      commands.addAll(<HeartbeatAxisCommand>[
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_CALIBRATION_4_A,
          value: cal4A,
        ),
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_CALIBRATION_4_B,
          value: cal4B,
        ),
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_CALIBRATION_4_C,
          value: cal4C,
        ),
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_CALIBRATION_4_D,
          value: cal4D,
        ),
      ]);
    } else {
      commands.addAll(<HeartbeatAxisCommand>[
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_CALIBRATION_3_UP,
          value: cal3Neutral,
        ),
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_CALIBRATION_3_LEFT,
          value: cal3Right,
        ),
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_CALIBRATION_3_CENTER,
          value: cal3Center,
        ),
      ]);
    }

    return commands;
  }

  List<HeartbeatAxisCommand> mapCalibrationPatternAxes(
    CalibrationPatternTickOutput calibrationOutput,
  ) {
    if (calibrationOutput.isFourPhase) {
      return <HeartbeatAxisCommand>[
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_ELECTRODE_1_POWER,
          value: calibrationOutput.e1!,
        ),
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_ELECTRODE_2_POWER,
          value: calibrationOutput.e2!,
        ),
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_ELECTRODE_3_POWER,
          value: calibrationOutput.e3!,
        ),
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_ELECTRODE_4_POWER,
          value: calibrationOutput.e4!,
        ),
      ];
    }

    return <HeartbeatAxisCommand>[
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_POSITION_ALPHA,
        value: calibrationOutput.alpha!,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_POSITION_BETA,
        value: calibrationOutput.beta!,
      ),
    ];
  }

  List<HeartbeatAxisCommand> mapFourPhaseOutputAxes(
    FourPhaseElectrodeOutput output,
  ) {
    final List<HeartbeatAxisCommand> commands = <HeartbeatAxisCommand>[];
    final double? pulseRandom = output.pulseIntervalRandomNormalized;
    if (pulseRandom != null) {
      commands.add(
        HeartbeatAxisCommand(
          axis: enums.AxisType.AXIS_PULSE_INTERVAL_RANDOM_PERCENT,
          value: pulseRandom,
        ),
      );
    }

    commands.addAll(<HeartbeatAxisCommand>[
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_ELECTRODE_1_POWER,
        value: output.e1,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_ELECTRODE_2_POWER,
        value: output.e2,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_ELECTRODE_3_POWER,
        value: output.e3,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_ELECTRODE_4_POWER,
        value: output.e4,
      ),
    ]);

    return commands;
  }

  List<HeartbeatAxisCommand> mapThreePhaseOutputAxes({
    required double alpha,
    required double beta,
  }) {
    return <HeartbeatAxisCommand>[
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_POSITION_ALPHA,
        value: alpha,
      ),
      HeartbeatAxisCommand(
        axis: enums.AxisType.AXIS_POSITION_BETA,
        value: beta,
      ),
    ];
  }
}
