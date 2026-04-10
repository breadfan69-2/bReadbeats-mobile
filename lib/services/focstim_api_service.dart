import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import '../core/hdlc.dart';
import '../generated/protobuf/constants.pbenum.dart' as enums;
import '../generated/protobuf/focstim_rpc.pb.dart' as rpc;
import '../generated/protobuf/messages.pb.dart' as msg;
import '../models/device_models.dart';
import '../session/device_transport.dart';

class FocstimApiException implements Exception {
  const FocstimApiException(this.message, {this.code});

  final String message;
  final enums.Errors? code;

  @override
  String toString() {
    if (code == null) {
      return 'FocstimApiException: $message';
    }
    return 'FocstimApiException(${code!.name}): $message';
  }
}

/// Trust boundary note:
/// This transport is intentionally plain TCP for current FOC-Stim firmware.
/// It is only intended for private, user-controlled local WiFi networks.
/// Do not use this app on public/shared networks because traffic is unencrypted
/// and unauthenticated at the transport layer.
class FocstimApiService implements DeviceTransport {
  FocstimApiService({
    this.requestTimeoutMs = 1500,
    this.setupRequestTimeoutMs = 5000,
    this.maxPendingRequests = 20,
  });

  final int requestTimeoutMs;
  final int setupRequestTimeoutMs;
  final int maxPendingRequests;

  final HdlcFramer _framer = HdlcFramer();
  final StreamController<rpc.Notification> _notificationController =
      StreamController<rpc.Notification>.broadcast();
  final StreamController<FocstimConnectionState> _stateController =
      StreamController<FocstimConnectionState>.broadcast();

  final Map<int, _PendingResponse> _pending = <int, _PendingResponse>{};

  Socket? _socket;
  StreamSubscription<List<int>>? _socketSubscription;
  FocstimConnectionState _state = FocstimConnectionState.disconnected;
  int _requestIdCounter = 1;
  int _lastResponseMs = 0;

  /// Wall-clock ms of the last successfully received response from device.
  @override
  int get lastResponseMs => _lastResponseMs;
  int get hdlcDroppedFrameCount => _framer.droppedFrameCount;

  FocstimConnectionState get state => _state;
  @override
  Stream<FocstimConnectionState> get stateStream => _stateController.stream;
  @override
  Stream<rpc.Notification> get notifications => _notificationController.stream;
  @override
  bool get isConnected =>
      _state == FocstimConnectionState.connected && _socket != null;

