enum FocstimConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

enum OutputModeSelection {
  threePhase,
  fourPhase,
}

class FocstimFirmwareVersion {
  const FocstimFirmwareVersion({
    required this.major,
    required this.minor,
    required this.revision,
    required this.branch,
    required this.comment,
    required this.board,
  });

  final int major;
  final int minor;
  final int revision;
  final String branch;
  final String comment;
  final String board;

  String get pretty => '$major.$minor.$revision ($branch)';
}

class FocstimCapabilities {
  const FocstimCapabilities({
    required this.threephase,
    required this.fourphase,
    required this.battery,
    required this.deviceVolume,
    required this.lsm6dsox,
    required this.maximumWaveformAmplitudeAmps,
  });

  final bool threephase;
  final bool fourphase;
  final bool battery;
  final bool deviceVolume;
  final bool lsm6dsox;
  final double maximumWaveformAmplitudeAmps;
}
