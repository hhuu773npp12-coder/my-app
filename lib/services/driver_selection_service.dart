import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverSelectionService {
  /// حساب المسافة بين نقطتين باستخدام Haversine formula
  static double calculateDistance(
    double lat1, double lon1, 
    double lat2, double lon2
  ) {
    const double earthRadius = 6371; // نصف قطر الأرض بالكيلومتر
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
  
  /// ترتيب السائقين حسب الأولوية المحسنة (نوع الخدمة + الحالة + القرب + الرصيد)
  static List<Map<String, dynamic>> sortDriversByPriority(
    List<Map<String, dynamic>> drivers,
    double customerLat,
    double customerLon,
    {double maxDistance = 10.0, String? serviceType} // الحد الأقصى للمسافة بالكيلومتر
  ) {
    List<Map<String, dynamic>> eligibleDrivers = [];
    
    // ترتيب أولي حسب نوع الخدمة والحالة
    drivers = _sortByServiceTypeAndStatus(drivers, serviceType);
    
    for (var driver in drivers) {
      // التحقق من وجود الموقع
      if (driver['latitude'] == null || driver['longitude'] == null) {
        continue;
      }
      
      double driverLat = (driver['latitude'] as num).toDouble();
      double driverLon = (driver['longitude'] as num).toDouble();
      
      // حساب المسافة
      double distance = calculateDistance(
        customerLat, customerLon, 
        driverLat, driverLon
      );
      
      // تصفية السائقين ضمن المسافة المحددة
      if (distance <= maxDistance) {
        driver['distance'] = distance;
        
        // حساب نقاط الأولوية
        double priorityScore = _calculatePriorityScore(driver);
        driver['priorityScore'] = priorityScore;
        
        eligibleDrivers.add(driver);
      }
    }
    
    // ترتيب حسب نقاط الأولوية (الأعلى أولاً)
    eligibleDrivers.sort((a, b) => 
      (b['priorityScore'] as double).compareTo(a['priorityScore'] as double)
    );
    
    return eligibleDrivers;
  }
  
  /// ترتيب السائقين حسب نوع الخدمة والحالة أولاً
  static List<Map<String, dynamic>> _sortByServiceTypeAndStatus(
    List<Map<String, dynamic>> drivers, 
    String? targetServiceType
  ) {
    drivers.sort((a, b) {
      // أولوية نوع الخدمة
      bool aMatchesService = targetServiceType == null || 
          (a['serviceType'] == targetServiceType);
      bool bMatchesService = targetServiceType == null || 
          (b['serviceType'] == targetServiceType);
      
      if (aMatchesService != bMatchesService) {
        return aMatchesService ? -1 : 1;
      }
      
      // ثانياً: الحالة النشطة
      bool aActive = a['active'] == true && a['available'] == true;
      bool bActive = b['active'] == true && b['available'] == true;
      
      if (aActive != bActive) {
        return aActive ? -1 : 1;
      }
      
      return 0;
    });
    
    return drivers;
  }
  
  /// حساب نقاط الأولوية المحسنة للسائق
  static double _calculatePriorityScore(Map<String, dynamic> driver) {
    double distance = driver['distance'] ?? 10.0;
    double balance = (driver['balance'] ?? 0).toDouble();
    double rating = (driver['rating'] ?? 3.0).toDouble();
    int completedOrders = driver['completedOrders'] ?? 0;
    bool isActive = driver['active'] == true && driver['available'] == true;
    
    // نقاط الحالة النشطة (مضاعف مهم)
    double statusMultiplier = isActive ? 1.0 : 0.3;
    
    // كلما قلت المسافة، زادت النقاط (نقاط المسافة من 0 إلى 100)
    double distanceScore = max(0, 100 - (distance * 10));
    
    // نقاط الرصيد المحسنة (كل 10000 دينار = 15 نقطة، بحد أقصى 75 نقطة)
    double balanceScore = min(75, (balance / 10000) * 15);
    
    // نقاط التقييم (من 0 إلى 50)
    double ratingScore = (rating / 5.0) * 50;
    
    // نقاط الخبرة (كل 10 طلبات مكتملة = 5 نقاط، بحد أقصى 25 نقطة)
    double experienceScore = min(25, (completedOrders / 10) * 5);
    
    // المجموع الكلي مع مضاعف الحالة
    return (distanceScore + balanceScore + ratingScore + experienceScore) * statusMultiplier;
  }
  
  /// جلب السائقين المناسبين لنوع خدمة معين مع ترتيب محسن
  static Future<List<Map<String, dynamic>>> getAvailableDrivers(
    String serviceType,
    {String? region, bool includeInactive = false}
  ) async {
    Query query = FirebaseFirestore.instance
        .collection("users")
        .where("type", isEqualTo: serviceType);
    
    // إضافة السائقين غير النشطين إذا طُلب ذلك
    if (!includeInactive) {
      query = query.where("active", isEqualTo: true)
                  .where("available", isEqualTo: true);
    }
    
    // إضافة فلتر المنطقة إذا تم تحديدها
    if (region != null && region.isNotEmpty) {
      query = query.where("region", isEqualTo: region);
    }
    
    QuerySnapshot snapshot = await query.get();
    
    return snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }
  
  /// تحديث حالة السائق (متاح/غير متاح)
  static Future<void> updateDriverAvailability(
    String driverId, 
    bool isAvailable
  ) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(driverId)
        .update({"available": isAvailable});
  }
  
  /// إضافة طلب للسائقين المختارين
  static Future<void> assignOrderToDrivers(
    Map<String, dynamic> orderData,
    List<Map<String, dynamic>> selectedDrivers
  ) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    for (var driver in selectedDrivers) {
      DocumentReference assignedOrderRef = 
          FirebaseFirestore.instance.collection("assignedRequests").doc();
      
      batch.set(assignedOrderRef, {
        "serviceRequestId": orderData['id'],
        "driverId": driver['id'],
        "driverName": driver['name'],
        "driverPhone": driver['phone'],
        "driverRating": driver['rating'] ?? 3.0,
        "distance": driver['distance'],
        "priorityScore": driver['priorityScore'],
        "customerName": orderData['customerName'],
        "customerPhone": orderData['customerPhone'],
        "serviceType": orderData['serviceType'],
        "fromLocation": orderData['fromLocation'],
        "toLocation": orderData['toLocation'],
        "mealPrice": orderData['mealPrice'] ?? 0,
        "deliveryFee": orderData['deliveryFee'] ?? 0,
        "serviceFee": orderData['serviceFee'] ?? 1000,
        "totalAmount": orderData['totalAmount'],
        "status": "pending",
        "assignedAt": FieldValue.serverTimestamp(),
        "expiresAt": Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 15))
        ),
      });
    }
    
    await batch.commit();
  }
  
  /// إحصائيات السائق
  static Future<Map<String, dynamic>> getDriverStats(String driverId) async {
    // جلب الطلبات المكتملة
    QuerySnapshot completedOrders = await FirebaseFirestore.instance
        .collection("assignedRequests")
        .where("driverId", isEqualTo: driverId)
        .where("status", isEqualTo: "completed")
        .get();
    
    // جلب التقييمات
    QuerySnapshot ratings = await FirebaseFirestore.instance
        .collection("driverRatings")
        .where("driverId", isEqualTo: driverId)
        .get();
    
    double totalRating = 0;
    int ratingCount = ratings.docs.length;
    
    for (var doc in ratings.docs) {
      totalRating += (doc.data() as Map<String, dynamic>)['rating'] ?? 0;
    }
    
    double averageRating = ratingCount > 0 ? totalRating / ratingCount : 0;
    
    return {
      "completedOrders": completedOrders.docs.length,
      "averageRating": averageRating,
      "totalRatings": ratingCount,
    };
  }
}
