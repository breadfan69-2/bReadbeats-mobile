import '../generated/protobuf/constants.pbenum.dart' as enums;
import '../generated/protobuf/focstim_rpc.pb.dart' as rpc;
import '../generated/protobuf/messages.pb.dart' as msg;
import '../models/device_models.dart';

abstract interface class DeviceTransport {
  Stream<rpc.Notification> get notifications;
  Stream<FocstimConnectionState> get stateStream;
  int get lastResponseMs;
  bool get isConnected;

  Future<void> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  });

  Future<void> disconnect();

  Future<msg.ResponseFirmwareVersion> getFirmwareVersion();
  Future<msg.ResponseCapabilitiesGet> getCapabilities();

  Future<void> startSignal(enums.OutputMode mode);
  Future<void> stopSignal();

  Future<void> startLsm6dsox({
    double imuSamplerateHz = 104.0,
    double accFullscaleG = 4.0,
    double gyrFullscaleDps = 500.0,
  });

  Future<void> stopLsm6dsox();

  Future<void> zeroAllAxes();

  Future<rpc.Response> sendRequest(
    void Function(rpc.Request request) applyRequest, {
    int? timeoutMs,
  });
}