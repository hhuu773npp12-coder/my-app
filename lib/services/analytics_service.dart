// lib/services/analytics_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// خدمة التحليلات والإحصائيات
class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// تهيئة خدمة التحليلات
  static Future<void> initialize() async {
    try {
      // تهيئة أي إعدادات مطلوبة للتحليلات
      debugPrint('Analytics service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing analytics service: $e');
    }
  }

  /// تسجيل حدث في التطبيق
  static Future<void> logEvent({
    required String eventName,
    required String userId,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _firestore.collection('analytics_events').add({
        'eventName': eventName,
        'userId': userId,
        'parameters': parameters ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('Error logging analytics event: $e');
    }
  }

  /// تسجيل استخدام الشاشة
  static Future<void> logScreenView({
    required String screenName,
    required String userId,
    Duration? timeSpent,
  }) async {
    await logEvent(
      eventName: 'screen_view',
      userId: userId,
      parameters: {
        'screen_name': screenName,
        'time_spent_seconds': timeSpent?.inSeconds,
      },
    );
  }

  /// تسجيل طلب خدمة
  static Future<void> logServiceRequest({
    required String serviceType,
    required String userId,
    required double price,
    String? location,
  }) async {
    await logEvent(
      eventName: 'service_request',
      userId: userId,
      parameters: {
        'service_type': serviceType,
        'price': price,
        'location': location,
      },
    );
  }

  /// تسجيل إكمال طلب
  static Future<void> logOrderCompletion({
    required String orderId,
    required String serviceType,
    required String userId,
    required double rating,
    required Duration duration,
  }) async {
    await logEvent(
      eventName: 'order_completed',
      userId: userId,
      parameters: {
        'order_id': orderId,
        'service_type': serviceType,
        'rating': rating,
        'duration_minutes': duration.inMinutes,
      },
    );
  }

  /// الحصول على إحصائيات المستخدم
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    final ordersSnapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .get();

    final completedOrders = ordersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;

    final totalSpent = ordersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        // ignore: avoid_types_as_parameter_names
        .fold<double>(0, (sum, doc) => sum + (doc.data()['price'] ?? 0));

    return {
      'totalOrders': ordersSnapshot.docs.length,
      'completedOrders': completedOrders,
      'totalSpent': totalSpent,
      'memberSince': DateTime.now(), // يجب الحصول على تاريخ التسجيل الفعلي
    };
  }

  /// الحصول على إحصائيات مقدم الخدمة
  static Future<Map<String, dynamic>> getProviderStats(
      String providerId) async {
    final ordersSnapshot = await _firestore
        .collection('orders')
        .where('serviceProviderId', isEqualTo: providerId)
        .get();

    final completedOrders = ordersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;

    final totalEarnings = ordersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        // ignore: avoid_types_as_parameter_names
        .fold<double>(0, (sum, doc) => sum + (doc.data()['price'] ?? 0));

    final ratingsSnapshot = await _firestore
        .collection('ratings')
        .where('serviceProviderId', isEqualTo: providerId)
        .get();

    double averageRating = 0;
    if (ratingsSnapshot.docs.isNotEmpty) {
      final totalRating = ratingsSnapshot.docs
          // ignore: avoid_types_as_parameter_names
          .fold<double>(0, (sum, doc) => sum + (doc.data()['rating'] ?? 0));
      averageRating = totalRating / ratingsSnapshot.docs.length;
    }

    return {
      'totalOrders': ordersSnapshot.docs.length,
      'completedOrders': completedOrders,
      'totalEarnings': totalEarnings,
      'averageRating': averageRating,
      'totalRatings': ratingsSnapshot.docs.length,
    };
  }
}

/// خدمة التقارير
class ReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// تقرير الأداء اليومي
  static Future<Map<String, dynamic>> getDailyReport(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final ordersSnapshot = await _firestore
        .collection('orders')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final totalOrders = ordersSnapshot.docs.length;
    final completedOrders = ordersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        .length;

    final totalRevenue = ordersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'completed')
        // ignore: avoid_types_as_parameter_names
        .fold<double>(0, (sum, doc) => sum + (doc.data()['price'] ?? 0));

    return {
      'date': date,
      'totalOrders': totalOrders,
      'completedOrders': completedOrders,
      'pendingOrders': totalOrders - completedOrders,
      'totalRevenue': totalRevenue,
      'completionRate':
          totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0,
    };
  }

  /// تقرير أداء الخدمات
  static Future<List<Map<String, dynamic>>> getServicesReport() async {
    final services = [
      'taxi',
      'electrician',
      'plumber',
      'blacksmith',
      'cooling'
    ];
    final reports = <Map<String, dynamic>>[];

    for (final service in services) {
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('serviceType', isEqualTo: service)
          .get();

      final totalOrders = ordersSnapshot.docs.length;
      final completedOrders = ordersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      final totalRevenue = ordersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          // ignore: avoid_types_as_parameter_names
          .fold<double>(0, (sum, doc) => sum + (doc.data()['price'] ?? 0));

      reports.add({
        'serviceType': service,
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'totalRevenue': totalRevenue,
        'completionRate':
            totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0,
      });
    }

    return reports;
  }
}
