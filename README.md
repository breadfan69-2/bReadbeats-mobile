# bREadbeats Mobile

A Flutter-based Android app that brings audio-reactive haptic feedback to your FOC-Stim V4 device over WiFi. The app interprets music in real-time, detecting beat and onset information to control electrode stimulation patterns—turning songs into physical sensations.

## First Connection Setup

When you launch the app for the first time, you'll walk through a quick setup wizard:

**

1. **Network Security** – A heads-up that FOC-Stim communicates over unencrypted WiFi. Keep your device on a trusted network.

2. **Device Connection** – Enter your FOC-Stim's IP address and port (default: 55533). The app tests the connection right away, so you'll know immediately if the setup works.

3. **Calibration** – Run a quick test to verify your electrode setup and make sure everything's responding. After setup completes, you can skip this step anytime by tapping the calibration tile.

Once you finish, the wizard saves your preferences and you won't see it again. To reconfigure your device IP or redo calibration later, tap the connection or calibration tiles from the home screen.

## Stim Modes: Beat vs. Onset

The app offers two interpretations of music, selectable from the stim pattern tile:

### Beat Mode
Follows the detected downbeats and tempo of a song. Think of it as the "steady pulse" — the app locks onto the rhythm and delivers stimulation synchronized with the drums or main groove. Works best with music that has a clear, consistent beat. The sensation tracks the energy of the kick drum and bass.

### Onset Mode
Triggers on transient attacks. Onsets are mapped to frequency bands, so high-frequency hits feel different from low-frequency rumbles. In 3-phase, the app uses stereo L/R bias to create left-right panning sensations.

In 4-phase onset mode, each electrode is driven by one or more frequency bands, and the mapping is **user-configurable**. Open the stim pattern screen while in 4-phase onset to assign up to 3 bands per electrode from 7 available (sub-bass through brilliance). Changes apply on the next heartbeat tick without stopping the session.

#### Key Difference
- **Beat mode** = continuous, syncopated stimulation anchored to tempo
- **Onset mode** = reactive pulses triggered by acoustic details, more dynamic and texture-focused



## Mode Switching

**Important:** When you switch between beat and onset modes (or between 3-phase and 4-phase), the app stops the current session. The device connection stays alive, but audio capture halts. This ensures a clean state transition and prevents overlapping audio streams or confused stimulation patterns.

After switching, start the session again to resume interpretation with the new mode active.

## 3-Phase vs. 4-Phase Output

The app supports both electrode configurations:

- **3-phase** – Uses a circular 2D arrangement, creating smooth rotational patterns. Stereo audio bias creates left/right motion across the circle.
- **4-phase** – Uses a tetrahedron (3D), enabling more spatial precision. In onset mode, spectral bands map directly to the four electrode vertices for immersive frequency-sweep effects.

Select your output mode from the calibration tile. The phase visualizer shows real-time electrode intensity as a circle (3-phase) or tetrahedron (4-phase).

## Hardware Button Functions

The FOC-Stim device has a single encoder button. Here's what it does when connected to BB MObile:

- **Single click** – No effect (reserved for future use)
- **Triple click** (click-click-click) – Toggle volume lock on/off.  
- **Long press** (click/hold >1500ms) – Soft mute. Stimulation stops immediately, but the session stays active. Release to resume.
- **Click then hold** (click-click/hold >600ms) – Disconnect from the app and stop the session entirely.

The app displays button state and volume level in the telemetry tile, so you can see what's happening on the device side in real-time. Button actions trigger haptic feedback on your phone so you get confirmation without looking at the screen.

## Home Screen

The home screen is organized into tiles:

- **Phase Visualizer** – Real-time electrode intensity display (circle for 3-phase, tetrahedron for 4-phase).
- **Session Tile** – Start/stop the session. Tap for stim pattern details (beat/onset mode, 3/4-phase, and in 4-phase onset, user band mapping).
- **Audio Tile** – Pick which app's audio to capture (Spotify, YouTube, etc.). 
The app uses Android's app-specific audio capture, not the microphone or system mix. Shows level and silence-gate status while capture is active.
- **Carrier Freq Tile** – Adjust carrier frequency (Hz).
- **Connection Tile** – Shows WiFi status, battery level, and device volume.
- **Pulse Freq Tile** – Set pulse frequency mode (auto/manual) and range.
- **Beat Intelligence Tile** – Toggle adaptive learning features: tempo unlock hold, adaptive lead, hard fill gate.
- **Telemetry Tile** – Pages through live device measurements: resistance, reactance, RMS current, peak current, and power.
- **Calibration Tile** – Run calibration patterns and select 3-phase/4-phase output.
- **Manual Mode Tile** – Launch the manual control surface (see below).

If the connection drops due to bad IP, timeout, or firmware mismatch, the app shows an error and pushes you to the device settings screen so you can fix it. If audio capture hits a permissions or projection issue, a snackbar appears with a "Fix" action to jump to the audio settings.

## Manual Mode

Manual mode gives you direct touch control over electrode stimulation, bypassing audio-reactive processing entirely. Tap the manual mode tile on the home screen to enter a full-screen, landscape-locked instrument surface.

- **Touch pad** – Drag to move the stimulation position across the phase space (velocity-capped for safety). The pad reflects your current phase configuration (circle or tetrahedron).
- **Carrier & Pulse frequency** – Adjustable from the manual surface.
- **LFO controls** – Low-frequency oscillators for carrier and pulse frequency modulation.
- **Session control** – Start/stop from within manual mode; the session does not auto-start on entry.
- **Calibration access** – Available via an overlay button without leaving manual mode.

Position, frequency, and LFO settings persist across sessions.

## Stability Notes

- The app requires **Android 11+** and specific audio permissions. Grant them when prompted.  NOTE:  Android has only one 'capture' permission, which includes screen capture.   Breadbeats Mobile does NOT capture screen, only audio of the specific app selected.
- WiFi should be stable and low-latency. Latency spikes can cause stuttering.


---

**Got questions or issues?** Check the device connection first (IP, port, network), verify permissions are granted, and make sure your FOC-Stim firmware is up to date and properly working with restim.
