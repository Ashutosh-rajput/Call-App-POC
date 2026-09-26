import 'dart:async';
import 'package:flutter/services.dart';
import '../models/system_status.dart';

class TelecomService {
  static const MethodChannel _channel = MethodChannel('com.example.call_test/telecom');
  static const EventChannel _eventChannel = EventChannel('com.example.call_test/events');

  static final TelecomService _instance = TelecomService._internal();
  factory TelecomService() => _instance;
  TelecomService._internal() {
    _initEventStream();
  }

  final StreamController<Map<dynamic, dynamic>> _eventStreamController = StreamController.broadcast();
  Stream<Map<dynamic, dynamic>> get eventStream => _eventStreamController.stream;

  final StreamController<Map<String, String>> _logStreamController = StreamController.broadcast();
  Stream<Map<String, String>> get logStream => _logStreamController.stream;

  final StreamController<Map<dynamic, dynamic>> _audioLevelStreamController = StreamController.broadcast();
  Stream<Map<dynamic, dynamic>> get audioLevelStream => _audioLevelStreamController.stream;

  final StreamController<Map<dynamic, dynamic>> _transportStreamController = StreamController.broadcast();
  Stream<Map<dynamic, dynamic>> get transportStream => _transportStreamController.stream;

  void _initEventStream() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final type = event['type'];
        if (type == 'LOG_ENTRY') {
          final logMap = event['log'] as Map<dynamic, dynamic>? ?? {};
          _logStreamController.add({
            'time': logMap['time']?.toString() ?? '',
            'tag': logMap['tag']?.toString() ?? '',
            'message': logMap['message']?.toString() ?? '',
            'level': logMap['level']?.toString() ?? 'INFO',
          });
        } else if (type == 'LIVE_AUDIO_LEVEL') {
          _audioLevelStreamController.add(event['data'] as Map<dynamic, dynamic>? ?? {});
        } else if (type == 'TRANSPORT_PROGRESS' || type == 'TRANSPORT_COMPLETE') {
          _transportStreamController.add({
            'type': type,
            'stats': event['stats'] as Map<dynamic, dynamic>? ?? {},
          });
        } else {
          _eventStreamController.add(event);
        }
      }
    }, onError: (error) {
      _logStreamController.add({
        'time': 'NOW',
        'tag': 'FlutterBridge',
        'message': 'EventChannel error: $error',
        'level': 'ERROR',
      });
    });
  }

  Future<SystemStatus> getSystemStatus() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSystemStatus');
      return SystemStatus.fromMap(res ?? {});
    } catch (e) {
      return SystemStatus(
        sdkInt: 0,
        release: 'Unknown',
        deviceModel: 'Error',
        isApi34Plus: false,
        roleAvailable: false,
        roleHeld: false,
        isPhoneAccountRegistered: false,
        isPhoneAccountEnabled: false,
        isServiceBound: false,
        streamingState: 'ERROR',
        hasActiveStreamingCall: false,
        hasActiveTelecomCall: false,
        permissions: {},
        adbCommands: {},
      );
    }
  }

  Future<Map<dynamic, dynamic>> requestRuntimePermissions() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestRuntimePermissions');
    return res ?? {};
  }

  Future<Map<dynamic, dynamic>> requestRole() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestRole');
    return res ?? {};
  }

  Future<bool> registerPhoneAccount() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('registerPhoneAccount');
    return res?['success'] == true;
  }

  Future<bool> unregisterPhoneAccount() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('unregisterPhoneAccount');
    return res?['success'] == true;
  }

  Future<Map<dynamic, dynamic>> createTestCall({
    String callerName = 'Test Caller',
    String phoneNumber = 'tel:5550199',
    int direction = 1, // 1: Incoming, 2: Outgoing
  }) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('createTestCall', {
      'callerName': callerName,
      'phoneNumber': phoneNumber,
      'direction': direction,
    });
    return res ?? {};
  }

  Future<Map<dynamic, dynamic>> startCallStreaming() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('startCallStreaming');
    return res ?? {};
  }

  Future<Map<dynamic, dynamic>> stopCallStreaming() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('stopCallStreaming');
    return res ?? {};
  }

  Future<Map<dynamic, dynamic>> disconnectActiveCall() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('disconnectActiveCall');
    return res ?? {};
  }

  Future<Map<dynamic, dynamic>> runAudioDiagnostics() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('runAudioDiagnostics');
    return res ?? {};
  }

  Future<bool> startLiveAudioCapture({int sourceId = 7}) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('startLiveAudioCapture', {
      'sourceId': sourceId,
    });
    return res?['success'] == true;
  }

  Future<bool> stopLiveAudioCapture() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('stopLiveAudioCapture');
    return res?['success'] == true;
  }

  Future<bool> startNetworkTransportBenchmark({
    String host = '127.0.0.1',
    int port = 19876,
    int durationSeconds = 8,
  }) async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('startNetworkTransportBenchmark', {
      'host': host,
      'port': port,
      'durationSeconds': durationSeconds,
    });
    return res?['started'] == true;
  }

  Future<bool> stopNetworkTransportBenchmark() async {
    final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('stopNetworkTransportBenchmark');
    return res?['stopped'] == true;
  }

  Future<List<Map<String, String>>> getLogs() async {
    final res = await _channel.invokeMethod<List<dynamic>>('getLogs');
    if (res == null) return [];
    return res.map((item) {
      final m = item as Map<dynamic, dynamic>;
      return {
        'time': m['time']?.toString() ?? '',
        'tag': m['tag']?.toString() ?? '',
        'message': m['message']?.toString() ?? '',
        'level': m['level']?.toString() ?? 'INFO',
      };
    }).toList();
  }

  Future<void> clearLogs() async {
    await _channel.invokeMethod('clearLogs');
  }

  Future<String> getLogFilePath() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getLogFilePath');
      return res?['path']?.toString() ?? 'Unavailable';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> exportLogsToFile() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('exportLogsToFile');
      return res?['path']?.toString() ?? 'Failed to export';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
