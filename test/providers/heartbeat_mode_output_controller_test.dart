import 'package:breadbeats_mobile/audio/motion/beat_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/four_phase_electrode_mapper.dart';
import 'package:breadbeats_mobile/audio/motion/onset_motion_engine.dart';
import 'package:breadbeats_mobile/audio/motion/three_phase_position_mapper.dart';
import 'package:breadbeats_mobile/audio/processing/audio_signal_processor.dart';
import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/heartbeat_axis_dispatch_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_mode_axis_apply_controller.dart';
import 'package:breadbeats_mobile/providers/heartbeat_mode_output_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'apply routes four-phase mode through four-phase mapper and applier',
    () {
      final _FakeFourPhaseElectrodeMapper fourPhaseMapper =
          _FakeFourPhaseElectrodeMapper(
            const FourPhaseElectrodeOutput(
              e1: 0.11,
              e2: 0.22,
              e3: 0.33,
              e4: 0.44,
              pulseIntervalRandomNormalized: 0.15,
            ),
          );
      final _FakeThreePhasePositionMapper threePhaseMapper =
          _FakeThreePhasePositionMapper(alpha: -0.6, beta: 0.8);
      final _FakeHeartbeatModeAxisApplyController modeAxisApplyController =
          _FakeHeartbeatModeAxisApplyController();

      final HeartbeatModeOutputController controller =
          HeartbeatModeOutputController(
            fourPhaseElectrodeMapper: fourPhaseMapper,
            threePhasePositionMapper: threePhaseMapper,
            heartbeatModeAxisApplyController: modeAxisApplyController,
          );

      const List<List<AudioBand>> expectedBandMapping = <List<AudioBand>>[
        <AudioBand>[AudioBand.bass],
        <AudioBand>[AudioBand.lowMid],
        <AudioBand>[AudioBand.mid],
        <AudioBand>[AudioBand.subBass],
      ];
      const List<BeatResponseCurve> expectedBeatCurves = <BeatResponseCurve>[
        BeatResponseCurve.linear,
        BeatResponseCurve.ease,
        BeatResponseCurve.bell,
        BeatResponseCurve.linear,
      ];

      final List<Future<void>> operations = <Future<void>>[];
      double? observedE1;
      double? observedE2;
      double? observedE3;
      double? observedE4;

      controller.apply(
        outputMode: OutputModeSelection.fourPhase,
        stimMode: StimMode.onset,
        beatMotion: BeatMotionEngine(),
        onsetMotion: OnsetMotionEngine(),
        features: AudioFeatures.zero,
        blendedAngle: 1.2,
        base: 0.35,
        silenceFade: 0.4,
        fillAngle: 2.4,
        pulseIntervalRandomPercent: 47.0,
        beatRadiusAwareContrastStrength: 0.45,
        beatSpeedThresholdSpreadStrength: 0.3,
        beatResponseCurves: expectedBeatCurves,
        bandMapping: expectedBandMapping,
        blendX: -0.1,
        blendY: 0.2,
        fillCenterY: 0.3,
        fillRadius: 0.4,
        fillHhImpulse: 0.5,
        outputDrive: 0.6,
        operations: operations,
        forceSync: true,
        shouldSendAxis:
            ({
              required int axisKey,
              required double value,
              required bool forceSync,
            }) => true,
        moveAxis: (enums.AxisType axis, double value, int intervalMs) =>
            Future<void>.value(),
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
            }) {},
      );

      expect(fourPhaseMapper.callCount, 1);
      expect(fourPhaseMapper.lastStimMode, StimMode.onset);
      expect(
        fourPhaseMapper.lastPulseIntervalRandomPercent,
        closeTo(47.0, 1e-12),
      );
      expect(fourPhaseMapper.lastBlendX, closeTo(-0.1, 1e-12));
      expect(fourPhaseMapper.lastBlendY, closeTo(0.2, 1e-12));
      expect(
        fourPhaseMapper.lastBeatRadiusAwareContrastStrength,
        closeTo(0.45, 1e-12),
      );
      expect(
        fourPhaseMapper.lastBeatSpeedThresholdSpreadStrength,
        closeTo(0.3, 1e-12),
      );
      expect(
        fourPhaseMapper.lastBeatResponseCurves,
        equals(expectedBeatCurves),
      );
      expect(fourPhaseMapper.lastBandMapping, equals(expectedBandMapping));
      expect(threePhaseMapper.callCount, 0);

      expect(modeAxisApplyController.fourPhaseCalls, 1);
      expect(modeAxisApplyController.threePhaseCalls, 0);
      expect(modeAxisApplyController.lastForceSync, isTrue);
      expect(
        modeAxisApplyController.lastFourPhaseOutput?.e1,
        closeTo(0.11, 1e-12),
      );

      expect(observedE1, closeTo(0.11, 1e-12));
      expect(observedE2, closeTo(0.22, 1e-12));
      expect(observedE3, closeTo(0.33, 1e-12));
      expect(observedE4, closeTo(0.44, 1e-12));
    },
  );

  test('apply routes three-phase mode through position mapper and applier', () {
    final _FakeFourPhaseElectrodeMapper fourPhaseMapper =
        _FakeFourPhaseElectrodeMapper(
          const FourPhaseElectrodeOutput(
            e1: 0.2,
            e2: 0.3,
            e3: 0.4,
            e4: 0.5,
            pulseIntervalRandomNormalized: null,
          ),
        );
    final _FakeThreePhasePositionMapper threePhaseMapper =
        _FakeThreePhasePositionMapper(alpha: -0.75, beta: 0.9);
    final _FakeHeartbeatModeAxisApplyController modeAxisApplyController =
        _FakeHeartbeatModeAxisApplyController();

    final HeartbeatModeOutputController controller =
        HeartbeatModeOutputController(
          fourPhaseElectrodeMapper: fourPhaseMapper,
          threePhasePositionMapper: threePhaseMapper,
          heartbeatModeAxisApplyController: modeAxisApplyController,
        );

    final List<Future<void>> operations = <Future<void>>[];
    double? observedAlpha;
    double? observedBeta;
    double? observedOutputScale;

    controller.apply(
      outputMode: OutputModeSelection.threePhase,
      stimMode: StimMode.beat,
      beatMotion: BeatMotionEngine(),
      onsetMotion: OnsetMotionEngine(),
      features: AudioFeatures.zero,
      blendedAngle: 0.9,
      base: 0.25,
      silenceFade: 0.15,
      fillAngle: 0.8,
      pulseIntervalRandomPercent: 22.0,
      beatRadiusAwareContrastStrength: 0.2,
      beatSpeedThresholdSpreadStrength: 0.1,
      beatResponseCurves: defaultBeatFourPhaseResponseCurves,
      bandMapping: defaultOnsetBandMapping,
      blendX: -0.45,
      blendY: 0.67,
      fillCenterY: 0.12,
      fillRadius: 0.89,
      fillHhImpulse: 0.91,
      outputDrive: 0.77,
      operations: operations,
      forceSync: false,
      shouldSendAxis:
          ({
            required int axisKey,
            required double value,
            required bool forceSync,
          }) => false,
      moveAxis: (enums.AxisType axis, double value, int intervalMs) =>
          Future<void>.value(),
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
          }) {
            observedAlpha = alpha;
            observedBeta = beta;
            observedOutputScale = outputScale;
          },
    );

    expect(fourPhaseMapper.callCount, 0);
    expect(threePhaseMapper.callCount, 1);
    expect(threePhaseMapper.lastStimMode, StimMode.beat);
    expect(threePhaseMapper.lastBlendX, closeTo(-0.45, 1e-12));

    expect(modeAxisApplyController.fourPhaseCalls, 0);
    expect(modeAxisApplyController.threePhaseCalls, 1);
    expect(modeAxisApplyController.lastOutputDrive, closeTo(0.77, 1e-12));

    expect(observedAlpha, closeTo(-0.75, 1e-12));
    expect(observedBeta, closeTo(0.9, 1e-12));
    expect(observedOutputScale, closeTo(0.77, 1e-12));
  });
}