  @override
  Future<void> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return connectTcp(host, port, timeout: timeout);
  }

  Future<void> connectTcp(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final String normalizedHost = host.trim();
    _validateEndpoint(normalizedHost, port);

    await disconnect();
    _framer.clearDroppedFrameCount();
    _setState(FocstimConnectionState.connecting);

    try {
      final Socket socket = await Socket.connect(
        normalizedHost,
        port,
        timeout: timeout,
      );
      socket.setOption(SocketOption.tcpNoDelay, true);
      _socket = socket;
      _socketSubscription = socket.listen(
        _onSocketData,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: true,
      );
      _lastResponseMs = DateTime.now().millisecondsSinceEpoch;
      _setState(FocstimConnectionState.connected);
    } catch (error) {
      _setState(FocstimConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    _socket?.destroy();
    _socket = null;

    _framer.reset();
    _failPending(const SocketException('Disconnected'));

    if (_state != FocstimConnectionState.disconnected) {
      _setState(FocstimConnectionState.disconnected);
    }
  }

  @override
  Future<msg.ResponseFirmwareVersion> getFirmwareVersion() async {
    final rpc.Response response = await _sendRequest((rpc.Request request) {
      request.requestFirmwareVersion = msg.RequestFirmwareVersion();
    }, timeoutMs: setupRequestTimeoutMs);

    _throwIfRpcError(response);
    if (!response.hasResponseFirmwareVersion()) {
      throw const FocstimApiException(
        'Missing response_firmware_version payload',
      );
    }

    return response.responseFirmwareVersion;
  }

  @override
  Future<msg.ResponseCapabilitiesGet> getCapabilities() async {
    final rpc.Response response = await _sendRequest((rpc.Request request) {
      request.requestCapabilitiesGet = msg.RequestCapabilitiesGet();
    }, timeoutMs: setupRequestTimeoutMs);

    _throwIfRpcError(response);
    if (!response.hasResponseCapabilitiesGet()) {
      throw const FocstimApiException(
        'Missing response_capabilities_get payload',
      );
    }

    return response.responseCapabilitiesGet;
  }

  @override
  Future<void> startSignal(enums.OutputMode mode) async {
    final rpc.Response response = await _sendRequest((rpc.Request request) {
      request.requestSignalStart = msg.RequestSignalStart()..mode = mode;
    }, timeoutMs: setupRequestTimeoutMs);

    _throwIfRpcError(response);
  }

  @override
  Future<void> stopSignal() async {
    final rpc.Response response = await _sendRequest((rpc.Request request) {
      request.requestSignalStop = msg.RequestSignalStop();
    }, timeoutMs: setupRequestTimeoutMs);

    _throwIfRpcError(response);
  }

  Future<void> moveAxis(
    enums.AxisType axis,
    double value,
    int intervalMs, {
    int? timeoutMs,
  }) async {
    if (!value.isFinite) {
      throw const FocstimApiException('Axis value must be finite');
    }

    final int normalizedIntervalMs = intervalMs < 0 ? 0 : intervalMs;
    final int effectiveTimeoutMs =
        timeoutMs ??
        (normalizedIntervalMs == 0 ? setupRequestTimeoutMs : requestTimeoutMs);

    final rpc.Response response = await _sendRequest((rpc.Request request) {
      request.requestAxisMoveTo = msg.RequestAxisMoveTo()
        ..axis = axis
        ..value = value
        ..interval = normalizedIntervalMs;
    }, timeoutMs: effectiveTimeoutMs);

    _throwIfRpcError(response);
  }

  Future<void> lockDeviceVolume(bool lock) async {
    final rpc.Response response = await _sendRequest((rpc.Request request) {
      request.requestLockDeviceVolume = msg.RequestLockDeviceVolume()
        ..lock = lock;
    }, timeoutMs: setupRequestTimeoutMs);

    _throwIfRpcError(response);
  }

  @override
  Future<void> startLsm6dsox({
    double imuSamplerateHz = 104.0,
    double accFullscaleG = 4.0,
    double gyrFullscaleDps = 500.0,
  }) async {
    final rpc.Response response = await _sendRequest((rpc.Request request) {
      request.requestLsm6dsoxStart = msg.RequestLSM6DSOXStart()
        ..imuSamplerate = imuSamplerateHz
        ..accFullscale = accFullscaleG
        ..gyrFullscale = gyrFullscaleDps;
    }, timeoutMs: setupRequestTimeoutMs);

    _throwIfRpcError(response);
  }

  @override
  Future<void> stopLsm6dsox() async {
    final rpc.Response response = await _sendRequest((rpc.Request request) {
      request.requestLsm6dsoxStop = msg.RequestLSM6DSOXStop();
    }, timeoutMs: setupRequestTimeoutMs);

    _throwIfRpcError(response);
  }

  @override
  Future<void> zeroAllAxes() async {
    final List<Future<void>> operations = <Future<void>>[
      moveAxis(enums.AxisType.AXIS_WAVEFORM_AMPLITUDE_AMPS, 0.0, 0),
      moveAxis(enums.AxisType.AXIS_ELECTRODE_1_POWER, 0.0, 0),
      moveAxis(enums.AxisType.AXIS_ELECTRODE_2_POWER, 0.0, 0),
      moveAxis(enums.AxisType.AXIS_ELECTRODE_3_POWER, 0.0, 0),
      moveAxis(enums.AxisType.AXIS_ELECTRODE_4_POWER, 0.0, 0),
      moveAxis(enums.AxisType.AXIS_POSITION_ALPHA, 0.0, 0),
      moveAxis(enums.AxisType.AXIS_POSITION_BETA, 0.0, 0),
    ];

    await Future.wait(operations);
  }

  @override
  Future<rpc.Response> sendRequest(
    void Function(rpc.Request request) applyRequest, {
    int? timeoutMs,
  }) {
    return _sendRequest(applyRequest, timeoutMs: timeoutMs);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _notificationController.close();
  }

  Future<rpc.Response> _sendRequest(
    void Function(rpc.Request request) applyRequest, {
    int? timeoutMs,
  }) {
    if (!isConnected || _socket == null) {
      throw const FocstimApiException('Not connected to device');
    }

    if (_pending.length >= maxPendingRequests) {
      throw const FocstimApiException(
        'Too many pending requests; dropping new request',
      );
    }

    final rpc.Request request = rpc.Request()..id = _nextRequestId();
    applyRequest(request);

    final rpc.RpcMessage envelope = rpc.RpcMessage()..request = request;
    final Completer<rpc.Response> completer = Completer<rpc.Response>();

    final int effectiveTimeoutMs = timeoutMs ?? requestTimeoutMs;
    final Timer timeout = Timer(Duration(milliseconds: effectiveTimeoutMs), () {
      final _PendingResponse? pending = _pending.remove(request.id);
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.completeError(
          TimeoutException(
            'Timed out waiting for response id=${request.id} '
            'after ${effectiveTimeoutMs}ms',
          ),
        );
      }
    });

    _pending[request.id] = _PendingResponse(
      completer: completer,
      timeout: timeout,
    );

    try {
      _socket!.add(_framer.encode(envelope.writeToBuffer()));
    } catch (error, stackTrace) {
      final _PendingResponse? pending = _pending.remove(request.id);
      pending?.timeout.cancel();
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }

    return completer.future;
  }

  void _onSocketData(List<int> rawData) {
    final List<Uint8List> frames = _framer.parse(Uint8List.fromList(rawData));

    for (final Uint8List frame in frames) {
      rpc.RpcMessage message;
      try {
        message = rpc.RpcMessage.fromBuffer(frame);
      } catch (error, stackTrace) {
        developer.log(
          'Failed to parse inbound frame',
          name: 'FocstimApiService',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }

      switch (message.whichMessage()) {
        case rpc.RpcMessage_Message.response:
          _handleResponse(message.response);
          break;
        case rpc.RpcMessage_Message.notification:
          _notificationController.add(message.notification);
          break;
        case rpc.RpcMessage_Message.request:
        case rpc.RpcMessage_Message.notSet:
          break;
      }
    }
  }

  void _onSocketError(Object error) {
    _setState(FocstimConnectionState.error);
    _failPending(error);
  }

  void _onSocketDone() {
    unawaited(disconnect());
  }

  void _handleResponse(rpc.Response response) {
    _lastResponseMs = DateTime.now().millisecondsSinceEpoch;
    final _PendingResponse? pending = _pending.remove(response.id);
    if (pending == null) {
      return;
    }

    pending.timeout.cancel();
    if (!pending.completer.isCompleted) {
      pending.completer.complete(response);
    }
  }

  void _throwIfRpcError(rpc.Response response) {
    if (!response.hasError()) {
      return;
    }

    throw FocstimApiException(
      'Device returned error',
      code: response.error.code,
    );
  }

  void _failPending(Object error) {
    for (final _PendingResponse pending in _pending.values) {
      pending.timeout.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error);
      }
    }
    _pending.clear();
  }

  int _nextRequestId() {
    final int id = _requestIdCounter;
    _requestIdCounter++;
    if (_requestIdCounter > 4095) {
      _requestIdCounter = 1;
    }
    return id;
  }

  void _setState(FocstimConnectionState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void _validateEndpoint(String host, int port) {
    if (host.isEmpty) {
      throw const FocstimApiException('Host must not be empty');
    }
    if (port < 1 || port > 65535) {
      throw const FocstimApiException('Port must be in range 1-65535');
    }
    if (!_isValidHost(host)) {
      throw FocstimApiException('Invalid host: $host');
    }
  }

  bool _isValidHost(String host) {
    if (InternetAddress.tryParse(host) != null) {
      return true;
    }
    if (host.length > 253) {
      return false;
    }

    final List<String> labels = host.split('.');
    if (labels.any((String label) => label.isEmpty || label.length > 63)) {
      return false;
    }

    final RegExp hostnameLabel = RegExp(
      r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$',
    );
    return labels.every(hostnameLabel.hasMatch);
  }
}

class _PendingResponse {
  _PendingResponse({required this.completer, required this.timeout});

  final Completer<rpc.Response> completer;
  final Timer timeout;
}
