import 'package:breadbeats_mobile/audio/motion/four_phase_electrode_mapper.dart';
import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/providers/calibration_pattern_tick_mapper.dart';
import 'package:breadbeats_mobile/providers/heartbeat_axis_command_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatAxisCommandMapper mapper = HeartbeatAxisCommandMapper();

  test('maps base plus three-phase calibration axes', () {
    final List<HeartbeatAxisCommand> commands = mapper
        .mapBaseAndCalibrationAxes(
          amplitudeToSend: 0.7,
          carrierToSend: 555.0,
          effectivePulseHz: 14.0,
          pulseWidthCycles: 12.0,
          pulseRiseTimeCycles: 4.0,
          normalizedPulseIntervalRandom: 0.21,
          outputMode: OutputModeSelection.threePhase,
          cal3Neutral: -1.0,
          cal3Right: 0.25,
          cal3Center: -0.75,
          cal4A: -0.1,
          cal4B: -0.2,
          cal4C: -0.3,
          cal4D: -0.4,
        );

    expect(commands.length, 9);
    expect(commands[0].axis, enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS);
    expect(commands[0].value, closeTo(0.7, 1e-12));
    expect(commands[5].axis, enums.AxisType.AXIS_PULSE_INTERVAL_RANDOM_PERCENT);
    expect(commands[5].value, closeTo(0.21, 1e-12));
    expect(commands[6].axis, enums.AxisType.AXIS_CALIBRATION_3_UP);
    expect(commands[6].value, closeTo(-1.0, 1e-12));
    expect(commands[7].axis, enums.AxisType.AXIS_CALIBRATION_3_LEFT);
    expect(commands[7].value, closeTo(0.25, 1e-12));
    expect(commands[8].axis, enums.AxisType.AXIS_CALIBRATION_3_CENTER);
    expect(commands[8].value, closeTo(-0.75, 1e-12));
  });

  test('maps base plus four-phase calibration axes', () {
    final List<HeartbeatAxisCommand> commands = mapper
        .mapBaseAndCalibrationAxes(
          amplitudeToSend: 0.4,
          carrierToSend: 640.0,
          effectivePulseHz: 10.0,
          pulseWidthCycles: 9.0,
          pulseRiseTimeCycles: 3.0,
          normalizedPulseIntervalRandom: 0.0,
          outputMode: OutputModeSelection.fourPhase,
          cal3Neutral: 0.0,
          cal3Right: 0.0,
          cal3Center: 0.0,
          cal4A: 1.0,
          cal4B: 2.0,
          cal4C: 3.0,
          cal4D: 4.0,
        );

    expect(commands.length, 10);
    expect(commands[6].axis, enums.AxisType.AXIS_CALIBRATION_4_A);
    expect(commands[6].value, closeTo(1.0, 1e-12));
    expect(commands[7].axis, enums.AxisType.AXIS_CALIBRATION_4_B);
    expect(commands[7].value, closeTo(2.0, 1e-12));
    expect(commands[8].axis, enums.AxisType.AXIS_CALIBRATION_4_C);
    expect(commands[8].value, closeTo(3.0, 1e-12));
    expect(commands[9].axis, enums.AxisType.AXIS_CALIBRATION_4_D);
    expect(commands[9].value, closeTo(4.0, 1e-12));
  });

  test('maps calibration pattern outputs for both output modes', () {
    final List<HeartbeatAxisCommand> fourPhaseCommands = mapper
        .mapCalibrationPatternAxes(
          const CalibrationPatternTickOutput.fourPhase(
            e1: 0.1,
            e2: 0.2,
            e3: 0.3,
            e4: 0.4,
          ),
        );
    expect(
      fourPhaseCommands.map((HeartbeatAxisCommand command) => command.axis),
      [
        enums.AxisType.AXIS_ELECTRODE_1_POWER,
        enums.AxisType.AXIS_ELECTRODE_2_POWER,
        enums.AxisType.AXIS_ELECTRODE_3_POWER,
        enums.AxisType.AXIS_ELECTRODE_4_POWER,
      ],
    );

    final List<HeartbeatAxisCommand> threePhaseCommands = mapper
        .mapCalibrationPatternAxes(
          const CalibrationPatternTickOutput.threePhase(alpha: -0.6, beta: 0.7),
        );
    expect(threePhaseCommands.length, 2);
    expect(threePhaseCommands[0].axis, enums.AxisType.AXIS_POSITION_ALPHA);
    expect(threePhaseCommands[0].value, closeTo(-0.6, 1e-12));
    expect(threePhaseCommands[1].axis, enums.AxisType.AXIS_POSITION_BETA);
    expect(threePhaseCommands[1].value, closeTo(0.7, 1e-12));
  });

  test('maps four-phase output axes with optional pulse random axis', () {
    final List<HeartbeatAxisCommand> withPulseRandom = mapper
        .mapFourPhaseOutputAxes(
          const FourPhaseElectrodeOutput(
            e1: 0.11,
            e2: 0.22,
            e3: 0.33,
            e4: 0.44,
            pulseIntervalRandomNormalized: 0.5,
          ),
        );

    expect(withPulseRandom.length, 5);
    expect(
      withPulseRandom.first.axis,
      enums.AxisType.AXIS_PULSE_INTERVAL_RANDOM_PERCENT,
    );
    expect(withPulseRandom.first.value, closeTo(0.5, 1e-12));

    final List<HeartbeatAxisCommand> withoutPulseRandom = mapper
        .mapFourPhaseOutputAxes(
          const FourPhaseElectrodeOutput(
            e1: 0.11,
            e2: 0.22,
            e3: 0.33,
            e4: 0.44,
            pulseIntervalRandomNormalized: null,
          ),
        );

    expect(withoutPulseRandom.length, 4);
    expect(
      withoutPulseRandom.map((HeartbeatAxisCommand command) => command.axis),
      <enums.AxisType>[
        enums.AxisType.AXIS_ELECTRODE_1_POWER,
        enums.AxisType.AXIS_ELECTRODE_2_POWER,
        enums.AxisType.AXIS_ELECTRODE_3_POWER,
        enums.AxisType.AXIS_ELECTRODE_4_POWER,
      ],
    );
  });

  test('maps three-phase output axes', () {
    final List<HeartbeatAxisCommand> commands = mapper.mapThreePhaseOutputAxes(
      alpha: -0.2,
      beta: 0.6,
    );

    expect(commands.length, 2);
    expect(commands[0].axis, enums.AxisType.AXIS_POSITION_ALPHA);
    expect(commands[0].value, closeTo(-0.2, 1e-12));
    expect(commands[1].axis, enums.AxisType.AXIS_POSITION_BETA);
    expect(commands[1].value, closeTo(0.6, 1e-12));
  });
}
