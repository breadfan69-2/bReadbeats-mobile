import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/calibration_controller.dart';
import 'package:breadbeats_mobile/providers/calibration_pattern_tick_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const CalibrationPatternTickMapper mapper = CalibrationPatternTickMapper();

  test('maps active four-phase pattern outputs after advancing time', () {
    final CalibrationController controller = CalibrationController()
      ..setPattern(CalibrationPattern.sequential1234)
      ..setPatternSpeed(1.0)
      ..resetAngle();

    final CalibrationPatternTickOutput output = mapper.map(
      pattern: controller.pattern,
      controller: controller,
      outputMode: OutputModeSelection.fourPhase,
      dtSec: 0.25,
    );

    expect(output.isFourPhase, isTrue);
    expect(output.e1, closeTo(0.5, 1e-9));
    expect(output.e2, closeTo(1.0, 1e-9));
    expect(output.e3, closeTo(0.5, 1e-9));
    expect(output.e4, closeTo(0.0, 1e-9));
    expect(output.alpha, isNull);
    expect(output.beta, isNull);
  });

  test('maps active three-phase pattern outputs after advancing time', () {
    final CalibrationController controller = CalibrationController()
      ..setPattern(CalibrationPattern.circle)
      ..setPatternSpeed(1.0)
      ..resetAngle();

    final CalibrationPatternTickOutput output = mapper.map(
      pattern: controller.pattern,
      controller: controller,
      outputMode: OutputModeSelection.threePhase,
      dtSec: 0.25,
    );

    expect(output.isFourPhase, isFalse);
    expect(output.alpha, closeTo(0.0, 1e-9));
    expect(output.beta, closeTo(1.0, 1e-9));
    expect(output.e1, isNull);
    expect(output.e2, isNull);
    expect(output.e3, isNull);
    expect(output.e4, isNull);
  });
}
