import 'package:breadbeats_mobile/audio/motion/four_phase_electrode_mapper.dart';
import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/providers/heartbeat_mode_axis_apply_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const HeartbeatModeAxisApplyController controller =
      HeartbeatModeAxisApplyController();

  test(
    'applyFourPhase queues mapped commands and updates electrode levels',
    () async {
      final List<Future<void>> operations = <Future<void>>[];
      final List<enums.AxisType> sentAxes = <enums.AxisType>[];
      final List<double> sentValues = <double>[];
      double? observedE1;
      double? observedE2;
      double? observedE3;
      double? observedE4;

      controller.applyFourPhase(
        fourPhaseOutput: const FourPhaseElectrodeOutput(
          e1: 0.11,
          e2: 0.22,
          e3: 0.33,
          e4: 0.44,
          pulseIntervalRandomNormalized: 0.17,
        ),
        operations: operations,
        forceSync: false,
        shouldSendAxis:
            ({
              required int axisKey,
              required double value,
              required bool forceSync,
            }) => axisKey != enums.AxisType.AXIS_ELECTRODE_3_POWER.value,
        moveAxis: (enums.AxisType axis, double value, int intervalMs) {
          sentAxes.add(axis);
          sentValues.add(value);
          expect(intervalMs, 33);
          return Future<void>.value();
        },
        updateFourPhaseElectrodeLevels:
            ({
              required double e1,
              required double e2,
              required double e3,
              required double e4,
            }) {
              observedE1 = e1;
              observedE2 = e2;
              observedE3 = e3;
              observedE4 = e4;
            },
      );

      expect(operations.length, 4);
      await Future.wait(operations);
      expect(sentAxes, <enums.AxisType>[
        enums.AxisType.AXIS_PULSE_INTERVAL_RANDOM_PERCENT,
        enums.AxisType.AXIS_ELECTRODE_1_POWER,
        enums.AxisType.AXIS_ELECTRODE_2_POWER,
        enums.AxisType.AXIS_ELECTRODE_4_POWER,
      ]);
      expect(sentValues, <double>[0.17, 0.11, 0.22, 0.44]);
      expect(observedE1, closeTo(0.11, 1e-12));
      expect(observedE2, closeTo(0.22, 1e-12));
      expect(observedE3, closeTo(0.33, 1e-12));
      expect(observedE4, closeTo(0.44, 1e-12));
    },
  );

  test('applyFourPhase omits pulse random axis when not present', () async {
    final List<Future<void>> operations = <Future<void>>[];
    final List<enums.AxisType> sentAxes = <enums.AxisType>[];

    controller.applyFourPhase(
      fourPhaseOutput: const FourPhaseElectrodeOutput(
        e1: 0.4,
        e2: 0.3,
        e3: 0.2,
        e4: 0.1,
        pulseIntervalRandomNormalized: null,
      ),
      operations: operations,
      forceSync: true,
      shouldSendAxis:
          ({
            required int axisKey,
            required double value,
            required bool forceSync,
          }) => true,
      moveAxis: (enums.AxisType axis, double value, int intervalMs) {
        sentAxes.add(axis);
        return Future<void>.value();
      },
      updateFourPhaseElectrodeLevels:
          ({
            required double e1,
            required double e2,
            required double e3,
            required double e4,
          }) {},
    );

    await Future.wait(operations);
    expect(sentAxes, <enums.AxisType>[
      enums.AxisType.AXIS_ELECTRODE_1_POWER,
      enums.AxisType.AXIS_ELECTRODE_2_POWER,
      enums.AxisType.AXIS_ELECTRODE_3_POWER,
      enums.AxisType.AXIS_ELECTRODE_4_POWER,
    ]);
  });

  test(
    'applyThreePhase queues mapped commands and applies output scale',
    () async {
      final List<Future<void>> operations = <Future<void>>[];
      final List<enums.AxisType> sentAxes = <enums.AxisType>[];
      double? observedAlpha;
      double? observedBeta;
      double? observedOutputScale;

      controller.applyThreePhase(
        alpha: -0.6,
        beta: 0.9,
        outputDrive: 0.73,
        operations: operations,
        forceSync: false,
        shouldSendAxis:
            ({
              required int axisKey,
              required double value,
              required bool forceSync,
            }) => axisKey != enums.AxisType.AXIS_POSITION_BETA.value,
        moveAxis: (enums.AxisType axis, double value, int intervalMs) {
          sentAxes.add(axis);
          return Future<void>.value();
        },
        updateThreePhaseElectrodeLevels:
            ({
              required double alpha,
              required double beta,
              required double outputScale,
            }) {
              observedAlpha = alpha;
              observedBeta = beta;
              observedOutputScale = outputScale;
            },
      );

      await Future.wait(operations);
      expect(sentAxes, <enums.AxisType>[enums.AxisType.AXIS_POSITION_ALPHA]);
      expect(observedAlpha, closeTo(-0.6, 1e-12));
      expect(observedBeta, closeTo(0.9, 1e-12));
      expect(observedOutputScale, closeTo(0.73, 1e-12));
    },
  );
}
