enum StimMode { beat, onset }

/// Trigger type determines orbit speed and motion character.
enum TriggerKind { syncopation, beat, downbeat, fill }

enum TransientProfile { bassDominant, neutral, noFeatures }

enum BeatResponseCurve { linear, ease, bell }

/// Calibration test patterns for electrode verification.
enum CalibrationPattern {
  none,
  circle,
  circleReverse,
  sequential1234,
  sequential4321,
  manual,
}

/// The seven spectral bands exposed by [AudioFeatures].
enum AudioBand { subBass, bass, lowMid, mid, upperMid, presence, brilliance }

/// The factory default 4-phase onset band mapping.
/// Index 0 = E1 (A), 1 = E2 (B), 2 = E3 (C), 3 = E4 (D).
const List<List<AudioBand>> defaultOnsetBandMapping = <List<AudioBand>>[
  <AudioBand>[AudioBand.mid, AudioBand.upperMid, AudioBand.presence],
  <AudioBand>[AudioBand.lowMid, AudioBand.mid],
  <AudioBand>[AudioBand.bass, AudioBand.lowMid],
  <AudioBand>[AudioBand.subBass, AudioBand.bass],
];

const List<BeatResponseCurve> defaultBeatFourPhaseResponseCurves =
    <BeatResponseCurve>[
      BeatResponseCurve.linear,
      BeatResponseCurve.linear,
      BeatResponseCurve.linear,
      BeatResponseCurve.linear,
    ];
