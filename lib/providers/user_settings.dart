import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_models.dart';
import '../models/enums.dart';

class UserSettings {
  static const String prefsCapturePackageKey = 'capture.selected_app_package';
  static const String prefsCaptureAppNameKey = 'capture.selected_app_name';
  static const String prefsCaptureUidKey = 'capture.selected_app_uid';
  static const String prefsHostKey = 'connection.host';
  static const String prefsPortKey = 'connection.port';
  static const String prefsHostHistoryKey = 'connection.host_history';

  OutputModeSelection outputMode = OutputModeSelection.fourPhase;
  StimMode stimMode = StimMode.beat;

  double sensitivity = 0.48;
  double intensityCap = 50.0;
  double carrierHz = 950.0;
  double carrierMinHz = 700.0;
  double carrierMaxHz = 1200.0;
  double tauMicros = 355.0;
  bool calibrationLocked = true;

  double pulseWidthCycles = 5.0;
  double pulseRiseTimeCycles = 10.0;
  double pulseIntervalRandomPercent = 10.0;

  double cal3Neutral = 0.0;
  double cal3Right = 0.0;
  double cal3Center = -0.7;
  double cal4A = 0.0;
  double cal4B = 0.0;
  double cal4C = 0.0;
  double cal4D = 0.0;

  double pulseMinHz = 5.0;
  double pulseMaxHz = 80.0;
  bool manualPulseMode = false;
  double manualPulseHz = 40.0;
  double manualAlpha = 0.0;
  double manualBeta = 0.0;
  double manualE1 = 0.333;
  double manualE2 = 0.333;
  double manualE3 = 0.333;
  double manualE4 = 0.0;
  bool carrierLfoEnabled = false;
  double carrierLfoRateHz = 0.5;
  double carrierLfoDepth = 0.3;
  bool pulseLfoEnabled = false;
  double pulseLfoRateHz = 0.5;
  double pulseLfoDepth = 0.3;
  bool carrierLocked = false;
  bool pulseLocked = false;
  double manualIntensity = 0.0;
  double bassMonitorLowHz = 20.0;
  double bassMonitorHighHz = 250.0;
  double onsetSensitivityMin = 0.0;
  double onsetSensitivityMax = 1.0;
  double onsetSmoothing = 0.0;
  List<List<AudioBand>> onsetBandMapping = defaultOnsetBandMapping
      .map((List<AudioBand> bands) => List<AudioBand>.from(bands))
      .toList();
  bool imuStreamingEnabled = false;
  bool tempoUnlockHoldEnabled = true;
  double energyResponseStrength = 1.0;
  double latencyCompensationMs = 0.0;
  bool adaptiveLeadEnabled = true;
  bool learningEnabled = true;
  double learningStrength = 0.55;
  double beatRadiusAwareContrastStrength = 0.0;
  double beatSpeedThresholdSpreadStrength = 0.0;
  List<BeatResponseCurve> beatFourPhaseResponseCurves =
      defaultBeatFourPhaseResponseCurves
          .map((BeatResponseCurve curve) => curve)
          .toList();
  bool hardFillGateEnabled = false;
  double adaptiveLeadCorrectionGain = 0.35;

  Timer? _persistTimer;

