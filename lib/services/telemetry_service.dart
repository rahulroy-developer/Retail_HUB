import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum DeliveryState { EN_ROUTE, ARRIVED_AT_DESTINATION }

class TelemetryService extends ChangeNotifier {
  // Store Outlet A
  static const double targetLat = 22.7625;
  static const double targetLng = 88.3720;
  static const double targetRadiusMeters = 50.0;

  // Telemetry state
  Position? currentPosition;
  double distanceToTarget = double.infinity;
  DeliveryState deliveryState = DeliveryState.EN_ROUTE;
  
  double currentShockMagnitude = 0.0;
  bool shockDetected = false;
  DateTime? _lastShockTime;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;

  TelemetryService() {
    _initLocationStream();
    _initAccelerometerStream();
  }

  Future<void> _initLocationStream() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position != null) {
          currentPosition = position;
          _calculateGeofence(position.latitude, position.longitude);
          notifyListeners();
        }
      },
    );
  }

  void _initAccelerometerStream() {
    _accelSubscription = userAccelerometerEventStream().listen(
      (UserAccelerometerEvent event) {
        double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        currentShockMagnitude = magnitude;

        if (magnitude > 15.0) {
          _handleShock();
        }
        notifyListeners();
      },
    );
  }

  void _handleShock() {
    final now = DateTime.now();
    // 5 seconds cooldown
    if (_lastShockTime == null || now.difference(_lastShockTime!).inSeconds >= 5) {
      shockDetected = true;
      _lastShockTime = now;
      
      // Auto reset shock warning banner after 5 seconds
      Timer(const Duration(seconds: 5), () {
        shockDetected = false;
        notifyListeners();
      });
    }
  }

  // Haversine formula implementation
  void _calculateGeofence(double lat, double lng) {
    const R = 6371e3; // metres
    final phi1 = lat * pi / 180; // φ, λ in radians
    final phi2 = targetLat * pi / 180;
    final deltaPhi = (targetLat - lat) * pi / 180;
    final deltaLambda = (targetLng - lng) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) *
            sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    distanceToTarget = R * c;

    if (distanceToTarget <= targetRadiusMeters) {
      deliveryState = DeliveryState.ARRIVED_AT_DESTINATION;
    } else {
      deliveryState = DeliveryState.EN_ROUTE;
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _accelSubscription?.cancel();
    super.dispose();
  }
}
