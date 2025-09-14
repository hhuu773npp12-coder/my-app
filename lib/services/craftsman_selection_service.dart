import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class CraftsmanSelectionService {
  /// أنواع الحرف المتاحة
  static const Map<String, String> craftTypes = {
    'electrician': 'كهربائي',
    'plumber': 'سباك', 
    'blacksmith': 'حداد',
    'cooling': 'تبريد وتكييف',
    'carpenter': 'نجار',
    'painter': 'دهان',
    'tiler': 'بلاط',
    'mechanic': 'ميكانيكي',
  };

  /// حساب المسافة بين نقطتين
  static double calculateDistance(
    double lat1, double lon1, 
    double lat2, double lon2
  ) {
    const double earthRadius = 6371;
    
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

  /// ترتيب أصحاب الحرف حسب الأولوية
  static List<Map<String, dynamic>> sortCraftsmenByPriority(
    List<Map<String, dynamic>> craftsmen,
    double customerLat,
    double customerLon,
    {double maxDistance = 15.0}
  ) {
    List<Map<String, dynamic>> eligibleCraftsmen = [];
    
    for (var craftsman in craftsmen) {
      if (craftsman['latitude'] == null || craftsman['longitude'] == null) {
        continue;
      }
      
      double craftsmanLat = (craftsman['latitude'] as num).toDouble();
      double craftsmanLon = (craftsman['longitude'] as num).toDouble();
      
      double distance = calculateDistance(
        customerLat, customerLon, 
        craftsmanLat, craftsmanLon
      );
      
      if (distance <= maxDistance) {
        craftsman['distance'] = distance;
        double priorityScore = _calculateCraftsmanPriorityScore(craftsman);
        craftsman['priorityScore'] = priorityScore;
        eligibleCraftsmen.add(craftsman);
      }
    }
    
    eligibleCraftsmen.sort((a, b) => 
      (b['priorityScore'] as double).compareTo(a['priorityScore'] as double)
    );
    
    return eligibleCraftsmen;
  }

  /// حساب نقاط الأولوية لصاحب الحرفة
  static double _calculateCraftsmanPriorityScore(Map<String, dynamic> craftsman) {
    double distance = craftsman['distance'] ?? 15.0;
    double balance = (craftsman['balance'] ?? 0).toDouble();
    double rating = (craftsman['rating'] ?? 3.0).toDouble();
    int completedJobs = craftsman['completedJobs'] ?? 0;
    int yearsExperience = craftsman['yearsExperience'] ?? 0;
    bool hasTools = craftsman['hasTools'] ?? false;
    bool hasTransport = craftsman['hasTransport'] ?? false;
    
    // نقاط المسافة (0-100)
    double distanceScore = max(0, 100 - (distance * 6));
    
    // نقاط الرصيد (0-40)
    double balanceScore = min(40, (balance / 15000) * 10);
    
    // نقاط التقييم (0-50)
    double ratingScore = (rating / 5.0) * 50;
    
    // نقاط الخبرة (0-30)
    double experienceScore = min(30, (completedJobs / 5) * 3 + yearsExperience * 2);
    
    // نقاط إضافية للأدوات والنقل (0-20)
    double bonusScore = 0;
    if (hasTools) bonusScore += 10;
    if (hasTransport) bonusScore += 10;
    
    return distanceScore + balanceScore + ratingScore + experienceScore + bonusScore;
  }

  /// جلب أصحاب الحرف المتاحين
  static Future<List<Map<String, dynamic>>> getAvailableCraftsmen(
    String craftType,
    {String? region, String? specialty}
  ) async {
    Query query = FirebaseFirestore.instance
        .collection("users")
        .where("type", isEqualTo: craftType)
        .where("active", isEqualTo: true)
        .where("available", isEqualTo: true);
    
    if (region != null && region.isNotEmpty) {
      query = query.where("region", isEqualTo: region);
    }
    
    if (specialty != null && specialty.isNotEmpty) {
      query = query.where("specialty", isEqualTo: specialty);
    }
    
    QuerySnapshot snapshot = await query.get();
    
    return snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// جلب إحصائيات صاحب الحرفة
  static Future<Map<String, dynamic>> getCraftsmanStats(String craftsmanId) async {
    // الأعمال المكتملة
    QuerySnapshot completedJobs = await FirebaseFirestore.instance
        .collection("assignedRequests")
        .where("craftsmanId", isEqualTo: craftsmanId)
        .where("status", isEqualTo: "completed")
        .get();
    
    // التقييمات
    QuerySnapshot ratings = await FirebaseFirestore.instance
        .collection("craftsmanRatings")
        .where("craftsmanId", isEqualTo: craftsmanId)
        .get();
    
    double totalRating = 0;
    int ratingCount = ratings.docs.length;
    
    for (var doc in ratings.docs) {
      totalRating += (doc.data() as Map<String, dynamic>)['rating'] ?? 0;
    }
    
    double averageRating = ratingCount > 0 ? totalRating / ratingCount : 0;
    
    // حساب الأرباح الشهرية
    DateTime now = DateTime.now();
    DateTime monthStart = DateTime(now.year, now.month, 1);
    
    QuerySnapshot monthlyJobs = await FirebaseFirestore.instance
        .collection("assignedRequests")
        .where("craftsmanId", isEqualTo: craftsmanId)
        .where("status", isEqualTo: "completed")
        .where("completedAt", isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .get();
    
    double monthlyEarnings = 0;
    for (var doc in monthlyJobs.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      monthlyEarnings += (data['craftsmanFee'] ?? 0).toDouble();
    }
    
    return {
      "completedJobs": completedJobs.docs.length,
      "averageRating": averageRating,
      "totalRatings": ratingCount,
      "monthlyEarnings": monthlyEarnings,
      "monthlyJobs": monthlyJobs.docs.length,
    };
  }

  /// تخصيص عمل لأصحاب الحرف
  static Future<void> assignJobToCraftsmen(
    Map<String, dynamic> jobData,
    List<Map<String, dynamic>> selectedCraftsmen
  ) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    for (var craftsman in selectedCraftsmen) {
      DocumentReference assignedJobRef = 
          FirebaseFirestore.instance.collection("assignedRequests").doc();
      
      batch.set(assignedJobRef, {
        "serviceRequestId": jobData['id'],
        "craftsmanId": craftsman['id'],
        "craftsmanName": craftsman['name'],
        "craftsmanPhone": craftsman['phone'],
        "craftsmanRating": craftsman['rating'] ?? 3.0,
        "craftsmanType": craftsman['type'],
        "distance": craftsman['distance'],
        "priorityScore": craftsman['priorityScore'],
        "customerName": jobData['customerName'],
        "customerPhone": jobData['customerPhone'],
        "customerAddress": jobData['customerAddress'],
        "serviceType": jobData['serviceType'],
        "jobDescription": jobData['jobDescription'],
        "urgencyLevel": jobData['urgencyLevel'] ?? 'normal',
        "estimatedDuration": jobData['estimatedDuration'],
        "budgetRange": jobData['budgetRange'],
        "craftsmanFee": jobData['craftsmanFee'] ?? 0,
        "serviceFee": jobData['serviceFee'] ?? 2000,
        "totalAmount": jobData['totalAmount'],
        "status": "pending",
        "assignedAt": FieldValue.serverTimestamp(),
        "expiresAt": Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 2))
        ),
        "requiresTools": jobData['requiresTools'] ?? false,
        "requiresTransport": jobData['requiresTransport'] ?? false,
      });
    }
    
    await batch.commit();
  }

  /// الحصول على التخصصات حسب نوع الحرفة
  static List<String> getSpecialtiesByType(String craftType) {
    switch (craftType) {
      case 'electrician':
        return [
          'كهرباء منزلية',
          'كهرباء صناعية', 
          'إنارة',
          'مولدات',
          'تمديدات',
          'صيانة أجهزة'
        ];
      case 'plumber':
        return [
          'سباكة منزلية',
          'تسليك مجاري',
          'تركيب خزانات',
          'صيانة مضخات',
          'تمديدات مياه',
          'إصلاح تسريبات'
        ];
      case 'blacksmith':
        return [
          'حدادة عامة',
          'أبواب ونوافذ',
          'درابزين',
          'بوابات',
          'هياكل معدنية',
          'لحام'
        ];
      case 'cooling':
        return [
          'تكييف مركزي',
          'تكييف شباك',
          'تكييف سبليت',
          'تبريد تجاري',
          'صيانة مبردات',
          'تركيب وحدات'
        ];
      default:
        return ['عام'];
    }
  }

  /// تحديث حالة صاحب الحرفة
  static Future<void> updateCraftsmanAvailability(
    String craftsmanId, 
    bool isAvailable
  ) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(craftsmanId)
        .update({"available": isAvailable});
  }

  /// البحث عن أصحاب الحرف بالفلاتر المتقدمة
  static Future<List<Map<String, dynamic>>> searchCraftsmenWithFilters({
    required String craftType,
    String? region,
    String? specialty,
    double? minRating,
    int? maxDistance,
    bool? hasTools,
    bool? hasTransport,
    String? priceRange,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection("users")
        .where("type", isEqualTo: craftType)
        .where("active", isEqualTo: true)
        .where("available", isEqualTo: true);
    
    if (region != null) {
      query = query.where("region", isEqualTo: region);
    }
    
    if (specialty != null) {
      query = query.where("specialty", isEqualTo: specialty);
    }
    
    if (minRating != null) {
      query = query.where("rating", isGreaterThanOrEqualTo: minRating);
    }
    
    if (hasTools != null) {
      query = query.where("hasTools", isEqualTo: hasTools);
    }
    
    if (hasTransport != null) {
      query = query.where("hasTransport", isEqualTo: hasTransport);
    }
    
    QuerySnapshot snapshot = await query.get();
    
    List<Map<String, dynamic>> results = snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
    
    // فلترة إضافية للمسافة ونطاق السعر
    if (maxDistance != null || priceRange != null) {
      results = results.where((craftsman) {
        bool passesFilter = true;
        
        if (maxDistance != null && craftsman['distance'] != null) {
          passesFilter = passesFilter && craftsman['distance'] <= maxDistance;
        }
        
        if (priceRange != null) {
          // تطبيق فلتر نطاق السعر
          String craftsmanPriceRange = craftsman['priceRange'] ?? 'متوسط';
          passesFilter = passesFilter && craftsmanPriceRange == priceRange;
        }
        
        return passesFilter;
      }).toList();
    }
    
    return results;
  }
}