class _FakeFourPhaseElectrodeMapper extends FourPhaseElectrodeMapper {
  _FakeFourPhaseElectrodeMapper(this.output);

  final FourPhaseElectrodeOutput output;
  int callCount = 0;
  StimMode? lastStimMode;
  double? lastPulseIntervalRandomPercent;
  double? lastBlendX;
  double? lastBlendY;
  double? lastBeatRadiusAwareContrastStrength;
  double? lastBeatSpeedThresholdSpreadStrength;
  List<BeatResponseCurve>? lastBeatResponseCurves;
  List<List<AudioBand>>? lastBandMapping;

  @override
  FourPhaseElectrodeOutput map({
    required StimMode stimMode,
    required BeatMotionEngine beatMotion,
    required AudioFeatures features,
    required double blendedAngle,
    required double blendX,
    required double blendY,
    required double base,
    required double silenceFade,
    required double fillAngle,
    required double pulseIntervalRandomPercent,
    required double beatRadiusAwareContrastStrength,
    required double beatSpeedThresholdSpreadStrength,
    required List<BeatResponseCurve> beatResponseCurves,
    List<List<AudioBand>> bandMapping = defaultOnsetBandMapping,
  }) {
    callCount++;
    lastStimMode = stimMode;
    lastPulseIntervalRandomPercent = pulseIntervalRandomPercent;
    lastBlendX = blendX;
    lastBlendY = blendY;
    lastBeatRadiusAwareContrastStrength = beatRadiusAwareContrastStrength;
    lastBeatSpeedThresholdSpreadStrength = beatSpeedThresholdSpreadStrength;
    lastBeatResponseCurves = beatResponseCurves;
    lastBandMapping = bandMapping;
    return output;
  }
}

