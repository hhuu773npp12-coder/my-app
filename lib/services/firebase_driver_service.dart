// lib/services/firebase_driver_service.dart
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart'; // لإستخدام debugPrint

class DriverLocationService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  Timer? _locationTimer;

  DatabaseReference driverLocationRef(String driverId) =>
      _db.ref('drivers/$driverId/location');

  /// تحديث الموقع الحالي للسائق
  Future<void> updateLocation(String driverId, double lat, double lng) async {
    await driverLocationRef(driverId).set({
      'lat': lat,
      'lng': lng,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// حذف الموقع عند توقف الخدمة
  Future<void> clearLocation(String driverId) async {
    await driverLocationRef(driverId).remove();
    _locationTimer?.cancel();
  }

  /// بدء التحديث التلقائي كل [interval] ثواني
  void startUpdatingLocation(String driverId, {int interval = 5}) {
    _locationTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await updateLocation(driverId, position.latitude, position.longitude);
      } catch (e) {
        debugPrint("⚠️ خطأ في تحديث الموقع: $e");
      }
    });
  }

  /// إيقاف التحديث التلقائي
  void stopUpdatingLocation() {
    _locationTimer?.cancel();
  }

  /// الاستماع لتغير موقع السائق في الوقت الفعلي
  Stream<Map<String, dynamic>?> listenToDriver(String driverId) {
    return driverLocationRef(driverId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return {
          'lat': (data['lat'] as num).toDouble(),
          'lng': (data['lng'] as num).toDouble(),
          'ts': data['ts'],
        };
      }
      return null;
    });
  }
}
