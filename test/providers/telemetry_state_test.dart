import 'package:breadbeats_mobile/generated/protobuf/focstim_rpc.pb.dart'
    as rpc;
import 'package:breadbeats_mobile/generated/protobuf/constants.pbenum.dart'
    as enums;
import 'package:breadbeats_mobile/generated/protobuf/notifications.pb.dart'
    as notif;
import 'package:breadbeats_mobile/providers/telemetry_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'TelemetryState recordNotification updates metadata and rate window',
    () {
      final TelemetryState telemetry = TelemetryState();

      final rpc.Notification first = rpc.Notification()
        ..notificationDebugTeleplot = (notif.NotificationDebugTeleplot()
          ..id = 'ch.first'
          ..value = 1.0);
      telemetry.recordNotification(
        notification: first,
        nowMs: 1000,
        droppedFrames: 2,
      );

      expect(telemetry.notificationCount, 1);
      expect(telemetry.lastCategory, 'debug_teleplot');
      expect(telemetry.lastWallClockMs, 1000);
      expect(telemetry.lastDeviceTimestamp, 0);
      expect(telemetry.hdlcDroppedFrames, 2);
      expect(telemetry.categoryCounts['debug_teleplot'], 1);
      expect(telemetry.rateHz, 0.0);

      final rpc.Notification second = rpc.Notification()
        ..notificationBattery = notif.NotificationBattery();
      telemetry.recordNotification(
        notification: second,
        nowMs: 2100,
        droppedFrames: 3,
      );

      expect(telemetry.notificationCount, 2);
      expect(telemetry.lastCategory, 'battery');
      expect(telemetry.lastWallClockMs, 2100);
      expect(telemetry.hdlcDroppedFrames, 3);
      expect(telemetry.categoryCounts['debug_teleplot'], 1);
      expect(telemetry.categoryCounts['battery'], 1);
      expect(telemetry.rateHz, closeTo((2.0 * 1000.0) / 1100.0, 1e-12));
    },
  );

  test(
    'TelemetryState setTeleplotValue enforces channel cap with eviction',
    () {
      final TelemetryState telemetry = TelemetryState();

      for (int i = 0; i <= TelemetryState.maxTeleplotChannels; i += 1) {
        telemetry.setTeleplotValue(id: 'ch.$i', value: i.toDouble());
      }

      expect(
        telemetry.teleplotChannelCount,
        TelemetryState.maxTeleplotChannels,
      );

      final Map<String, double> entries = Map<String, double>.fromEntries(
        telemetry.teleplotEntries,
      );
      expect(entries.containsKey('ch.0'), isFalse);
      expect(entries.containsKey('ch.1'), isTrue);
      expect(
        entries.containsKey('ch.${TelemetryState.maxTeleplotChannels}'),
        isTrue,
      );
    },
  );

  test('TelemetryState applies payload decode into owned state', () {
    final TelemetryState telemetry = TelemetryState();

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationDeviceVolume = (notif.NotificationDeviceVolume()
          ..volume = 0.35
          ..locked = true),
    );
    expect(telemetry.deviceVolume, closeTo(0.35, 1e-12));
    expect(telemetry.deviceVolumeLocked, isTrue);

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationCurrents = (notif.NotificationCurrents()
          ..rmsA = 0.11
          ..rmsB = 0.22
          ..rmsC = 0.33
          ..rmsD = 0.44
          ..peakA = 1.1
          ..peakB = 1.2
          ..peakC = 1.3
          ..peakD = 1.4
          ..outputPower = 2.5
          ..outputPowerSkin = 1.5
          ..peakCmd = 0.9),
    );
    expect(telemetry.rmsA, closeTo(0.11, 1e-12));
    expect(telemetry.peakD, closeTo(1.4, 1e-12));
    expect(telemetry.outputPowerW, closeTo(2.5, 1e-12));

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationOutputResistance = (notif.NotificationOutputResistance()
          ..resistanceA = 201.0
          ..resistanceB = 202.0
          ..resistanceC = 203.0
          ..resistanceD = 204.0
          ..constant = 33.0
          ..reluctanceA = -21.0
          ..reluctanceB = -22.0
          ..reluctanceC = 23.0
          ..reluctanceD = 24.0),
    );
    expect(telemetry.outputResistanceA, closeTo(201.0, 1e-12));
    expect(telemetry.outputResistanceConstant, closeTo(33.0, 1e-12));
    expect(telemetry.outputReluctanceA, closeTo(-21.0, 1e-12));
    expect(telemetry.outputReluctanceB, closeTo(-22.0, 1e-12));

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationSkinResistance = (notif.NotificationSkinResistance()
          ..resistanceA = 101.0
          ..resistanceB = 102.0
          ..resistanceC = 103.0
          ..resistanceD = 104.0
          ..reluctanceA = -11.0
          ..reluctanceB = -12.0
          ..reluctanceC = 13.0
          ..reluctanceD = 14.0),
    );
    expect(telemetry.skinResistanceA, closeTo(101.0, 1e-12));
    expect(telemetry.resistanceA, closeTo(101.0, 1e-12));
    expect(telemetry.skinReluctanceA, closeTo(-11.0, 1e-12));
    expect(telemetry.skinReluctanceB, closeTo(-12.0, 1e-12));
    expect(telemetry.reluctanceD, closeTo(14.0, 1e-12));

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationSignalStats = (notif.NotificationSignalStats()
          ..actualPulseFrequency = 48.0
          ..vDrive = 12.3
          ..transformerUtilization = 0.45
          ..voltageUtilization = 0.55),
    );
    expect(telemetry.actualPulseFrequency, closeTo(48.0, 1e-12));
    expect(telemetry.vDrive, closeTo(12.3, 1e-12));

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationBattery = (notif.NotificationBattery()
          ..batteryVoltage = 7.4
          ..batteryChargeRateWatt = 1.2
          ..batterySoc =
              0.55 // firmware sends 0–1 fraction
          ..wallPowerPresent = true
          ..chipTemperature = 36.0),
    );
    expect(telemetry.batteryVoltage, closeTo(7.4, 1e-12));
    expect(telemetry.batterySoc, closeTo(55.0, 1e-2));
    expect(telemetry.wallPowerPresent, isTrue);

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationButtonPress = (notif.NotificationButtonPress()
          ..state = enums.ButtonState.BUTTON_DOWN
          ..timestampMs = 321),
    );
    expect(telemetry.buttonState, enums.ButtonState.BUTTON_DOWN.name);
    expect(telemetry.buttonTimestampMs, 321);
  });

  test('TelemetryState bounds checks clamp invalid numeric payload values', () {
    final TelemetryState telemetry = TelemetryState();

    telemetry.recordNotification(
      notification: rpc.Notification()
        ..notificationDebugString = (notif.NotificationDebugString()
          ..message = 'x'),
      nowMs: 10,
      droppedFrames: -5,
    );
    expect(telemetry.hdlcDroppedFrames, 0);

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationDeviceVolume = (notif.NotificationDeviceVolume()
          ..volume = 2.0
          ..locked = false),
    );
    expect(telemetry.deviceVolume, 1.0);

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationBattery = (notif.NotificationBattery()
          ..batteryVoltage = -1.0
          ..batteryChargeRateWatt = 9999999.0
          ..batterySoc = 350.0
          ..chipTemperature = 500.0),
    );
    expect(telemetry.batteryVoltage, 0.0);
    expect(telemetry.batteryChargeRateWatt, 100000.0);
    expect(telemetry.batterySoc, 100.0);
    expect(telemetry.batteryChipTemperature, 200.0);

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationSignalStats = (notif.NotificationSignalStats()
          ..actualPulseFrequency = 9000.0
          ..vDrive = -10.0
          ..transformerUtilization = 3.0
          ..voltageUtilization = -1.0),
    );
    expect(telemetry.actualPulseFrequency, 5000.0);
    expect(telemetry.vDrive, 0.0);
    expect(telemetry.transformerUtilization, 2.0);
    expect(telemetry.voltageUtilization, 0.0);

    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationPressure = (notif.NotificationPressure()
          ..pressure = -100.0),
    );
    expect(telemetry.pressurePa, 0.0);

    telemetry.setTeleplotValue(id: 'bad', value: 2000000.0);
    final Map<String, double> entries = Map<String, double>.fromEntries(
      telemetry.teleplotEntries,
    );
    expect(entries['bad'], 1000000.0);
  });

  test('TelemetryState clear resets counters and maps', () {
    final TelemetryState telemetry = TelemetryState();

    telemetry.setTeleplotValue(id: 'x', value: 3.0);
    telemetry.applyNotificationPayload(
      notification: rpc.Notification()
        ..notificationDeviceVolume = (notif.NotificationDeviceVolume()
          ..volume = 0.8
          ..locked = true),
    );
    telemetry.recordNotification(
      notification: rpc.Notification()
        ..notificationPressure = notif.NotificationPressure(),
      nowMs: 1234,
      droppedFrames: 4,
    );

    telemetry.clear();

    expect(telemetry.notificationCount, 0);
    expect(telemetry.rateHz, 0.0);
    expect(telemetry.lastCategory, 'none');
    expect(telemetry.lastDeviceTimestamp, 0);
    expect(telemetry.lastWallClockMs, 0);
    expect(telemetry.hdlcDroppedFrames, 0);
    expect(telemetry.deviceVolume, 0.0);
    expect(telemetry.deviceVolumeLocked, isFalse);
    expect(telemetry.categoryCounts, isEmpty);
    expect(telemetry.teleplotChannelCount, 0);
  });
}