  static const String _prefsOutputModeKey = 'settings.output_mode';
  static const String _prefsStimModeKey = 'settings.stim_mode';
  static const String _prefsSensitivityKey = 'settings.sensitivity';
  static const String _prefsIntensityCapKey = 'settings.intensity_cap';
  static const String _prefsCarrierHzKey = 'settings.carrier_hz';
  static const String _prefsCarrierMinHzKey = 'settings.carrier_min_hz';
  static const String _prefsCarrierMaxHzKey = 'settings.carrier_max_hz';
  static const String _prefsTauMicrosKey = 'settings.tau_micros';
  static const String _prefsCalibrationLockedKey =
      'settings.calibration_locked';
  static const String _prefsPulseWidthCyclesKey = 'settings.pulse_width_cycles';
  static const String _prefsPulseRiseTimeCyclesKey =
      'settings.pulse_rise_time_cycles';
  static const String _prefsPulseIntervalRandomKey =
      'settings.pulse_interval_random';
  static const String _prefsCal3NeutralKey = 'settings.cal3_neutral';
  static const String _prefsCal3RightKey = 'settings.cal3_right';
  static const String _prefsCal3CenterKey = 'settings.cal3_center';
  static const String _prefsCal4AKey = 'settings.cal4_a';
  static const String _prefsCal4BKey = 'settings.cal4_b';
  static const String _prefsCal4CKey = 'settings.cal4_c';
  static const String _prefsCal4DKey = 'settings.cal4_d';
  static const String _prefsPulseMinHzKey = 'settings.pulse_min_hz';
  static const String _prefsPulseMaxHzKey = 'settings.pulse_max_hz';
  static const String _prefsBassMonitorLowHzKey =
      'settings.bass_monitor_low_hz';
  static const String _prefsBassMonitorHighHzKey =
      'settings.bass_monitor_high_hz';
  static const String _prefsManualPulseModeKey = 'settings.manual_pulse_mode';
  static const String _prefsManualPulseHzKey = 'settings.manual_pulse_hz';
  static const String _prefsManualAlphaKey = 'settings.manual_alpha';
  static const String _prefsManualBetaKey = 'settings.manual_beta';
  static const String _prefsManualE1Key = 'settings.manual_e1';
  static const String _prefsManualE2Key = 'settings.manual_e2';
  static const String _prefsManualE3Key = 'settings.manual_e3';
  static const String _prefsManualE4Key = 'settings.manual_e4';
  static const String _prefsManualCarrierLfoEnabledKey =
      'settings.manual_carrier_lfo_enabled';
  static const String _prefsManualCarrierLfoRateHzKey =
      'settings.manual_carrier_lfo_rate_hz';
  static const String _prefsManualCarrierLfoDepthKey =
      'settings.manual_carrier_lfo_depth';
  static const String _prefsManualPulseLfoEnabledKey =
      'settings.manual_pulse_lfo_enabled';
  static const String _prefsManualPulseLfoRateHzKey =
      'settings.manual_pulse_lfo_rate_hz';
  static const String _prefsManualPulseLfoDepthKey =
      'settings.manual_pulse_lfo_depth';
  static const String _prefsManualCarrierLockedKey =
      'settings.manual_carrier_locked';
  static const String _prefsManualPulseLockedKey =
      'settings.manual_pulse_locked';
  static const String _prefsManualIntensityKey = 'settings.manual_intensity';
  static const String _prefsOnsetSensMinKey = 'settings.onset_sensitivity_min';
  static const String _prefsOnsetSensMaxKey = 'settings.onset_sensitivity_max';
  static const String _prefsOnsetSmoothingKey = 'settings.onset_smoothing';
  static const String _prefsOnsetBandMapE1Key = 'settings.onset_band_map_e1';
  static const String _prefsOnsetBandMapE2Key = 'settings.onset_band_map_e2';
  static const String _prefsOnsetBandMapE3Key = 'settings.onset_band_map_e3';
  static const String _prefsOnsetBandMapE4Key = 'settings.onset_band_map_e4';
  static const String _prefsImuStreamingEnabledKey =
      'settings.imu_streaming_enabled';
  static const String _prefsTempoUnlockHoldEnabledKey =
      'settings.tempo_unlock_hold_enabled';
  static const String _prefsEnergyResponseStrengthKey =
      'settings.energy_response_strength';
  static const String _prefsLatencyCompensationMsKey =
      'settings.latency_compensation_ms';
  static const String _prefsAdaptiveLeadEnabledKey =
      'settings.adaptive_lead_enabled';
  static const String _prefsLearningEnabledKey = 'settings.learning_enabled';
  static const String _prefsLearningStrengthKey = 'settings.learning_strength';
  static const String _prefsBeatRadiusAwareContrastStrengthKey =
      'settings.beat_radius_aware_contrast_strength';
  static const String _prefsBeatSpeedThresholdSpreadStrengthKey =
      'settings.beat_speed_threshold_spread_strength';
  static const String _prefsBeatCurveE1Key = 'settings.beat_curve_e1';
  static const String _prefsBeatCurveE2Key = 'settings.beat_curve_e2';
  static const String _prefsBeatCurveE3Key = 'settings.beat_curve_e3';
  static const String _prefsBeatCurveE4Key = 'settings.beat_curve_e4';
  static const String _prefsHardFillGateEnabledKey =
      'settings.hard_fill_gate_enabled';
  static const String _prefsAdaptiveLeadCorrectionGainKey =
      'settings.adaptive_lead_correction_gain';

