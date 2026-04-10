import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../network/api_client.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // تتبع الموقف (GPS الراكب)
  bool _isTracking = false;
  Map<String, dynamic>? _targetStation;
  StreamSubscription<Position>? _trackingSub;

  // تتبع الوجهة (موقع الباص)
  bool _isTrackingDestination = false;
  Map<String, dynamic>? _destinationStation;
  int? _trackedBusId;
  Timer? _destinationTimer;
  bool _destinationNotified = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
      await _localNotifications.initialize(const InitializationSettings(android: android, iOS: ios));
      await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      // Set audio mode
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _initialized = true;
    } catch (_) {}
  }

  Future<void> showNotification({required String title, required String body}) async {
    if (!_initialized) await init();
    try {
      const androidDetails = AndroidNotificationDetails(
        'bus_app_channel', 'إشعارات الباصات',
        channelDescription: 'إشعارات نظام الباصات',
        importance: Importance.high, priority: Priority.high,
        playSound: true, enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (_) {}
  }

  Future<void> playArrivalSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/mixkit-happy-bells-notification-937.wav'));
    } catch (_) {}
  }

  /// صوت + إشعار معاً
  Future<void> alertUser({required String title, required String body}) async {
    await playArrivalSound();
    await Future.delayed(const Duration(milliseconds: 200));
    await showNotification(title: title, body: body);
  }

  Future<bool> requestPermission() async {
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  // ═══ تتبع الموقف ═══
  void startTracking(Map<String, dynamic> station) {
    _targetStation = station;
    _isTracking = true;
    _trackLocation();
  }

  void stopTracking() {
    _isTracking = false;
    _targetStation = null;
    _trackingSub?.cancel();
  }

  bool get isTracking => _isTracking;
  Map<String, dynamic>? get targetStation => _targetStation;

  Future<void> _trackLocation() async {
    if (_targetStation == null) return;
    final ok = await requestPermission();
    if (!ok) return;
    bool notified = false;

    _trackingSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50),
    ).listen((Position pos) {
      if (!_isTracking || _targetStation == null) return;
      final sLat = (_targetStation!['lat'] is int) ? (_targetStation!['lat'] as int).toDouble() : _targetStation!['lat'] as double;
      final sLng = (_targetStation!['lng'] is int) ? (_targetStation!['lng'] as int).toDouble() : _targetStation!['lng'] as double;
      final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, sLat, sLng);
      if (dist <= 500 && !notified) {
        notified = true;
        alertUser(title: '🚌 اقتربت من موقفك!', body: 'أنت على بعد ${dist.toInt()} متر من ${_targetStation!['name']}');
      }
      if (dist > 1000) notified = false;
    });
  }

  // ═══ تتبع الوجهة ═══
  void startDestinationTracking({required int busId, required Map<String, dynamic> destinationStation}) {
    _trackedBusId = busId;
    _destinationStation = destinationStation;
    _isTrackingDestination = true;
    _destinationNotified = false;
    _destinationTimer?.cancel();
    _destinationTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkBusNearDestination());
    _checkBusNearDestination();
  }

  void stopDestinationTracking() {
    _isTrackingDestination = false;
    _destinationStation = null;
    _trackedBusId = null;
    _destinationNotified = false;
    _destinationTimer?.cancel();
  }

  bool get isTrackingDestination => _isTrackingDestination;
  Map<String, dynamic>? get destinationStation => _destinationStation;

  Future<void> _checkBusNearDestination() async {
    if (!_isTrackingDestination || _trackedBusId == null || _destinationStation == null) return;
    try {
      final api = ApiClient();
      final res = await api.dio.get('/buses/$_trackedBusId');
      final bus = res.data;
      if (bus['current_lat'] == null || bus['current_lng'] == null) return;
      final bLat = (bus['current_lat'] is int) ? (bus['current_lat'] as int).toDouble() : bus['current_lat'] as double;
      final bLng = (bus['current_lng'] is int) ? (bus['current_lng'] as int).toDouble() : bus['current_lng'] as double;
      final dLat = (_destinationStation!['lat'] is int) ? (_destinationStation!['lat'] as int).toDouble() : _destinationStation!['lat'] as double;
      final dLng = (_destinationStation!['lng'] is int) ? (_destinationStation!['lng'] as int).toDouble() : _destinationStation!['lng'] as double;
      final dist = Geolocator.distanceBetween(bLat, bLng, dLat, dLng);
      if (dist <= 800 && !_destinationNotified) {
        _destinationNotified = true;
        alertUser(title: '📍 اقتربت من وجهتك!', body: 'الباص على بعد ${dist.toInt()} متر من ${_destinationStation!['name']} — جهّز حالك للنزول');
      }
      if (dist > 1500) _destinationNotified = false;
    } catch (_) {}
  }
}
