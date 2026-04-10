import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/calibration_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_axis_command_mapper.dart';
import 'package:breadbeats_mobile/providers/heartbeat_axis_dispatch_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_base_and_calibration_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_calibration_override_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'queueBaseAndHandleCalibrationOverride queues base commands and returns false when override inactive',
    () async {
      final _FakeHeartbeatAxisCommandMapper axisCommandMapper =
          _FakeHeartbeatAxisCommandMapper(const <HeartbeatAxisCommand>[
            HeartbeatAxisCommand(
              axis: enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS,
              value: 0.6,
            ),
            HeartbeatAxisCommand(
              axis: enums.AxisType.AXIS_CARRIER_FREQUENCY_HZ,
              value: 550.0,
            ),
            HeartbeatAxisCommand(
              axis: enums.AxisType.AXIS_PULSE_FREQUENCY_HZ,
              value: 18.0,
            ),
          ]);
      final _FakeHeartbeatCalibrationOverrideController
      calibrationOverrideController =
          _FakeHeartbeatCalibrationOverrideController(result: false);

      final HeartbeatBaseAndCalibrationController controller =
          HeartbeatBaseAndCalibrationController(
            heartbeatAxisCommandMapper: axisCommandMapper,
            heartbeatCalibrationOverrideController:
                calibrationOverrideController,
          );

      final List<Future<void>> operations = <Future<void>>[];
      final List<enums.AxisType> sentAxes = <enums.AxisType>[];

      final bool handled = await controller
          .queueBaseAndHandleCalibrationOverride(
            amplitudeToSend: 0.6,
            carrierToSend: 550.0,
            effectivePulseHz: 18.0,
            pulseWidthCycles: 12.0,
            pulseRiseTimeCycles: 4.0,
            normalizedPulseIntervalRandom: 0.2,
            outputMode: OutputModeSelection.threePhase,
            cal3Neutral: -1.0,
            cal3Right: 0.2,
            cal3Center: -0.4,
            cal4A: 0.1,
            cal4B: 0.2,
            cal4C: 0.3,
            cal4D: 0.4,
            operations: operations,
            forceSync: true,
            shouldSendAxis:
                ({
                  required int axisKey,
                  required double value,
                  required bool forceSync,
                }) => axisKey != enums.AxisType.AXIS_CARRIER_FREQUENCY_HZ.value,
            moveAxis: (enums.AxisType axis, double value, int intervalMs) {
              sentAxes.add(axis);
              return Future<void>.value();
            },
            calibrationPattern: CalibrationPattern.none,
            calibrationController: CalibrationController(),
            manualAlpha: 0.0,
            manualBeta: 0.0,
            manualE1: 0.333,
            manualE2: 0.333,
            manualE3: 0.333,
            manualE4: 0.0,
            dtSec: 1 / 60,
            nowSec: 11.25,
            markFullSync: (_) {},
            updateFourPhaseElectrodeLevels:
                ({
                  required double e1,
                  required double e2,
                  required double e3,
                  required double e4,
                }) {},
            updateThreePhaseElectrodeLevels:
                ({
                  required double alpha,
                  required double beta,
                  required double outputScale,
                }) {},
            recordCalibrationOutput:
                ({required double amplitudeToSend, required int nowMs}) {},
            nowMs: 4321,
          );

      await Future.wait(operations);

      expect(handled, isFalse);
      expect(axisCommandMapper.callCount, 1);
      expect(axisCommandMapper.lastOutputMode, OutputModeSelection.threePhase);
      expect(calibrationOverrideController.callCount, 1);
      expect(
        calibrationOverrideController.lastCalibrationPattern,
        CalibrationPattern.none,
      );
      expect(sentAxes, <enums.AxisType>[
        enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS,
        enums.AxisType.AXIS_PULSE_FREQUENCY_HZ,
      ]);
    },
  );

  test(
    'queueBaseAndHandleCalibrationOverride returns true when override handled and forwards context',
    () async {
      final _FakeHeartbeatAxisCommandMapper axisCommandMapper =
          _FakeHeartbeatAxisCommandMapper(const <HeartbeatAxisCommand>[
            HeartbeatAxisCommand(
              axis: enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS,
              value: 0.7,
            ),
          ]);
      final _FakeHeartbeatCalibrationOverrideController
      calibrationOverrideController =
          _FakeHeartbeatCalibrationOverrideController(result: true);

      final HeartbeatBaseAndCalibrationController controller =
          HeartbeatBaseAndCalibrationController(
            heartbeatAxisCommandMapper: axisCommandMapper,
            heartbeatCalibrationOverrideController:
                calibrationOverrideController,
          );

      final bool handled = await controller
          .queueBaseAndHandleCalibrationOverride(
            amplitudeToSend: 0.7,
            carrierToSend: 480.0,
            effectivePulseHz: 10.0,
            pulseWidthCycles: 8.0,
            pulseRiseTimeCycles: 3.0,
            normalizedPulseIntervalRandom: 0.05,
            outputMode: OutputModeSelection.fourPhase,
            cal3Neutral: 0.0,
            cal3Right: 0.0,
            cal3Center: 0.0,
            cal4A: 0.9,
            cal4B: 0.8,
            cal4C: 0.7,
            cal4D: 0.6,
            operations: <Future<void>>[],
            forceSync: false,
            shouldSendAxis:
                ({
                  required int axisKey,
                  required double value,
                  required bool forceSync,
                }) => true,
            moveAxis: (enums.AxisType axis, double value, int intervalMs) =>
                Future<void>.value(),
            calibrationPattern: CalibrationPattern.circle,
            calibrationController: CalibrationController(),
            manualAlpha: 0.0,
            manualBeta: 0.0,
            manualE1: 0.333,
            manualE2: 0.333,
            manualE3: 0.333,
            manualE4: 0.0,
            dtSec: 1 / 120,
            nowSec: 22.5,
            markFullSync: (_) {},
            updateFourPhaseElectrodeLevels:
                ({
                  required double e1,
                  required double e2,
                  required double e3,
                  required double e4,
                }) {},
            updateThreePhaseElectrodeLevels:
                ({
                  required double alpha,
                  required double beta,
                  required double outputScale,
                }) {},
            recordCalibrationOutput:
                ({required double amplitudeToSend, required int nowMs}) {},
            nowMs: 9876,
          );

      expect(handled, isTrue);
      expect(axisCommandMapper.callCount, 1);
      expect(axisCommandMapper.lastOutputMode, OutputModeSelection.fourPhase);
      expect(calibrationOverrideController.callCount, 1);
      expect(
        calibrationOverrideController.lastCalibrationPattern,
        CalibrationPattern.circle,
      );
      expect(
        calibrationOverrideController.lastOutputMode,
        OutputModeSelection.fourPhase,
      );
      expect(calibrationOverrideController.lastDtSec, closeTo(1 / 120, 1e-12));
      expect(calibrationOverrideController.lastNowSec, closeTo(22.5, 1e-12));
      expect(
        calibrationOverrideController.lastAmplitudeToSend,
        closeTo(0.7, 1e-12),
      );
      expect(calibrationOverrideController.lastNowMs, 9876);
    },
  );
}

