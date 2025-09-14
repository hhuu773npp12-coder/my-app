import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// خدمة إدارة الموقع الجغرافي
/// توفر وظائف شاملة للتعامل مع المواقع والخرائط
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  /// التحقق من صلاحيات الموقع وطلبها إذا لزم الأمر
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // التحقق من تفعيل خدمة الموقع
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('خدمة الموقع غير مفعلة. يرجى تفعيلها من الإعدادات.');
    }

    // التحقق من صلاحيات الموقع
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('تم رفض صلاحيات الموقع.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('صلاحيات الموقع مرفوضة نهائياً. يرجى تفعيلها من إعدادات التطبيق.');
    }

    return true;
  }

  /// الحصول على الموقع الحالي
  Future<Position> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeLimit,
  }) async {
    await checkAndRequestPermissions();
    
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: accuracy,
      timeLimit: timeLimit ?? const Duration(seconds: 15),
    );
  }

  /// الحصول على الموقع الحالي كـ LatLng
  Future<LatLng> getCurrentLatLng() async {
    final position = await getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  /// تحويل الإحداثيات إلى عنوان نصي
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
      }
      return 'عنوان غير محدد';
    } catch (e) {
      return 'خطأ في تحديد العنوان';
    }
  }

  /// تحويل العنوان النصي إلى إحداثيات
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations[0].latitude, locations[0].longitude);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// حساب المسافة بين نقطتين (بالكيلومتر)
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    ) / 1000; // تحويل من متر إلى كيلومتر
  }

  /// حساب المسافة بين موقعين LatLng
  double calculateDistanceLatLng(LatLng start, LatLng end) {
    return calculateDistance(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// مراقبة تغييرات الموقع
  Stream<Position> watchPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// التحقق من وجود الموقع ضمن نطاق محدد
  bool isLocationInRange(
    LatLng userLocation,
    LatLng targetLocation,
    double rangeInKm,
  ) {
    double distance = calculateDistanceLatLng(userLocation, targetLocation);
    return distance <= rangeInKm;
  }

  /// الحصول على معلومات مفصلة عن الموقع
  Future<LocationInfo> getLocationInfo(LatLng location) async {
    final address = await getAddressFromCoordinates(
      location.latitude,
      location.longitude,
    );
    
    return LocationInfo(
      coordinates: location,
      address: address,
      timestamp: DateTime.now(),
    );
  }

  /// تنسيق الإحداثيات للعرض
  String formatCoordinates(LatLng location, {int precision = 6}) {
    return '${location.latitude.toStringAsFixed(precision)}, ${location.longitude.toStringAsFixed(precision)}';
  }

  /// التحقق من صحة الإحداثيات
  bool isValidCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  /// إنشاء رابط خرائط جوجل
  String generateGoogleMapsUrl(LatLng location, {String? label}) {
    final lat = location.latitude;
    final lng = location.longitude;
    final labelParam = label != null ? '($label)' : '';
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng$labelParam';
  }

  /// حفظ الموقع المفضل
  Future<void> saveFavoriteLocation(String name, LatLng location) async {
    // يمكن تطوير هذه الوظيفة لحفظ المواقع في قاعدة البيانات المحلية
    // أو في Firebase حسب احتياجات التطبيق
  }

  /// الحصول على المواقع المفضلة
  Future<List<FavoriteLocation>> getFavoriteLocations() async {
    // يمكن تطوير هذه الوظيفة لاسترجاع المواقع المحفوظة
    return [];
  }
}

/// فئة معلومات الموقع
class LocationInfo {
  final LatLng coordinates;
  final String address;
  final DateTime timestamp;

  LocationInfo({
    required this.coordinates,
    required this.address,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': coordinates.latitude,
      'longitude': coordinates.longitude,
      'address': address,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationInfo.fromMap(Map<String, dynamic> map) {
    return LocationInfo(
      coordinates: LatLng(map['latitude'], map['longitude']),
      address: map['address'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

/// فئة الموقع المفضل
class FavoriteLocation {
  final String id;
  final String name;
  final LatLng coordinates;
  final String? description;
  final DateTime createdAt;

  FavoriteLocation({
    required this.id,
    required this.name,
    required this.coordinates,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': coordinates.latitude,
      'longitude': coordinates.longitude,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FavoriteLocation.fromMap(Map<String, dynamic> map) {
    return FavoriteLocation(
      id: map['id'],
      name: map['name'],
      coordinates: LatLng(map['latitude'], map['longitude']),
      description: map['description'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

/// استثناءات خدمة الموقع
class LocationServiceException implements Exception {
  final String message;
  final String? code;

  LocationServiceException(this.message, {this.code});

  @override
  String toString() => 'LocationServiceException: $message';
}
