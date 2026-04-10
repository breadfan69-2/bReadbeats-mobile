// Gate chain constants
const int gateFailThreshold = 12;

// Tempo lock confidence thresholds
const double tempoLockEnterConfidence = 0.20;
const double tempoLockExitConfidence = 0.15;

// Stroke readiness hysteresis
const int strokeGreenThreshold = 3;
const int strokeYellowThreshold = 4;
const int strokeBlockLimit = 3;
const int strokeGracePeriodMs = 450;

// Spectral fill thresholds
const double specFillThresholdBeat = 0.12;
const double specFillThresholdDownbeat = 0.18;
const double specFillThresholdSyncopation = 0.08;
const double specFillSustainBeatSec = 0.18;
const double specFillSustainDownbeatSec = 0.24;
const double specFillSustainSyncopationSec = 0.12;

// Fill mode motion constants
const double fillRotOmega = 31.4;
const double fillBaseRadius = 0.06;
const double fillHhImpulseSize = 0.18;
const double fillHhDecayRate = 8.0;

// Hardware button handling constants
const int buttonHoldThresholdMs = 1500;
const double buttonResumeRampSec = 1.8;
const int tripleClickMaxGapMs = 600;
const int buttonDisconnectHoldMs = 1000;

// Tempo-unlock hold constants
const double tempoUnlockHoldFluxSpikeRatio = 2.0;
const double tempoUnlockHoldFluxDropRatio = 0.25;

// Absolute no-beat timeout (wall-clock)
const int absoluteNoBeatTimeoutMs = 2000;

// Energy fullness modulation of fill gate thresholds
const double energyFillGateReduction = 0.5;

// Bass dominance transient profile
const double bassDominanceMinRatio = 1.95;
const double bassDominanceMinFlux = 0.15;
const double bassDominanceMinFullness = 0.18;
const double bassDominanceNeutralBloomMult = 0.5;