  bool restoreFromPreferences(SharedPreferences prefs) {
    bool changed = false;

    final String? savedOutputMode = prefs.getString(_prefsOutputModeKey);
    if (savedOutputMode == 'threePhase' &&
        outputMode != OutputModeSelection.threePhase) {
      outputMode = OutputModeSelection.threePhase;
      changed = true;
    } else if (savedOutputMode == 'fourPhase' &&
        outputMode != OutputModeSelection.fourPhase) {
      outputMode = OutputModeSelection.fourPhase;
      changed = true;
    }

    final String? savedStimMode = prefs.getString(_prefsStimModeKey);
    if (savedStimMode == 'beat' && stimMode != StimMode.beat) {
      stimMode = StimMode.beat;
      changed = true;
    } else if (savedStimMode == 'onset' && stimMode != StimMode.onset) {
      stimMode = StimMode.onset;
      changed = true;
    }

    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsSensitivityKey,
          current: sensitivity,
          apply: (double value) => sensitivity = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsIntensityCapKey,
          current: intensityCap,
          apply: (double value) => intensityCap = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCarrierHzKey,
          current: carrierHz,
          apply: (double value) => carrierHz = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCarrierMinHzKey,
          current: carrierMinHz,
          apply: (double value) => carrierMinHz = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCarrierMaxHzKey,
          current: carrierMaxHz,
          apply: (double value) => carrierMaxHz = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsTauMicrosKey,
          current: tauMicros,
          apply: (double value) => tauMicros = value,
        ) ||
        changed;
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsCalibrationLockedKey,
          current: calibrationLocked,
          apply: (bool value) => calibrationLocked = value,
        ) ||
        changed;

    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsPulseWidthCyclesKey,
          current: pulseWidthCycles,
          apply: (double value) => pulseWidthCycles = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsPulseRiseTimeCyclesKey,
          current: pulseRiseTimeCycles,
          apply: (double value) => pulseRiseTimeCycles = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsPulseIntervalRandomKey,
          current: pulseIntervalRandomPercent,
          apply: (double value) => pulseIntervalRandomPercent = value,
        ) ||
        changed;

    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCal3NeutralKey,
          current: cal3Neutral,
          apply: (double value) => cal3Neutral = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCal3RightKey,
          current: cal3Right,
          apply: (double value) => cal3Right = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCal3CenterKey,
          current: cal3Center,
          apply: (double value) => cal3Center = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCal4AKey,
          current: cal4A,
          apply: (double value) => cal4A = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCal4BKey,
          current: cal4B,
          apply: (double value) => cal4B = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCal4CKey,
          current: cal4C,
          apply: (double value) => cal4C = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsCal4DKey,
          current: cal4D,
          apply: (double value) => cal4D = value,
        ) ||
        changed;

    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsPulseMinHzKey,
          current: pulseMinHz,
          apply: (double value) => pulseMinHz = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsPulseMaxHzKey,
          current: pulseMaxHz,
          apply: (double value) => pulseMaxHz = value,
        ) ||
        changed;
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsManualPulseModeKey,
          current: manualPulseMode,
          apply: (bool value) => manualPulseMode = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualPulseHzKey,
          current: manualPulseHz,
          apply: (double value) => manualPulseHz = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualAlphaKey,
          current: manualAlpha,
          apply: (double value) => manualAlpha = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualBetaKey,
          current: manualBeta,
          apply: (double value) => manualBeta = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualE1Key,
          current: manualE1,
          apply: (double value) => manualE1 = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualE2Key,
          current: manualE2,
          apply: (double value) => manualE2 = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualE3Key,
          current: manualE3,
          apply: (double value) => manualE3 = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualE4Key,
          current: manualE4,
          apply: (double value) => manualE4 = value,
        ) ||
        changed;
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsManualCarrierLfoEnabledKey,
          current: carrierLfoEnabled,
          apply: (bool value) => carrierLfoEnabled = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualCarrierLfoRateHzKey,
          current: carrierLfoRateHz,
          apply: (double value) => carrierLfoRateHz = value.clamp(0.05, 10.0),
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualCarrierLfoDepthKey,
          current: carrierLfoDepth,
          apply: (double value) => carrierLfoDepth = value.clamp(0.0, 1.0),
        ) ||
        changed;
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsManualPulseLfoEnabledKey,
          current: pulseLfoEnabled,
          apply: (bool value) => pulseLfoEnabled = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualPulseLfoRateHzKey,
          current: pulseLfoRateHz,
          apply: (double value) => pulseLfoRateHz = value.clamp(0.05, 10.0),
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualPulseLfoDepthKey,
          current: pulseLfoDepth,
          apply: (double value) => pulseLfoDepth = value.clamp(0.0, 1.0),
        ) ||
        changed;
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsManualCarrierLockedKey,
          current: carrierLocked,
          apply: (bool value) => carrierLocked = value,
        ) ||
        changed;
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsManualPulseLockedKey,
          current: pulseLocked,
          apply: (bool value) => pulseLocked = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsManualIntensityKey,
          current: manualIntensity,
          apply: (double value) => manualIntensity = value.clamp(0.0, 100.0),
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsBassMonitorLowHzKey,
          current: bassMonitorLowHz,
          apply: (double value) => bassMonitorLowHz = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsBassMonitorHighHzKey,
          current: bassMonitorHighHz,
          apply: (double value) => bassMonitorHighHz = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsOnsetSensMinKey,
          current: onsetSensitivityMin,
          apply: (double value) => onsetSensitivityMin = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsOnsetSensMaxKey,
          current: onsetSensitivityMax,
          apply: (double value) => onsetSensitivityMax = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsOnsetSmoothingKey,
          current: onsetSmoothing,
          apply: (double value) => onsetSmoothing = value,
        ) ||
        changed;

    final List<String?> bandMapRaw = <String?>[
      prefs.getString(_prefsOnsetBandMapE1Key),
      prefs.getString(_prefsOnsetBandMapE2Key),
      prefs.getString(_prefsOnsetBandMapE3Key),
      prefs.getString(_prefsOnsetBandMapE4Key),
    ];
    bool bandMapChanged = false;
    for (int i = 0; i < 4; i++) {
      final String? raw = bandMapRaw[i];
      if (raw == null) {
        continue;
      }
      final List<AudioBand> restored = _parseOnsetBands(raw);
      if (restored.isEmpty) {
        continue;
      }
      if (!listEquals(restored, onsetBandMapping[i])) {
        onsetBandMapping[i] = restored;
        bandMapChanged = true;
      }
    }
    if (bandMapChanged) {
      changed = true;
    }

    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsImuStreamingEnabledKey,
          current: imuStreamingEnabled,
          apply: (bool value) => imuStreamingEnabled = value,
        ) ||
        changed;
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsTempoUnlockHoldEnabledKey,
          current: tempoUnlockHoldEnabled,
          apply: (bool value) => tempoUnlockHoldEnabled = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsEnergyResponseStrengthKey,
          current: energyResponseStrength,
          apply: (double value) => energyResponseStrength = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsLatencyCompensationMsKey,
          current: latencyCompensationMs,
          apply: (double value) => latencyCompensationMs = value,
        ) ||
        changed;
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsAdaptiveLeadEnabledKey,
          current: adaptiveLeadEnabled,
          apply: (bool value) => adaptiveLeadEnabled = value,
        ) ||
        changed;
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsLearningEnabledKey,
          current: learningEnabled,
          apply: (bool value) => learningEnabled = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsLearningStrengthKey,
          current: learningStrength,
          apply: (double value) => learningStrength = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsBeatRadiusAwareContrastStrengthKey,
          current: beatRadiusAwareContrastStrength,
          apply: (double value) =>
              beatRadiusAwareContrastStrength = value.clamp(0.0, 1.0),
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsBeatSpeedThresholdSpreadStrengthKey,
          current: beatSpeedThresholdSpreadStrength,
          apply: (double value) =>
              beatSpeedThresholdSpreadStrength = value.clamp(0.0, 1.0),
        ) ||
        changed;
    final List<String?> beatCurveRaw = <String?>[
      prefs.getString(_prefsBeatCurveE1Key),
      prefs.getString(_prefsBeatCurveE2Key),
      prefs.getString(_prefsBeatCurveE3Key),
      prefs.getString(_prefsBeatCurveE4Key),
    ];
    bool beatCurveChanged = false;
    for (int i = 0; i < 4; i++) {
      final BeatResponseCurve? restored = _parseBeatResponseCurve(
        beatCurveRaw[i],
      );
      if (restored == null) {
        continue;
      }
      if (beatFourPhaseResponseCurves[i] != restored) {
        beatFourPhaseResponseCurves[i] = restored;
        beatCurveChanged = true;
      }
    }
    if (beatCurveChanged) {
      changed = true;
    }
    changed =
        _restoreBool(
          prefs: prefs,
          key: _prefsHardFillGateEnabledKey,
          current: hardFillGateEnabled,
          apply: (bool value) => hardFillGateEnabled = value,
        ) ||
        changed;
    changed =
        _restoreDouble(
          prefs: prefs,
          key: _prefsAdaptiveLeadCorrectionGainKey,
          current: adaptiveLeadCorrectionGain,
          apply: (double value) =>
              adaptiveLeadCorrectionGain = value.clamp(0.05, 1.0),
        ) ||
        changed;

    final double clampedCarrierHz = carrierHz.clamp(carrierMinHz, carrierMaxHz);
    if (clampedCarrierHz != carrierHz) {
      carrierHz = clampedCarrierHz;
      changed = true;
    }

    final double clampedTauMicros = tauMicros.clamp(0.0, 1000.0);
    if (clampedTauMicros != tauMicros) {
      tauMicros = clampedTauMicros;
      changed = true;
    }

    final double clampedManualAlpha = manualAlpha.clamp(-1.0, 1.0);
    if (clampedManualAlpha != manualAlpha) {
      manualAlpha = clampedManualAlpha;
      changed = true;
    }

    final double clampedManualBeta = manualBeta.clamp(-1.0, 1.0);
    if (clampedManualBeta != manualBeta) {
      manualBeta = clampedManualBeta;
      changed = true;
    }

    final double clampedManualE1 = manualE1.clamp(0.0, 1.0);
    if (clampedManualE1 != manualE1) {
      manualE1 = clampedManualE1;
      changed = true;
    }

    final double clampedManualE2 = manualE2.clamp(0.0, 1.0);
    if (clampedManualE2 != manualE2) {
      manualE2 = clampedManualE2;
      changed = true;
    }

    final double clampedManualE3 = manualE3.clamp(0.0, 1.0);
    if (clampedManualE3 != manualE3) {
      manualE3 = clampedManualE3;
      changed = true;
    }

    final double clampedManualE4 = manualE4.clamp(0.0, 1.0);
    if (clampedManualE4 != manualE4) {
      manualE4 = clampedManualE4;
      changed = true;
    }

    final double clampedManualIntensity = manualIntensity.clamp(0.0, 100.0);
    if (clampedManualIntensity != manualIntensity) {
      manualIntensity = clampedManualIntensity;
      changed = true;
    }

    return changed;
  }

  void schedulePersist({SharedPreferences? sharedPreferences}) {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final SharedPreferences prefs =
            sharedPreferences ?? await SharedPreferences.getInstance();

        await prefs.setString(
          _prefsOutputModeKey,
          outputMode == OutputModeSelection.threePhase
              ? 'threePhase'
              : 'fourPhase',
        );
        await prefs.setString(
          _prefsStimModeKey,
          stimMode == StimMode.beat ? 'beat' : 'onset',
        );

        await prefs.setDouble(_prefsSensitivityKey, sensitivity);
        await prefs.setDouble(_prefsIntensityCapKey, intensityCap);
        await prefs.setDouble(_prefsCarrierHzKey, carrierHz);
        await prefs.setDouble(_prefsCarrierMinHzKey, carrierMinHz);
        await prefs.setDouble(_prefsCarrierMaxHzKey, carrierMaxHz);
        await prefs.setDouble(_prefsTauMicrosKey, tauMicros);
        await prefs.setBool(_prefsCalibrationLockedKey, calibrationLocked);

        await prefs.setDouble(_prefsPulseWidthCyclesKey, pulseWidthCycles);
        await prefs.setDouble(
          _prefsPulseRiseTimeCyclesKey,
          pulseRiseTimeCycles,
        );
        await prefs.setDouble(
          _prefsPulseIntervalRandomKey,
          pulseIntervalRandomPercent,
        );

        await prefs.setDouble(_prefsCal3NeutralKey, cal3Neutral);
        await prefs.setDouble(_prefsCal3RightKey, cal3Right);
        await prefs.setDouble(_prefsCal3CenterKey, cal3Center);
        await prefs.setDouble(_prefsCal4AKey, cal4A);
        await prefs.setDouble(_prefsCal4BKey, cal4B);
        await prefs.setDouble(_prefsCal4CKey, cal4C);
        await prefs.setDouble(_prefsCal4DKey, cal4D);

        await prefs.setDouble(_prefsPulseMinHzKey, pulseMinHz);
        await prefs.setDouble(_prefsPulseMaxHzKey, pulseMaxHz);
        await prefs.setBool(_prefsManualPulseModeKey, manualPulseMode);
        await prefs.setDouble(_prefsManualPulseHzKey, manualPulseHz);
        await prefs.setDouble(_prefsManualAlphaKey, manualAlpha);
        await prefs.setDouble(_prefsManualBetaKey, manualBeta);
        await prefs.setDouble(_prefsManualE1Key, manualE1);
        await prefs.setDouble(_prefsManualE2Key, manualE2);
        await prefs.setDouble(_prefsManualE3Key, manualE3);
        await prefs.setDouble(_prefsManualE4Key, manualE4);
        await prefs.setBool(
          _prefsManualCarrierLfoEnabledKey,
          carrierLfoEnabled,
        );
        await prefs.setDouble(
          _prefsManualCarrierLfoRateHzKey,
          carrierLfoRateHz,
        );
        await prefs.setDouble(_prefsManualCarrierLfoDepthKey, carrierLfoDepth);
        await prefs.setBool(_prefsManualPulseLfoEnabledKey, pulseLfoEnabled);
        await prefs.setDouble(_prefsManualPulseLfoRateHzKey, pulseLfoRateHz);
        await prefs.setDouble(_prefsManualPulseLfoDepthKey, pulseLfoDepth);
        await prefs.setBool(_prefsManualCarrierLockedKey, carrierLocked);
        await prefs.setBool(_prefsManualPulseLockedKey, pulseLocked);
        await prefs.setDouble(_prefsManualIntensityKey, manualIntensity);
        await prefs.setDouble(_prefsBassMonitorLowHzKey, bassMonitorLowHz);
        await prefs.setDouble(_prefsBassMonitorHighHzKey, bassMonitorHighHz);
        await prefs.setDouble(_prefsOnsetSensMinKey, onsetSensitivityMin);
        await prefs.setDouble(_prefsOnsetSensMaxKey, onsetSensitivityMax);
        await prefs.setDouble(_prefsOnsetSmoothingKey, onsetSmoothing);
        await prefs.setString(
          _prefsOnsetBandMapE1Key,
          _serializeOnsetBands(onsetBandMapping[0]),
        );
        await prefs.setString(
          _prefsOnsetBandMapE2Key,
          _serializeOnsetBands(onsetBandMapping[1]),
        );
        await prefs.setString(
          _prefsOnsetBandMapE3Key,
          _serializeOnsetBands(onsetBandMapping[2]),
        );
        await prefs.setString(
          _prefsOnsetBandMapE4Key,
          _serializeOnsetBands(onsetBandMapping[3]),
        );
        await prefs.setBool(_prefsImuStreamingEnabledKey, imuStreamingEnabled);
        await prefs.setBool(
          _prefsTempoUnlockHoldEnabledKey,
          tempoUnlockHoldEnabled,
        );
        await prefs.setDouble(
          _prefsEnergyResponseStrengthKey,
          energyResponseStrength,
        );
        await prefs.setDouble(
          _prefsLatencyCompensationMsKey,
          latencyCompensationMs,
        );
        await prefs.setBool(_prefsAdaptiveLeadEnabledKey, adaptiveLeadEnabled);
        await prefs.setBool(_prefsLearningEnabledKey, learningEnabled);
        await prefs.setDouble(_prefsLearningStrengthKey, learningStrength);
        await prefs.setDouble(
          _prefsBeatRadiusAwareContrastStrengthKey,
          beatRadiusAwareContrastStrength,
        );
        await prefs.setDouble(
          _prefsBeatSpeedThresholdSpreadStrengthKey,
          beatSpeedThresholdSpreadStrength,
        );
        await prefs.setString(_prefsBeatCurveE1Key, _beatCurveAt(0).name);
        await prefs.setString(_prefsBeatCurveE2Key, _beatCurveAt(1).name);
        await prefs.setString(_prefsBeatCurveE3Key, _beatCurveAt(2).name);
        await prefs.setString(_prefsBeatCurveE4Key, _beatCurveAt(3).name);
        await prefs.setBool(_prefsHardFillGateEnabledKey, hardFillGateEnabled);
        await prefs.setDouble(
          _prefsAdaptiveLeadCorrectionGainKey,
          adaptiveLeadCorrectionGain,
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[UserSettings] Failed to persist settings: $error\n$stackTrace',
        );
        // Ignore persistence failures.
      }
    });
  }

  void dispose() {
    _persistTimer?.cancel();
  }

  String _serializeOnsetBands(List<AudioBand> bands) {
    return bands.map((AudioBand band) => band.name).join(',');
  }

  List<AudioBand> _parseOnsetBands(String raw) {
    final List<AudioBand> parsed = <AudioBand>[];
    for (final String token in raw.split(',')) {
      final String name = token.trim();
      if (name.isEmpty) {
        continue;
      }

      AudioBand? matched;
      for (final AudioBand band in AudioBand.values) {
        if (band.name == name) {
          matched = band;
          break;
        }
      }

      if (matched == null || parsed.contains(matched)) {
        continue;
      }
      parsed.add(matched);
      if (parsed.length >= 3) {
        break;
      }
    }
    return parsed;
  }

  BeatResponseCurve? _parseBeatResponseCurve(String? raw) {
    if (raw == null) {
      return null;
    }
    final String name = raw.trim();
    if (name.isEmpty) {
      return null;
    }
    for (final BeatResponseCurve curve in BeatResponseCurve.values) {
      if (curve.name == name) {
        return curve;
      }
    }
    return null;
  }

  BeatResponseCurve _beatCurveAt(int index) {
    if (index < 0 || index >= beatFourPhaseResponseCurves.length) {
      return BeatResponseCurve.linear;
    }
    return beatFourPhaseResponseCurves[index];
  }

  bool _restoreDouble({
    required SharedPreferences prefs,
    required String key,
    required double current,
    required void Function(double value) apply,
  }) {
    final double? next = prefs.getDouble(key);
    if (next == null || next == current) {
      return false;
    }
    apply(next);
    return true;
  }

  bool _restoreBool({
    required SharedPreferences prefs,
    required String key,
    required bool current,
    required void Function(bool value) apply,
  }) {
    final bool? next = prefs.getBool(key);
    if (next == null || next == current) {
      return false;
    }
    apply(next);
    return true;
  }
}
