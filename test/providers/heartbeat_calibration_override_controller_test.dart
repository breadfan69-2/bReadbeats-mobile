import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/calibration_controller.dart';
import 'package:breadbeats_mobile/providers/calibration_pattern_tick_mapper.dart';
import 'package:breadbeats_mobile/providers/heartbeat_axis_command_mapper.dart';
import 'package:breadbeats_mobile/providers/heartbeat_calibration_override_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'handleIfActive returns false when calibration pattern is none',
    () async {
      final _FakeCalibrationPatternTickMapper tickMapper =
          _FakeCalibrationPatternTickMapper(
            const CalibrationPatternTickOutput.threePhase(
              alpha: 0.1,
              beta: 0.2,
            ),
          );

      final HeartbeatCalibrationOverrideController controller =
          HeartbeatCalibrationOverrideController(
            calibrationPatternTickMapper: tickMapper,
          );

      bool fourPhaseUpdated = false;
      bool threePhaseUpdated = false;
      bool recorded = false;
      bool markedSync = false;

      final bool handled = await controller.handleIfActive(
        calibrationPattern: CalibrationPattern.none,
        calibrationController: CalibrationController(),
        manualAlpha: 0.0,
        manualBeta: 0.0,
        manualE1: 0.333,
        manualE2: 0.333,
        manualE3: 0.333,
        manualE4: 0.0,
        outputMode: OutputModeSelection.threePhase,
        dtSec: 1 / 60,
        operations: <Future<void>>[],
        forceSync: true,
        shouldSendAxis:
            ({
              required int axisKey,
              required double value,
              required bool forceSync,
            }) => true,
        moveAxis: (enums.AxisType axis, double value, int intervalMs) =>
            Future<void>.value(),
        nowSec: 12.0,
        markFullSync: (_) {
          markedSync = true;
        },
        updateFourPhaseElectrodeLevels:
            ({
              required double e1,
              required double e2,
              required double e3,
              required double e4,
            }) {
              fourPhaseUpdated = true;
            },
        updateThreePhaseElectrodeLevels:
            ({
              required double alpha,
              required double beta,
              required double outputScale,
            }) {
              threePhaseUpdated = true;
            },
        recordCalibrationOutput:
            ({required double amplitudeToSend, required int nowMs}) {
              recorded = true;
            },
        amplitudeToSend: 0.6,
        nowMs: 1234,
      );

      expect(handled, isFalse);
      expect(tickMapper.callCount, 0);
      expect(fourPhaseUpdated, isFalse);
      expect(threePhaseUpdated, isFalse);
      expect(recorded, isFalse);
      expect(markedSync, isFalse);
    },
  );

  test('handleIfActive processes four-phase calibration path', () async {
    final _FakeCalibrationPatternTickMapper tickMapper =
        _FakeCalibrationPatternTickMapper(
          const CalibrationPatternTickOutput.fourPhase(
            e1: 0.11,
            e2: 0.22,
            e3: 0.33,
            e4: 0.44,
          ),
        );
    final _FakeHeartbeatAxisCommandMapper axisCommandMapper =
        _FakeHeartbeatAxisCommandMapper(const <HeartbeatAxisCommand>[
          HeartbeatAxisCommand(
            axis: enums.AxisType.AXIS_ELECTRODE_1_POWER,
            value: 0.11,
          ),
          HeartbeatAxisCommand(
            axis: enums.AxisType.AXIS_ELECTRODE_2_POWER,
            value: 0.22,
          ),
        ]);

    final HeartbeatCalibrationOverrideController controller =
        HeartbeatCalibrationOverrideController(
          calibrationPatternTickMapper: tickMapper,
          heartbeatAxisCommandMapper: axisCommandMapper,
        );

    final List<enums.AxisType> sentAxes = <enums.AxisType>[];
    final List<double> sentValues = <double>[];
    double? observedNowSec;
    double? observedE1;
    double? observedE2;
    double? observedE3;
    double? observedE4;
    bool threePhaseUpdated = false;
    double? recordedAmplitude;
    int? recordedNowMs;

    final bool handled = await controller.handleIfActive(
      calibrationPattern: CalibrationPattern.circle,
      calibrationController: CalibrationController(),
      manualAlpha: 0.0,
      manualBeta: 0.0,
      manualE1: 0.333,
      manualE2: 0.333,
      manualE3: 0.333,
      manualE4: 0.0,
      outputMode: OutputModeSelection.fourPhase,
      dtSec: 1 / 60,
      operations: <Future<void>>[],
      forceSync: true,
      shouldSendAxis:
          ({
            required int axisKey,
            required double value,
            required bool forceSync,
          }) => true,
      moveAxis: (enums.AxisType axis, double value, int intervalMs) {
        sentAxes.add(axis);
        sentValues.add(value);
        expect(intervalMs, 33);
        return Future<void>.value();
      },
      nowSec: 42.5,
      markFullSync: (double nowSec) {
        observedNowSec = nowSec;
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
      updateThreePhaseElectrodeLevels:
          ({
            required double alpha,
            required double beta,
            required double outputScale,
          }) {
            threePhaseUpdated = true;
          },
      recordCalibrationOutput:
          ({required double amplitudeToSend, required int nowMs}) {
            recordedAmplitude = amplitudeToSend;
            recordedNowMs = nowMs;
          },
      amplitudeToSend: 0.75,
      nowMs: 9900,
    );

    expect(handled, isTrue);
    expect(tickMapper.callCount, 1);
    expect(axisCommandMapper.callCount, 1);
    expect(
      axisCommandMapper.lastOutput,
      isA<CalibrationPatternTickOutput>().having(
        (CalibrationPatternTickOutput output) => output.isFourPhase,
        'isFourPhase',
        isTrue,
      ),
    );
    expect(sentAxes, <enums.AxisType>[
      enums.AxisType.AXIS_ELECTRODE_1_POWER,
      enums.AxisType.AXIS_ELECTRODE_2_POWER,
    ]);
    expect(sentValues, <double>[0.11, 0.22]);
    expect(observedNowSec, closeTo(42.5, 1e-12));
    expect(observedE1, closeTo(0.11, 1e-12));
    expect(observedE2, closeTo(0.22, 1e-12));
    expect(observedE3, closeTo(0.33, 1e-12));
    expect(observedE4, closeTo(0.44, 1e-12));
    expect(threePhaseUpdated, isFalse);
    expect(recordedAmplitude, closeTo(0.75, 1e-12));
    expect(recordedNowMs, 9900);
  });

  test('handleIfActive processes three-phase calibration path', () async {
    final _FakeCalibrationPatternTickMapper tickMapper =
        _FakeCalibrationPatternTickMapper(
          const CalibrationPatternTickOutput.threePhase(alpha: -0.5, beta: 0.8),
        );
    final _FakeHeartbeatAxisCommandMapper axisCommandMapper =
        _FakeHeartbeatAxisCommandMapper(const <HeartbeatAxisCommand>[
          HeartbeatAxisCommand(
            axis: enums.AxisType.AXIS_POSITION_ALPHA,
            value: -0.5,
          ),
          HeartbeatAxisCommand(
            axis: enums.AxisType.AXIS_POSITION_BETA,
            value: 0.8,
          ),
        ]);

    final HeartbeatCalibrationOverrideController controller =
        HeartbeatCalibrationOverrideController(
          calibrationPatternTickMapper: tickMapper,
          heartbeatAxisCommandMapper: axisCommandMapper,
        );

    int markCallCount = 0;
    bool fourPhaseUpdated = false;
    double? observedAlpha;
    double? observedBeta;
    double? observedScale;
    final List<enums.AxisType> sentAxes = <enums.AxisType>[];

    final bool handled = await controller.handleIfActive(
      calibrationPattern: CalibrationPattern.sequential1234,
      calibrationController: CalibrationController(),
      manualAlpha: 0.0,
      manualBeta: 0.0,
      manualE1: 0.333,
      manualE2: 0.333,
      manualE3: 0.333,
      manualE4: 0.0,
      outputMode: OutputModeSelection.threePhase,
      dtSec: 1 / 120,
      operations: <Future<void>>[],
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
      nowSec: 8.0,
      markFullSync: (_) {
        markCallCount++;
      },
      updateFourPhaseElectrodeLevels:
          ({
            required double e1,
            required double e2,
            required double e3,
            required double e4,
          }) {
            fourPhaseUpdated = true;
          },
      updateThreePhaseElectrodeLevels:
          ({
            required double alpha,
            required double beta,
            required double outputScale,
          }) {
            observedAlpha = alpha;
            observedBeta = beta;
            observedScale = outputScale;
          },
      recordCalibrationOutput:
          ({required double amplitudeToSend, required int nowMs}) {},
      amplitudeToSend: 0.31,
      nowMs: 700,
    );

    expect(handled, isTrue);
    expect(tickMapper.callCount, 1);
    expect(axisCommandMapper.callCount, 1);
    expect(sentAxes, <enums.AxisType>[enums.AxisType.AXIS_POSITION_ALPHA]);
    expect(markCallCount, 0);
    expect(fourPhaseUpdated, isFalse);
    expect(observedAlpha, closeTo(-0.5, 1e-12));
    expect(observedBeta, closeTo(0.8, 1e-12));
    expect(observedScale, closeTo(1.0, 1e-12));
  });
}

class _FakeCalibrationPatternTickMapper extends CalibrationPatternTickMapper {
  _FakeCalibrationPatternTickMapper(this.output);

  final CalibrationPatternTickOutput output;
  int callCount = 0;

  @override
  CalibrationPatternTickOutput map({
    required CalibrationPattern pattern,
    required CalibrationController controller,
    required OutputModeSelection outputMode,
    required double dtSec,
    double? manualAlpha,
    double? manualBeta,
    double? manualE1,
    double? manualE2,
    double? manualE3,
    double? manualE4,
  }) {
    callCount++;
    return output;
  }
}

class _FakeHeartbeatAxisCommandMapper extends HeartbeatAxisCommandMapper {
  _FakeHeartbeatAxisCommandMapper(this.commands);

  final List<HeartbeatAxisCommand> commands;
  int callCount = 0;
  CalibrationPatternTickOutput? lastOutput;

  @override
  List<HeartbeatAxisCommand> mapCalibrationPatternAxes(
    CalibrationPatternTickOutput calibrationOutput,
  ) {
    callCount++;
    lastOutput = calibrationOutput;
    return commands;
  }
}