class _FakeHeartbeatAxisCommandMapper extends HeartbeatAxisCommandMapper {
  _FakeHeartbeatAxisCommandMapper(this.commands);

  final List<HeartbeatAxisCommand> commands;
  int callCount = 0;
  OutputModeSelection? lastOutputMode;

  @override
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
    callCount++;
    lastOutputMode = outputMode;
    return commands;
  }
}

class _FakeHeartbeatCalibrationOverrideController
    extends HeartbeatCalibrationOverrideController {
  _FakeHeartbeatCalibrationOverrideController({required this.result});

  final bool result;
  int callCount = 0;
  CalibrationPattern? lastCalibrationPattern;
  OutputModeSelection? lastOutputMode;
  double? lastDtSec;
  double? lastNowSec;
  double? lastAmplitudeToSend;
  int? lastNowMs;

  @override
  Future<bool> handleIfActive({
    required CalibrationPattern calibrationPattern,
    required CalibrationController calibrationController,
    required double manualAlpha,
    required double manualBeta,
    required double manualE1,
    required double manualE2,
    required double manualE3,
    required double manualE4,
    required OutputModeSelection outputMode,
    required double dtSec,
    required List<Future<void>> operations,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    required double nowSec,
    required void Function(double nowSec) markFullSync,
    required FourPhaseCalibrationLevelUpdater updateFourPhaseElectrodeLevels,
    required ThreePhaseCalibrationLevelUpdater updateThreePhaseElectrodeLevels,
    required CalibrationOutputRecorder recordCalibrationOutput,
    required double amplitudeToSend,
    required int nowMs,
  }) async {
    callCount++;
    lastCalibrationPattern = calibrationPattern;
    lastOutputMode = outputMode;
    lastDtSec = dtSec;
    lastNowSec = nowSec;
    lastAmplitudeToSend = amplitudeToSend;
    lastNowMs = nowMs;
    return result;
  }
}
