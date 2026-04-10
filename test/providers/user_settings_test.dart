import 'package:breadbeats_mobile/models/device_models.dart';
import 'package:breadbeats_mobile/models/enums.dart';
import 'package:breadbeats_mobile/providers/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('UserSettings restoreFromPreferences loads saved values', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.output_mode': 'threePhase',
      'settings.stim_mode': 'onset',
      'settings.sensitivity': 0.71,
      'settings.intensity_cap': 33.0,
      'settings.carrier_hz': 1400.0,
      'settings.carrier_min_hz': 700.0,
      'settings.carrier_max_hz': 1200.0,
      'settings.tau_micros': 412.0,
      'settings.calibration_locked': false,
      'settings.pulse_width_cycles': 9.0,
      'settings.pulse_rise_time_cycles': 12.0,
      'settings.pulse_interval_random': 25.0,
      'settings.cal3_neutral': 1.0,
      'settings.cal3_right': -0.5,
      'settings.cal3_center': -0.2,
      'settings.cal4_a': 0.4,
      'settings.cal4_b': -0.3,
      'settings.cal4_c': 0.2,
      'settings.cal4_d': -0.1,
      'settings.pulse_min_hz': 12.0,
      'settings.pulse_max_hz': 60.0,
      'settings.manual_pulse_mode': true,
      'settings.manual_pulse_hz': 47.0,
      'settings.bass_monitor_low_hz': 40.0,
      'settings.bass_monitor_high_hz': 220.0,
      'settings.onset_sensitivity_min': 0.15,
      'settings.onset_sensitivity_max': 0.85,
      'settings.onset_smoothing': 22.0,
      'settings.onset_band_map_e1': 'mid,upperMid,presence',
      'settings.onset_band_map_e2': 'bass,brilliance',
      'settings.onset_band_map_e3': 'subBass',
      'settings.onset_band_map_e4': 'presence,mid',
      'settings.imu_streaming_enabled': true,
      'settings.beat_radius_aware_contrast_strength': 0.64,
      'settings.beat_speed_threshold_spread_strength': 0.37,
      'settings.beat_curve_e1': 'bell',
      'settings.beat_curve_e2': 'ease',
      'settings.beat_curve_e3': 'linear',
      'settings.beat_curve_e4': 'bell',
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final UserSettings settings = UserSettings();

    final bool changed = settings.restoreFromPreferences(prefs);

    expect(changed, isTrue);
    expect(settings.outputMode, OutputModeSelection.threePhase);
    expect(settings.stimMode, StimMode.onset);
    expect(settings.sensitivity, closeTo(0.71, 1e-12));
    expect(settings.intensityCap, closeTo(33.0, 1e-12));
    expect(settings.carrierMinHz, closeTo(700.0, 1e-12));
    expect(settings.carrierMaxHz, closeTo(1200.0, 1e-12));
    expect(settings.carrierHz, closeTo(1200.0, 1e-12));
    expect(settings.tauMicros, closeTo(412.0, 1e-12));
    expect(settings.calibrationLocked, isFalse);
    expect(settings.pulseWidthCycles, closeTo(9.0, 1e-12));
    expect(settings.pulseRiseTimeCycles, closeTo(12.0, 1e-12));
    expect(settings.pulseIntervalRandomPercent, closeTo(25.0, 1e-12));
    expect(settings.cal3Neutral, closeTo(1.0, 1e-12));
    expect(settings.cal3Right, closeTo(-0.5, 1e-12));
    expect(settings.cal3Center, closeTo(-0.2, 1e-12));
    expect(settings.cal4A, closeTo(0.4, 1e-12));
    expect(settings.cal4B, closeTo(-0.3, 1e-12));
    expect(settings.cal4C, closeTo(0.2, 1e-12));
    expect(settings.cal4D, closeTo(-0.1, 1e-12));
    expect(settings.pulseMinHz, closeTo(12.0, 1e-12));
    expect(settings.pulseMaxHz, closeTo(60.0, 1e-12));
    expect(settings.manualPulseMode, isTrue);
    expect(settings.manualPulseHz, closeTo(47.0, 1e-12));
    expect(settings.bassMonitorLowHz, closeTo(40.0, 1e-12));
    expect(settings.bassMonitorHighHz, closeTo(220.0, 1e-12));
    expect(settings.onsetSensitivityMin, closeTo(0.15, 1e-12));
    expect(settings.onsetSensitivityMax, closeTo(0.85, 1e-12));
    expect(settings.onsetSmoothing, closeTo(22.0, 1e-12));
    expect(
      settings.onsetBandMapping,
      equals(<List<AudioBand>>[
        <AudioBand>[AudioBand.mid, AudioBand.upperMid, AudioBand.presence],
        <AudioBand>[AudioBand.bass, AudioBand.brilliance],
        <AudioBand>[AudioBand.subBass],
        <AudioBand>[AudioBand.presence, AudioBand.mid],
      ]),
    );
    expect(settings.imuStreamingEnabled, isTrue);
    expect(settings.beatRadiusAwareContrastStrength, closeTo(0.64, 1e-12));
    expect(settings.beatSpeedThresholdSpreadStrength, closeTo(0.37, 1e-12));
    expect(
      settings.beatFourPhaseResponseCurves,
      equals(<BeatResponseCurve>[
        BeatResponseCurve.bell,
        BeatResponseCurve.ease,
        BeatResponseCurve.linear,
        BeatResponseCurve.bell,
      ]),
    );
  });

  test(
    'UserSettings schedulePersist writes latest values after debounce',
    () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final UserSettings settings = UserSettings();

      settings.outputMode = OutputModeSelection.threePhase;
      settings.stimMode = StimMode.onset;
      settings.sensitivity = 0.2;
      settings.schedulePersist(sharedPreferences: prefs);

      settings.sensitivity = 0.73;
      settings.intensityCap = 29.0;
      settings.tauMicros = 288.0;
      settings.manualPulseMode = true;
      settings.manualPulseHz = 33.0;
      settings.onsetBandMapping = <List<AudioBand>>[
        <AudioBand>[AudioBand.bass, AudioBand.mid],
        <AudioBand>[AudioBand.lowMid],
        <AudioBand>[AudioBand.subBass, AudioBand.brilliance],
        <AudioBand>[AudioBand.presence],
      ];
      settings.imuStreamingEnabled = true;
      settings.beatRadiusAwareContrastStrength = 0.46;
      settings.beatSpeedThresholdSpreadStrength = 0.29;
      settings.beatFourPhaseResponseCurves = <BeatResponseCurve>[
        BeatResponseCurve.ease,
        BeatResponseCurve.linear,
        BeatResponseCurve.bell,
        BeatResponseCurve.ease,
      ];
      settings.schedulePersist(sharedPreferences: prefs);

      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(prefs.getString('settings.output_mode'), 'threePhase');
      expect(prefs.getString('settings.stim_mode'), 'onset');
      expect(prefs.getDouble('settings.sensitivity'), closeTo(0.73, 1e-12));
      expect(prefs.getDouble('settings.intensity_cap'), closeTo(29.0, 1e-12));
      expect(prefs.getDouble('settings.tau_micros'), closeTo(288.0, 1e-12));
      expect(prefs.getBool('settings.manual_pulse_mode'), isTrue);
      expect(prefs.getDouble('settings.manual_pulse_hz'), closeTo(33.0, 1e-12));
      expect(prefs.getString('settings.onset_band_map_e1'), 'bass,mid');
      expect(prefs.getString('settings.onset_band_map_e2'), 'lowMid');
      expect(
        prefs.getString('settings.onset_band_map_e3'),
        'subBass,brilliance',
      );
      expect(prefs.getString('settings.onset_band_map_e4'), 'presence');
      expect(prefs.getBool('settings.imu_streaming_enabled'), isTrue);
      expect(
        prefs.getDouble('settings.beat_radius_aware_contrast_strength'),
        closeTo(0.46, 1e-12),
      );
      expect(
        prefs.getDouble('settings.beat_speed_threshold_spread_strength'),
        closeTo(0.29, 1e-12),
      );
      expect(prefs.getString('settings.beat_curve_e1'), 'ease');
      expect(prefs.getString('settings.beat_curve_e2'), 'linear');
      expect(prefs.getString('settings.beat_curve_e3'), 'bell');
      expect(prefs.getString('settings.beat_curve_e4'), 'ease');

      settings.dispose();
    },
  );

  test(
    'UserSettings restoreFromPreferences ignores invalid onset band names',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings.onset_band_map_e1': 'invalidOnly',
        'settings.onset_band_map_e2': 'bass,notARealBand,mid',
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final UserSettings settings = UserSettings();

      final bool changed = settings.restoreFromPreferences(prefs);

      expect(changed, isTrue);
      expect(
        settings.onsetBandMapping[0],
        equals(<AudioBand>[
          AudioBand.mid,
          AudioBand.upperMid,
          AudioBand.presence,
        ]),
      );
      expect(
        settings.onsetBandMapping[1],
        equals(<AudioBand>[AudioBand.bass, AudioBand.mid]),
      );
    },
  );
}