class _FakeThreePhasePositionMapper extends ThreePhasePositionMapper {
  _FakeThreePhasePositionMapper({required this.alpha, required this.beta});

  final double alpha;
  final double beta;
  int callCount = 0;
  StimMode? lastStimMode;
  double? lastBlendX;

  @override
  (double alpha, double beta) map({
    required StimMode stimMode,
    required BeatMotionEngine beatMotion,
    required OnsetMotionEngine onsetMotion,
    required double blendX,
    required double blendY,
    required double fillCenterY,
    required double fillRadius,
    required double fillAngle,
    required double fillHhImpulse,
    required double silenceFade,
  }) {
    callCount++;
    lastStimMode = stimMode;
    lastBlendX = blendX;
    return (alpha, beta);
  }
}

class _FakeHeartbeatModeAxisApplyController
    extends HeartbeatModeAxisApplyController {
  int fourPhaseCalls = 0;
  int threePhaseCalls = 0;
  bool? lastForceSync;
  double? lastOutputDrive;
  FourPhaseElectrodeOutput? lastFourPhaseOutput;

  @override
  void applyFourPhase({
    required FourPhaseElectrodeOutput fourPhaseOutput,
    required List<Future<void>> operations,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    required FourPhaseElectrodeLevelUpdater updateFourPhaseElectrodeLevels,
  }) {
    fourPhaseCalls++;
    lastForceSync = forceSync;
    lastFourPhaseOutput = fourPhaseOutput;
    updateFourPhaseElectrodeLevels(
      e1: fourPhaseOutput.e1,
      e2: fourPhaseOutput.e2,
      e3: fourPhaseOutput.e3,
      e4: fourPhaseOutput.e4,
    );
  }

  @override
  void applyThreePhase({
    required double alpha,
    required double beta,
    required double outputDrive,
    required List<Future<void>> operations,
    required bool forceSync,
    required AxisSendPredicate shouldSendAxis,
    required AxisMoveSender moveAxis,
    required ThreePhaseElectrodeLevelUpdater updateThreePhaseElectrodeLevels,
  }) {
    threePhaseCalls++;
    lastForceSync = forceSync;
    lastOutputDrive = outputDrive;
    updateThreePhaseElectrodeLevels(
      alpha: alpha,
      beta: beta,
      outputScale: outputDrive,
    );
  }
}
