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

  Stream<bool> get cartUpdates => _cartUpdateController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (_socket != null && _socket!.connected) {
      // If already connected, maybe update auth? 
      // For simplicity, disconnect and reconnect if token changed is safer, 
      // but usually we just init once. 
      // However, if token changes (logout/login), we must reconnect.
      disconnect();
    }

    // Adjust URL if needed (remove /api if it's base)
    // Constants.baseUrl usually includes /api, we need just the host
    // e.g. http://10.0.2.2:3001
    String baseUrl = Constants.baseUrl;
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.replaceAll('/api', '');
    }

    AppLogger.info('Socket connecting to $baseUrl');

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .enableAutoConnect() // Enable auto connect for reconnects
        .setReconnectionAttempts(100)
        .setReconnectionDelay(1000)
        .build());

    if (!_socket!.connected) {
      _socket!.connect();
    }

    _socket!.onConnect((_) {
      AppLogger.info('Socket connected: ${_socket!.id}');
      // Trigger a check on connect to be safe (Double Verification)
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
    disconnect();
  }
}
