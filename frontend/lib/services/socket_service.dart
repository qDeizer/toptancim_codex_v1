import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';
import '../utils/logger.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  IO.Socket? _socket;
  final _cartUpdateController = StreamController<bool>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _mediaUpdateController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get cartUpdates => _cartUpdateController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  Stream<Map<String, dynamic>> get mediaUpdates => _mediaUpdateController.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (_socket != null && _socket!.connected) {
      disconnect();
    }

    String baseUrl = Constants.baseUrl;
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.replaceAll('/api', '');
    }

    AppLogger.info('Socket connecting to $baseUrl');

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .enableAutoConnect()
        .setReconnectionAttempts(100)
        .setReconnectionDelay(1000)
        .build());

    if (!_socket!.connected) {
      _socket!.connect();
    }

    _socket!.onConnect((_) {
      AppLogger.info('Socket connected: ${_socket!.id}');
      _cartUpdateController.add(true);
    });

    _socket!.onDisconnect((_) {
      AppLogger.warning('Socket disconnected');
    });

    _socket!.on('cart_updated', (data) {
      AppLogger.info('Cart updated event received: $data');
      _cartUpdateController.add(true);
    });

    _socket!.on('notification', (data) {
      AppLogger.info('Notification event received: $data');
      _notificationController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('media_updated', (data) {
      AppLogger.info('Media updated event received: $data');
      _mediaUpdateController.add(Map<String, dynamic>.from(data ?? {}));
    });

    _socket!.onError((data) => AppLogger.error('Socket error: $data'));
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
  }

  void dispose() {
    _cartUpdateController.close();
    _notificationController.close();
    _mediaUpdateController.close();
    disconnect();
  }
}
