import 'package:flutter/foundation.dart';

import '../generated/protobuf/constants.pbenum.dart' as enums;
import '../generated/protobuf/focstim_rpc.pb.dart' as rpc;
import '../generated/protobuf/notifications.pb.dart' as notif;

class TelemetryState {
  static const int totalTelemetryCategories = 15;
  static const int maxTeleplotChannels = 96;

  static const double _maxResistanceOhms = 1000000.0;
  static const double _maxCurrentAmps = 1000.0;
  static const double _maxPowerW = 100000.0;
  static const double _maxVoltageV = 1000.0;
  static const double _maxTemperatureC = 200.0;
  static const double _minTemperatureC = -100.0;
  static const double _maxPulseHz = 5000.0;
  static const double _maxUtilization = 2.0;
  static const double _maxBatterySoc = 100.0;
  static const double _maxPressurePa = 2000000.0;
  static const double _maxTeleplotValue = 1000000.0;

  final Map<String, int> _categoryCounts = <String, int>{};
  final Map<String, double> _teleplotValues = <String, double>{};

  int _windowStartMs = 0;
  int _windowCount = 0;

  int notificationCount = 0;
  double rateHz = 0.0;
  String lastCategory = 'none';
  int lastDeviceTimestamp = 0;
  int lastWallClockMs = 0;
  int hdlcDroppedFrames = 0;

  double deviceVolume = 0.0;
  bool deviceVolumeLocked = false;

  double rmsA = 0.0;
  double rmsB = 0.0;
  double rmsC = 0.0;
  double rmsD = 0.0;
  double peakA = 0.0;
  double peakB = 0.0;
  double peakC = 0.0;
  double peakD = 0.0;
  double outputPowerW = 0.0;
  double outputPowerSkinW = 0.0;
  double peakCmd = 0.0;

  double outputResistanceA = 0.0;
  double outputResistanceB = 0.0;
  double outputResistanceC = 0.0;
  double outputResistanceD = 0.0;
  double outputResistanceConstant = 0.0;
  double outputReluctanceA = 0.0;
  double outputReluctanceB = 0.0;
  double outputReluctanceC = 0.0;
  double outputReluctanceD = 0.0;

  double skinResistanceA = 0.0;
  double skinResistanceB = 0.0;
  double skinResistanceC = 0.0;
  double skinResistanceD = 0.0;
  double skinReluctanceA = 0.0;
  double skinReluctanceB = 0.0;
  double skinReluctanceC = 0.0;
  double skinReluctanceD = 0.0;

  double resistanceA = 0.0;
  double resistanceB = 0.0;
  double resistanceC = 0.0;
  double resistanceD = 0.0;
  double reluctanceA = 0.0;
  double reluctanceB = 0.0;
  double reluctanceC = 0.0;
  double reluctanceD = 0.0;

  String systemVariant = 'none';
  double systemTempStm32 = 0.0;
  double systemTempBoard = 0.0;
  double systemVBus = 0.0;
  double systemVRef = 0.0;
  double systemVSysMin = 0.0;
  double systemVSysMax = 0.0;
  double systemVBoostMin = 0.0;
  double systemVBoostMax = 0.0;
  double systemBoostDutyCycle = 0.0;

  double actualPulseFrequency = 0.0;
  double vDrive = 0.0;
  double transformerUtilization = 0.0;
  double voltageUtilization = 0.0;

  double batteryVoltage = 0.0;
  double batteryChargeRateWatt = 0.0;
  double batterySoc = 0.0;
  bool wallPowerPresent = false;
  double batteryChipTemperature = 0.0;

  int accX = 0;
  int accY = 0;
  int accZ = 0;
  int gyrX = 0;
  int gyrY = 0;
  int gyrZ = 0;

  double pressurePa = 0.0;
  String buttonState = 'unknown';
  int buttonTimestampMs = 0;
  String debugString = '';
  int debugAs5311Raw = 0;
  int debugAs5311Tracked = 0;
  int debugAs5311Flags = 0;
  double debugEdgingFullPowerThreshold = 0.0;
  double debugEdgingReducedPowerThreshold = 0.0;
  double debugEdgingReduction = 0.0;

