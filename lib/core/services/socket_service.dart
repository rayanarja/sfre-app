import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'notification_service.dart';

/// SocketService — يتصل بالسيرفر عبر Socket.IO ويشغل الإشعارات بالفورغراوند
/// 
/// أضف هالسطر لـ pubspec.yaml:
///   socket_io_client: ^3.0.2
///
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _connected = false;

  bool get isConnected => _connected;

  /// اتصل بالسيرفر
  Future<void> connect() async {
    if (_socket != null && _connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final role = prefs.getString(AppConstants.roleKey) ?? 'passenger';
    final userId = prefs.getInt('user_id');
    final driverId = prefs.getInt('driver_id');

    // الـ baseUrl فيها /api — شيلها للسوكت
    final socketUrl = AppConstants.baseUrl.replaceAll('/api', '');

    _socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .setExtraHeaders({'Authorization': 'Bearer $token'})
      .build());

    _socket!.onConnect((_) {
      _connected = true;
      // عرّف عن حالك
      _socket!.emit('join', {
        'role': role,
        'user_id': userId,
        if (role == 'driver' && driverId != null) 'driver_id': driverId,
      });
    });

    _socket!.onDisconnect((_) => _connected = false);

    // ═══ استمع للإشعارات — صوت + إشعار حتى بالفورغراوند ═══
    _socket!.on('notification', (data) {
      final message = data['message'] ?? '';
      final type = data['type'] ?? 'general';
      String title;
      switch (type) {
        case 'driver':
          title = '🚌 إشعار سائق';
          break;
        case 'passenger':
          title = '📢 إشعار راكب';
          break;
        default:
          title = '🔔 إشعار جديد';
      }
      // صوت + إشعار بالدرابية حتى لو التطبيق مفتوح
      NotificationService().alertUser(title: title, body: message);
    });

    // تحديث موقع الباص (للخريطة)
    _socket!.on('bus:position', (data) {
      // يمكنك إضافة StreamController هون لتحديث الخريطة
    });

    _socket!.connect();
  }

  /// تتبع باص معين
  void trackBus(int busId) {
    _socket?.emit('bus:track', {'bus_id': busId});
  }

  /// وقف تتبع
  void untrackBus(int busId) {
    _socket?.emit('bus:untrack', {'bus_id': busId});
  }

  /// أرسل موقع السائق
  void sendPosition(int busId, double lat, double lng, {int? speed}) {
    _socket?.emit('position:update', {
      'bus_id': busId,
      'lat': lat,
      'lng': lng,
      'speed': speed ?? 0,
    });
  }

  /// فصل
  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _connected = false;
  }
}
