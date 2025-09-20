import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantManagementService {
  /// تحديث حالة المطعم من نشط/غير نشط إلى مفتوح/مغلق
  static Future<void> updateRestaurantStatus(
      String restaurantId, bool isOpen) async {
    await FirebaseFirestore.instance
        .collection("restaurants")
        .doc(restaurantId)
        .update({
      "isOpen": isOpen,
      "lastStatusUpdate": FieldValue.serverTimestamp(),
    });
  }

  /// جلب المطاعم المفتوحة فقط
  static Future<List<Map<String, dynamic>>> getOpenRestaurants({
    String? region,
    String? cuisine,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection("restaurants")
        .where("isOpen", isEqualTo: true);

    if (region != null && region.isNotEmpty) {
      query = query.where("region", isEqualTo: region);
    }

    if (cuisine != null && cuisine.isNotEmpty) {
      query = query.where("cuisine", isEqualTo: cuisine);
    }

    QuerySnapshot snapshot = await query.get();

    return snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// إرسال طلب طعام للمطعم للموافقة أولاً
  static Future<String> sendFoodOrderToRestaurant({
    required String restaurantId,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> customerLocation,
    required int totalAmount,
  }) async {
    DocumentReference orderRef = FirebaseFirestore.instance
        .collection("restaurant_pending_orders")
        .doc();

    await orderRef.set({
      "restaurantId": restaurantId,
      "customerId": customerId,
      "customerName": customerName,
      "customerPhone": customerPhone,
      "items": items,
      "customerLocation": customerLocation,
      "totalAmount": totalAmount,
      "status": "pending_restaurant_approval",
      "createdAt": FieldValue.serverTimestamp(),
      "expiresAt":
          Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
    });

    // إرسال إشعار للمطعم
    await _sendNotificationToRestaurant(restaurantId, {
      "title": "طلب طعام جديد",
      "body": "لديك طلب جديد من $customerName بقيمة $totalAmount د.ع",
      "orderId": orderRef.id,
      "type": "new_food_order",
    });

    return orderRef.id;
  }

  /// موافقة المطعم على الطلب وإرساله للدراجات
  static Future<void> approveRestaurantOrder(
      String orderId, String restaurantId,
      {int? preparationTimeMinutes}) async {
    DocumentReference orderRef = FirebaseFirestore.instance
        .collection("restaurant_pending_orders")
        .doc(orderId);

    DocumentSnapshot orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
      throw Exception("الطلب غير موجود");
    }

    Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;

    // تحديث حالة الطلب
    await orderRef.update({
      "status": "approved_by_restaurant",
      "approvedAt": FieldValue.serverTimestamp(),
      "preparationTimeMinutes": preparationTimeMinutes ?? 15,
    });

    // إنشاء طلب في نظام مشاركة الدراجات
    await _shareOrderWithBikes(orderData, orderId);

    // إشعار العميل بالموافقة
    await _sendNotificationToCustomer(orderData['customerId'], {
      "title": "تم قبول طلبك",
      "body":
          "وافق المطعم على طلبك وسيتم تحضيره خلال ${preparationTimeMinutes ?? 15} دقيقة",
      "orderId": orderId,
      "type": "order_approved",
    });
  }

  /// رفض المطعم للطلب
  static Future<void> rejectRestaurantOrder(
      String orderId, String reason) async {
    DocumentReference orderRef = FirebaseFirestore.instance
        .collection("restaurant_pending_orders")
        .doc(orderId);

    DocumentSnapshot orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
      throw Exception("الطلب غير موجود");
    }

    Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;

    await orderRef.update({
      "status": "rejected_by_restaurant",
      "rejectedAt": FieldValue.serverTimestamp(),
      "rejectionReason": reason,
    });

    // إشعار العميل بالرفض
    await _sendNotificationToCustomer(orderData['customerId'], {
      "title": "تم رفض طلبك",
      "body": "عذراً، لم يتمكن المطعم من قبول طلبك. السبب: $reason",
      "orderId": orderId,
      "type": "order_rejected",
    });
  }

  /// مشاركة الطلب مع الدراجات بعد موافقة المطعم
  static Future<void> _shareOrderWithBikes(
      Map<String, dynamic> orderData, String originalOrderId) async {
    // إنشاء طلب جديد لمشاركته مع الدراجات
    DocumentReference bikeOrderRef =
        FirebaseFirestore.instance.collection("bike_delivery_orders").doc();

    await bikeOrderRef.set({
      "originalOrderId": originalOrderId,
      "restaurantId": orderData['restaurantId'],
      "customerId": orderData['customerId'],
      "customerName": orderData['customerName'],
      "customerPhone": orderData['customerPhone'],
      "customerLocation": orderData['customerLocation'],
      "totalAmount": orderData['totalAmount'],
      "serviceType": "food_delivery",
      "status": "pending_bike_assignment",
      "createdAt": FieldValue.serverTimestamp(),
      "maxBikeOrderValue": 40000, // الحد الأقصى الجديد
    });

    // البحث عن الدراجات المناسبة وإرسال الطلب لهم
    await _assignOrderToBikes(bikeOrderRef.id, orderData);
  }

  /// تعيين الطلب للدراجات المناسبة
  static Future<void> _assignOrderToBikes(
      String bikeOrderId, Map<String, dynamic> orderData) async {
    // جلب الدراجات المتاحة
    List<Map<String, dynamic>> availableBikes = await FirebaseFirestore.instance
        .collection("users")
        .where("type", isEqualTo: "delivery_bike")
        .where("active", isEqualTo: true)
        .where("available", isEqualTo: true)
        .get()
        .then((snapshot) => snapshot.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());

    // ترتيب الدراجات حسب الأولوية
    if (orderData['customerLocation'] != null) {
      double customerLat = orderData['customerLocation']['lat'];
      double customerLon = orderData['customerLocation']['lng'];

      // استخدام خدمة ترتيب السائقين المحسنة
      availableBikes =
          await _sortBikesByPriority(availableBikes, customerLat, customerLon);
    }

    // إرسال الطلب لأفضل 5 دراجات
    int maxBikes = 5;
    List<Map<String, dynamic>> selectedBikes =
        availableBikes.take(maxBikes).toList();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var bike in selectedBikes) {
      DocumentReference assignmentRef =
          FirebaseFirestore.instance.collection("bike_order_assignments").doc();

      batch.set(assignmentRef, {
        "bikeOrderId": bikeOrderId,
        "bikeId": bike['id'],
        "bikeName": bike['name'],
        "bikePhone": bike['phone'],
        "customerName": orderData['customerName'],
        "customerPhone": orderData['customerPhone'],
        "totalAmount": orderData['totalAmount'],
        "status": "pending",
        "assignedAt": FieldValue.serverTimestamp(),
        "expiresAt":
            Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 15))),
      });
    }

    await batch.commit();
  }

  /// ترتيب الدراجات حسب الأولوية المحسنة
  static Future<List<Map<String, dynamic>>> _sortBikesByPriority(
      List<Map<String, dynamic>> bikes,
      double customerLat,
      double customerLon) async {
    // حساب المسافة والنقاط لكل دراجة
    for (var bike in bikes) {
      if (bike['latitude'] != null && bike['longitude'] != null) {
        double distance = _calculateDistance(
            customerLat, customerLon, bike['latitude'], bike['longitude']);
        bike['distance'] = distance;
        bike['priorityScore'] = _calculateBikePriorityScore(bike);
      } else {
        bike['distance'] = 999.0;
        bike['priorityScore'] = 0.0;
      }
    }

    // ترتيب حسب النقاط
    bikes.sort((a, b) =>
        (b['priorityScore'] as double).compareTo(a['priorityScore'] as double));

    return bikes;
  }

  /// حساب نقاط الأولوية للدراجة
  static double _calculateBikePriorityScore(Map<String, dynamic> bike) {
    double distance = bike['distance'] ?? 999.0;
    double balance = (bike['balance'] ?? 0).toDouble();
    double rating = (bike['rating'] ?? 3.0).toDouble();
    int completedOrders = bike['completedOrders'] ?? 0;
    bool isActive = bike['active'] == true && bike['available'] == true;

    // مضاعف الحالة النشطة
    double statusMultiplier = isActive ? 1.0 : 0.2;

    // نقاط المسافة (كلما قل، زاد)
    double distanceScore = distance < 50 ? (50 - distance) * 2 : 0;

    // نقاط الرصيد (أهمية عالية للدراجات)
    double balanceScore = (balance / 10000) * 20;

    // نقاط التقييم
    double ratingScore = (rating / 5.0) * 30;

    // نقاط الخبرة
    double experienceScore = (completedOrders / 10) * 10;

    return (distanceScore + balanceScore + ratingScore + experienceScore) *
        statusMultiplier;
  }

  /// حساب المسافة بين نقطتين
  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// إرسال إشعار للمطعم
  static Future<void> _sendNotificationToRestaurant(
      String restaurantId, Map<String, dynamic> notification) async {
    await FirebaseFirestore.instance
        .collection("restaurant_notifications")
        .add({
      "restaurantId": restaurantId,
      "title": notification['title'],
      "body": notification['body'],
      "data": notification,
      "read": false,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  /// إرسال إشعار للعميل
  static Future<void> _sendNotificationToCustomer(
      String customerId, Map<String, dynamic> notification) async {
    await FirebaseFirestore.instance.collection("customer_notifications").add({
      "customerId": customerId,
      "title": notification['title'],
      "body": notification['body'],
      "data": notification,
      "read": false,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  /// جلب الطلبات المعلقة للمطعم
  static Stream<QuerySnapshot> getRestaurantPendingOrders(String restaurantId) {
    return FirebaseFirestore.instance
        .collection("restaurant_pending_orders")
        .where("restaurantId", isEqualTo: restaurantId)
        .where("status", isEqualTo: "pending_restaurant_approval")
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  /// جلب إحصائيات المطعم
  static Future<Map<String, dynamic>> getRestaurantStats(
      String restaurantId) async {
    // طلبات اليوم
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);

    QuerySnapshot todayOrders = await FirebaseFirestore.instance
        .collection("restaurant_pending_orders")
        .where("restaurantId", isEqualTo: restaurantId)
        .where("createdAt", isGreaterThan: Timestamp.fromDate(startOfDay))
        .get();

    // الطلبات المكتملة هذا الشهر
    DateTime startOfMonth = DateTime(today.year, today.month, 1);
    QuerySnapshot monthlyOrders = await FirebaseFirestore.instance
        .collection("restaurant_pending_orders")
        .where("restaurantId", isEqualTo: restaurantId)
        .where("status", isEqualTo: "completed")
        .where("createdAt", isGreaterThan: Timestamp.fromDate(startOfMonth))
        .get();

    double totalRevenue = 0;
    for (var doc in monthlyOrders.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      totalRevenue += (data['totalAmount'] ?? 0).toDouble();
    }

    return {
      "todayOrders": todayOrders.docs.length,
      "monthlyOrders": monthlyOrders.docs.length,
      "monthlyRevenue": totalRevenue,
      "averageOrderValue": monthlyOrders.docs.isNotEmpty
          ? totalRevenue / monthlyOrders.docs.length
          : 0,
    };
  }
}
