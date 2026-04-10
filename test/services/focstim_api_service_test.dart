import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart' as enums;
import 'package:breadbeats_mobile/services/focstim_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FocstimApiService validation', () {
    late FocstimApiService service;

    setUp(() {
      service = FocstimApiService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('moveAxis rejects non-finite values', () async {
      await expectLater(
        service.moveAxis(enums.AxisType.AXIS_POSITION_ALPHA, double.nan, 0),
        throwsA(isA<FocstimApiException>()),
      );

      await expectLater(
        service.moveAxis(
          enums.AxisType.AXIS_POSITION_ALPHA,
          double.infinity,
          0,
        ),
        throwsA(isA<FocstimApiException>()),
      );
    });

    test('connectTcp rejects empty host', () async {
      await expectLater(
        service.connectTcp('', 55533),
        throwsA(isA<FocstimApiException>()),
      );
    });

    test('connectTcp rejects invalid host format', () async {
      await expectLater(
        service.connectTcp('bad host!', 55533),
        throwsA(isA<FocstimApiException>()),
      );
    });

    test('connectTcp rejects out-of-range port', () async {
      await expectLater(
        service.connectTcp('127.0.0.1', 0),
        throwsA(isA<FocstimApiException>()),
      );

      await expectLater(
        service.connectTcp('127.0.0.1', 70000),
        throwsA(isA<FocstimApiException>()),
      );
    });
  });
}