  Map<String, int> get categoryCounts =>
      Map<String, int>.unmodifiable(_categoryCounts);

  int get seenCategories => _categoryCounts.length;

  int get teleplotChannelCount => _teleplotValues.length;

  List<MapEntry<String, int>> get categoryCountEntries {
    return _categoryCounts.entries.toList(growable: false);
  }

  List<MapEntry<String, double>> get teleplotEntries {
    final List<MapEntry<String, double>> entries = _teleplotValues.entries
        .toList(growable: false);
    entries.sort((MapEntry<String, double> a, MapEntry<String, double> b) {
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  void recordNotification({
    required rpc.Notification notification,
    required int nowMs,
    required int droppedFrames,
  }) {
    final rpc.Notification_Notification kind = notification.whichNotification();
    final String category = _notificationCategoryName(kind);

    notificationCount += 1;
    hdlcDroppedFrames = _boundedInt(
      field: 'hdlcDroppedFrames',
      value: droppedFrames,
      min: 0,
      max: 1000000000,
    );
    lastCategory = category;
    lastWallClockMs = nowMs;
    lastDeviceTimestamp = notification.hasTimestamp()
        ? notification.timestamp.toInt()
        : 0;

    _categoryCounts.update(
      category,
      (int value) => value + 1,
      ifAbsent: () => 1,
    );

    if (_windowStartMs == 0) {
      _windowStartMs = nowMs;
    }
    _windowCount += 1;

    final int elapsedMs = nowMs - _windowStartMs;
    if (elapsedMs >= 1000) {
      rateHz = (_windowCount * 1000.0) / elapsedMs;
      _windowStartMs = nowMs;
      _windowCount = 0;
    }
  }

  void setTeleplotValue({required String id, required double value}) {
    final String normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    final double boundedValue = _boundedDouble(
      field: 'debugTeleplot.$normalizedId',
      value: value,
      min: -_maxTeleplotValue,
      max: _maxTeleplotValue,
    );

    if (!_teleplotValues.containsKey(normalizedId) &&
        _teleplotValues.length >= maxTeleplotChannels) {
      final String oldestKey = _teleplotValues.keys.first;
      _teleplotValues.remove(oldestKey);
    }

    _teleplotValues[normalizedId] = boundedValue;
  }

  void applyNotificationPayload({required rpc.Notification notification}) {
    switch (notification.whichNotification()) {
      case rpc.Notification_Notification.notificationBoot:
        break;
      case rpc.Notification_Notification.notificationDeviceVolume:
        deviceVolume = _boundedDouble(
          field: 'deviceVolume',
          value: notification.notificationDeviceVolume.volume,
          min: 0.0,
          max: 1.0,
        );
        deviceVolumeLocked = notification.notificationDeviceVolume.locked;
        break;
      case rpc.Notification_Notification.notificationCurrents:
        final notif.NotificationCurrents currents =
            notification.notificationCurrents;
        rmsA = _boundedDouble(
          field: 'rmsA',
          value: currents.rmsA,
          min: 0.0,
          max: _maxCurrentAmps,
        );
        rmsB = _boundedDouble(
          field: 'rmsB',
          value: currents.rmsB,
          min: 0.0,
          max: _maxCurrentAmps,
        );
        rmsC = _boundedDouble(
          field: 'rmsC',
          value: currents.rmsC,
          min: 0.0,
          max: _maxCurrentAmps,
        );
        rmsD = _boundedDouble(
          field: 'rmsD',
          value: currents.rmsD,
          min: 0.0,
          max: _maxCurrentAmps,
        );
        peakA = _boundedDouble(
          field: 'peakA',
          value: currents.peakA,
          min: 0.0,
          max: _maxCurrentAmps,
        );
        peakB = _boundedDouble(
          field: 'peakB',
          value: currents.peakB,
          min: 0.0,
          max: _maxCurrentAmps,
        );
        peakC = _boundedDouble(
          field: 'peakC',
          value: currents.peakC,
          min: 0.0,
          max: _maxCurrentAmps,
        );
        peakD = _boundedDouble(
          field: 'peakD',
          value: currents.peakD,
          min: 0.0,
          max: _maxCurrentAmps,
        );
        outputPowerW = _boundedDouble(
          field: 'outputPowerW',
          value: currents.outputPower,
          min: 0.0,
          max: _maxPowerW,
        );
        outputPowerSkinW = _boundedDouble(
          field: 'outputPowerSkinW',
          value: currents.outputPowerSkin,
          min: 0.0,
          max: _maxPowerW,
        );
        peakCmd = _boundedDouble(
          field: 'peakCmd',
          value: currents.peakCmd,
          min: 0.0,
          max: _maxCurrentAmps,
        );
        break;
      case rpc.Notification_Notification.notificationOutputResistance:
        final notif.NotificationOutputResistance output =
            notification.notificationOutputResistance;
        outputResistanceA = _boundedDouble(
          field: 'outputResistanceA',
          value: output.resistanceA,
          min: 0.0,
          max: _maxResistanceOhms,
        );
        outputResistanceB = _boundedDouble(
          field: 'outputResistanceB',
          value: output.resistanceB,
          min: 0.0,
          max: _maxResistanceOhms,
        );
        outputResistanceC = _boundedDouble(
          field: 'outputResistanceC',
          value: output.resistanceC,
          min: 0.0,
          max: _maxResistanceOhms,
        );
        outputResistanceD = _boundedDouble(
          field: 'outputResistanceD',
          value: output.resistanceD,
          min: 0.0,
          max: _maxResistanceOhms,
        );
        outputResistanceConstant = output.hasConstant()
            ? _boundedDouble(
                field: 'outputResistanceConstant',
                value: output.constant,
                min: 0.0,
                max: _maxResistanceOhms,
              )
            : 0.0;
        outputReluctanceA = _boundedDouble(
          field: 'outputReluctanceA',
          value: output.reluctanceA,
          min: -_maxResistanceOhms,
          max: _maxResistanceOhms,
        );
        outputReluctanceB = _boundedDouble(
          field: 'outputReluctanceB',
          value: output.reluctanceB,
          min: -_maxResistanceOhms,
          max: _maxResistanceOhms,
        );
        outputReluctanceC = _boundedDouble(
          field: 'outputReluctanceC',
          value: output.reluctanceC,
          min: -_maxResistanceOhms,
          max: _maxResistanceOhms,
        );
        outputReluctanceD = _boundedDouble(
          field: 'outputReluctanceD',
          value: output.reluctanceD,
          min: -_maxResistanceOhms,
          max: _maxResistanceOhms,
        );
        break;
      case rpc.Notification_Notification.notificationSkinResistance:
        final notif.NotificationSkinResistance skin =
            notification.notificationSkinResistance;
        skinResistanceA = _boundedDouble(
          field: 'skinResistanceA',
          value: skin.resistanceA,
          min: 0.0,
          max: _maxResistanceOhms,
        );
        skinResistanceB = _boundedDouble(
          field: 'skinResistanceB',
          value: skin.resistanceB,
          min: 0.0,
          max: _maxResistanceOhms,
        );
        skinResistanceC = _boundedDouble(
          field: 'skinResistanceC',
          value: skin.resistanceC,
          min: 0.0,
          max: _maxResistanceOhms,
        );
        skinResistanceD = _boundedDouble(
          field: 'skinResistanceD',
          value: skin.resistanceD,
          min: 0.0,
          max: _maxResistanceOhms,
        );
        skinReluctanceA = _boundedDouble(
          field: 'skinReluctanceA',
          value: skin.reluctanceA,
          min: -_maxResistanceOhms,
          max: _maxResistanceOhms,
        );
        skinReluctanceB = _boundedDouble(
          field: 'skinReluctanceB',
          value: skin.reluctanceB,
          min: -_maxResistanceOhms,
          max: _maxResistanceOhms,
        );
        skinReluctanceC = _boundedDouble(
          field: 'skinReluctanceC',
          value: skin.reluctanceC,
          min: -_maxResistanceOhms,
          max: _maxResistanceOhms,
        );
        skinReluctanceD = _boundedDouble(
          field: 'skinReluctanceD',
          value: skin.reluctanceD,
          min: -_maxResistanceOhms,
          max: _maxResistanceOhms,
        );

        resistanceA = skinResistanceA;
        resistanceB = skinResistanceB;
        resistanceC = skinResistanceC;
        resistanceD = skinResistanceD;
        reluctanceA = skinReluctanceA;
        reluctanceB = skinReluctanceB;
        reluctanceC = skinReluctanceC;
        reluctanceD = skinReluctanceD;
        break;
      case rpc.Notification_Notification.notificationSystemStats:
        final notif.NotificationSystemStats stats =
            notification.notificationSystemStats;
        switch (stats.whichSystem()) {
          case notif.NotificationSystemStats_System.esc1:
            systemVariant = 'esc1';
            systemTempStm32 = _boundedDouble(
              field: 'systemTempStm32',
              value: stats.esc1.tempStm32,
              min: _minTemperatureC,
              max: _maxTemperatureC,
            );
            systemTempBoard = _boundedDouble(
              field: 'systemTempBoard',
              value: stats.esc1.tempBoard,
              min: _minTemperatureC,
              max: _maxTemperatureC,
            );
            systemVBus = _boundedDouble(
              field: 'systemVBus',
              value: stats.esc1.vBus,
              min: 0.0,
              max: _maxVoltageV,
            );
            systemVRef = _boundedDouble(
              field: 'systemVRef',
              value: stats.esc1.vRef,
              min: 0.0,
              max: _maxVoltageV,
            );
            break;
          case notif.NotificationSystemStats_System.focstimv3:
            systemVariant = 'focstimv3';
            systemTempStm32 = _boundedDouble(
              field: 'systemTempStm32',
              value: stats.focstimv3.tempStm32,
              min: _minTemperatureC,
              max: _maxTemperatureC,
            );
            systemVRef = _boundedDouble(
              field: 'systemVRef',
              value: stats.focstimv3.vRef,
              min: 0.0,
              max: _maxVoltageV,
            );
            systemVSysMin = _boundedDouble(
              field: 'systemVSysMin',
              value: stats.focstimv3.vSysMin,
              min: 0.0,
              max: _maxVoltageV,
            );
            systemVSysMax = _boundedDouble(
              field: 'systemVSysMax',
              value: stats.focstimv3.vSysMax,
              min: 0.0,
              max: _maxVoltageV,
            );
            systemVBoostMin = _boundedDouble(
              field: 'systemVBoostMin',
              value: stats.focstimv3.vBoostMin,
              min: 0.0,
              max: _maxVoltageV,
            );
            systemVBoostMax = _boundedDouble(
              field: 'systemVBoostMax',
              value: stats.focstimv3.vBoostMax,
              min: 0.0,
              max: _maxVoltageV,
            );
            systemBoostDutyCycle = _boundedDouble(
              field: 'systemBoostDutyCycle',
              value: stats.focstimv3.boostDutyCycle,
              min: 0.0,
              max: 1.0,
            );
            break;
          case notif.NotificationSystemStats_System.notSet:
            systemVariant = 'none';
            break;
        }
        break;
      case rpc.Notification_Notification.notificationSignalStats:
        actualPulseFrequency = _boundedDouble(
          field: 'actualPulseFrequency',
          value: notification.notificationSignalStats.actualPulseFrequency,
          min: 0.0,
          max: _maxPulseHz,
        );
        vDrive = _boundedDouble(
          field: 'vDrive',
          value: notification.notificationSignalStats.vDrive,
          min: 0.0,
          max: _maxVoltageV,
        );
        transformerUtilization = _boundedDouble(
          field: 'transformerUtilization',
          value: notification.notificationSignalStats.transformerUtilization,
          min: 0.0,
          max: _maxUtilization,
        );
        voltageUtilization = _boundedDouble(
          field: 'voltageUtilization',
          value: notification.notificationSignalStats.voltageUtilization,
          min: 0.0,
          max: _maxUtilization,
        );
        break;
      case rpc.Notification_Notification.notificationBattery:
        final notif.NotificationBattery battery =
            notification.notificationBattery;
        batteryVoltage = _boundedDouble(
          field: 'batteryVoltage',
          value: battery.batteryVoltage,
          min: 0.0,
          max: 100.0,
        );
        batteryChargeRateWatt = _boundedDouble(
          field: 'batteryChargeRateWatt',
          value: battery.batteryChargeRateWatt,
          min: 0.0,
          max: _maxPowerW,
        );
        batterySoc = _boundedDouble(
          field: 'batterySoc',
          value:
              battery.batterySoc *
              100.0, // firmware sends 0–1 fraction; store as %
          min: 0.0,
          max: _maxBatterySoc,
        );
        wallPowerPresent = battery.wallPowerPresent;
        batteryChipTemperature = _boundedDouble(
          field: 'batteryChipTemperature',
          value: battery.chipTemperature,
          min: _minTemperatureC,
          max: _maxTemperatureC,
        );
        break;
      case rpc.Notification_Notification.notificationLsm6dsox:
        final notif.NotificationLSM6DSOX imu =
            notification.notificationLsm6dsox;
        accX = imu.accX;
        accY = imu.accY;
        accZ = imu.accZ;
        gyrX = imu.gyrX;
        gyrY = imu.gyrY;
        gyrZ = imu.gyrZ;
        break;
      case rpc.Notification_Notification.notificationPressure:
        pressurePa = _boundedDouble(
          field: 'pressurePa',
          value: notification.notificationPressure.pressure,
          min: 0.0,
          max: _maxPressurePa,
        );
        break;
      case rpc.Notification_Notification.notificationButtonPress:
        final enums.ButtonState button =
            notification.notificationButtonPress.state;
        buttonState = button.name;
        buttonTimestampMs = _boundedInt(
          field: 'buttonTimestampMs',
          value: notification.notificationButtonPress.timestampMs,
          min: 0,
          max: 2147483647,
        );
        break;
      case rpc.Notification_Notification.notificationDebugString:
        debugString = notification.notificationDebugString.message;
        break;
      case rpc.Notification_Notification.notificationDebugAs5311:
        debugAs5311Raw = notification.notificationDebugAs5311.raw;
        debugAs5311Tracked = notification.notificationDebugAs5311.tracked;
        debugAs5311Flags = notification.notificationDebugAs5311.flags;
        break;
      case rpc.Notification_Notification.notificationDebugEdging:
        debugEdgingFullPowerThreshold = _boundedDouble(
          field: 'debugEdgingFullPowerThreshold',
          value: notification.notificationDebugEdging.fullPowerThreshold,
          min: 0.0,
          max: 10.0,
        );
        debugEdgingReducedPowerThreshold = _boundedDouble(
          field: 'debugEdgingReducedPowerThreshold',
          value: notification.notificationDebugEdging.reducedPowerThreshold,
          min: 0.0,
          max: 10.0,
        );
        debugEdgingReduction = _boundedDouble(
          field: 'debugEdgingReduction',
          value: notification.notificationDebugEdging.reduction,
          min: 0.0,
          max: 10.0,
        );
        break;
      case rpc.Notification_Notification.notificationDebugTeleplot:
        setTeleplotValue(
          id: notification.notificationDebugTeleplot.id,
          value: notification.notificationDebugTeleplot.value,
        );
        break;
      case rpc.Notification_Notification.notSet:
        break;
    }
  }

  void clear() {
    notificationCount = 0;
    _categoryCounts.clear();
    _teleplotValues.clear();
    _windowStartMs = 0;
    _windowCount = 0;
    rateHz = 0.0;
    lastCategory = 'none';
    lastDeviceTimestamp = 0;
    lastWallClockMs = 0;
    hdlcDroppedFrames = 0;

    deviceVolume = 0.0;
    deviceVolumeLocked = false;

    rmsA = 0.0;
    rmsB = 0.0;
    rmsC = 0.0;
    rmsD = 0.0;
    peakA = 0.0;
    peakB = 0.0;
    peakC = 0.0;
    peakD = 0.0;
    outputPowerW = 0.0;
    outputPowerSkinW = 0.0;
    peakCmd = 0.0;

    outputResistanceA = 0.0;
    outputResistanceB = 0.0;
    outputResistanceC = 0.0;
    outputResistanceD = 0.0;
    outputResistanceConstant = 0.0;
    outputReluctanceA = 0.0;
    outputReluctanceB = 0.0;
    outputReluctanceC = 0.0;
    outputReluctanceD = 0.0;

    skinResistanceA = 0.0;
    skinResistanceB = 0.0;
    skinResistanceC = 0.0;
    skinResistanceD = 0.0;
    skinReluctanceA = 0.0;
    skinReluctanceB = 0.0;
    skinReluctanceC = 0.0;
    skinReluctanceD = 0.0;

    resistanceA = 0.0;
    resistanceB = 0.0;
    resistanceC = 0.0;
    resistanceD = 0.0;
    reluctanceA = 0.0;
    reluctanceB = 0.0;
    reluctanceC = 0.0;
    reluctanceD = 0.0;

    systemVariant = 'none';
    systemTempStm32 = 0.0;
    systemTempBoard = 0.0;
    systemVBus = 0.0;
    systemVRef = 0.0;
    systemVSysMin = 0.0;
    systemVSysMax = 0.0;
    systemVBoostMin = 0.0;
    systemVBoostMax = 0.0;
    systemBoostDutyCycle = 0.0;

    actualPulseFrequency = 0.0;
    vDrive = 0.0;
    transformerUtilization = 0.0;
    voltageUtilization = 0.0;

    batteryVoltage = 0.0;
    batteryChargeRateWatt = 0.0;
    batterySoc = 0.0;
    wallPowerPresent = false;
    batteryChipTemperature = 0.0;

    accX = 0;
    accY = 0;
    accZ = 0;
    gyrX = 0;
    gyrY = 0;
    gyrZ = 0;

    pressurePa = 0.0;
    buttonState = 'unknown';
    buttonTimestampMs = 0;
    debugString = '';
    debugAs5311Raw = 0;
    debugAs5311Tracked = 0;
    debugAs5311Flags = 0;
    debugEdgingFullPowerThreshold = 0.0;
    debugEdgingReducedPowerThreshold = 0.0;
    debugEdgingReduction = 0.0;
  }

  double _boundedDouble({
    required String field,
    required double value,
    required double min,
    required double max,
  }) {
    if (!value.isFinite) {
      _logOutOfRange(field: field, value: value, min: min, max: max);
      return min;
    }
    if (value < min || value > max) {
      _logOutOfRange(field: field, value: value, min: min, max: max);
      return value.clamp(min, max);
    }
    return value;
  }

  int _boundedInt({
    required String field,
    required int value,
    required int min,
    required int max,
  }) {
    if (value < min || value > max) {
      _logOutOfRange(field: field, value: value, min: min, max: max);
      return value.clamp(min, max);
    }
    return value;
  }

  void _logOutOfRange({
    required String field,
    required Object value,
    required Object min,
    required Object max,
  }) {
    debugPrint(
      '[TelemetryState] Out-of-range value for $field: $value '
      '(expected [$min..$max])',
    );
  }

  String _notificationCategoryName(rpc.Notification_Notification kind) {
    return switch (kind) {
      rpc.Notification_Notification.notificationBoot => 'boot',
      rpc.Notification_Notification.notificationDeviceVolume => 'device_volume',
      rpc.Notification_Notification.notificationCurrents => 'currents',
      rpc.Notification_Notification.notificationOutputResistance =>
        'output_resistance',
      rpc.Notification_Notification.notificationSkinResistance =>
        'skin_resistance',
      rpc.Notification_Notification.notificationSystemStats => 'system_stats',
      rpc.Notification_Notification.notificationSignalStats => 'signal_stats',
      rpc.Notification_Notification.notificationBattery => 'battery',
      rpc.Notification_Notification.notificationLsm6dsox => 'lsm6dsox',
      rpc.Notification_Notification.notificationPressure => 'pressure',
      rpc.Notification_Notification.notificationButtonPress => 'button_press',
      rpc.Notification_Notification.notificationDebugString => 'debug_string',
      rpc.Notification_Notification.notificationDebugAs5311 => 'debug_as5311',
      rpc.Notification_Notification.notificationDebugEdging => 'debug_edging',
      rpc.Notification_Notification.notificationDebugTeleplot =>
        'debug_teleplot',
      rpc.Notification_Notification.notSet => 'not_set',
    };
  }
}
