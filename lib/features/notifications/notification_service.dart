import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    // طلب إذن الإشعارات
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('إذن الإشعارات تم منحه');
    }

    // إعداد الإشعارات المحلية
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(initializationSettings);

    // الاستماع للإشعارات في المقدمة
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // الاستماع للإشعارات عند النقر عليها
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('رسالة في المقدمة: ${message.notification?.title}');
    
    await _showLocalNotification(
      title: message.notification?.title ?? 'إشعار جديد',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }

  static Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('تم النقر على الإشعار: ${message.notification?.title}');
    // يمكن إضافة منطق التنقل هنا
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'mesibawy_channel',
      'Mesibawy Notifications',
      channelDescription: 'إشعارات تطبيق مسيباوي',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // إرسال إشعار طلب جديد لمقدم الخدمة
  static Future<void> sendNewOrderNotification({
    required String providerId,
    required String orderType,
    required String customerName,
    required double price,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'recipientId': providerId,
        'title': 'طلب جديد - $orderType',
        'body': 'طلب جديد من $customerName بقيمة ${price.toStringAsFixed(0)} د.ع',
        'type': 'new_order',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': {
          'orderType': orderType,
          'customerName': customerName,
          'price': price,
        },
      });
    } catch (e) {
      print('خطأ في إرسال إشعار الطلب الجديد: $e');
    }
  }

  // إرسال إشعار خصم العمولة
  static Future<void> sendCommissionDeductedNotification({
    required String providerId,
    required double commission,
    required String orderType,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'recipientId': providerId,
        'title': 'تم خصم العمولة',
        'body': 'تم خصم عمولة ${commission.toStringAsFixed(0)} د.ع من طلب $orderType',
        'type': 'commission_deducted',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': {
          'commission': commission,
          'orderType': orderType,
        },
      });

      // حفظ سجل العمولة للوحة التحكم
      await _firestore.collection('commission_logs').add({
        'providerId': providerId,
        'commission': commission,
        'service': orderType,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('خطأ في إرسال إشعار العمولة: $e');
    }
  }

  // إرسال إشعار تغيير حالة الطلب للعميل
  static Future<void> sendOrderStatusNotification({
    required String customerId,
    required String status,
    required String orderType,
  }) async {
    try {
      String statusText = _getStatusText(status);
      
      await _firestore.collection('notifications').add({
        'recipientId': customerId,
        'title': 'تحديث حالة الطلب',
        'body': 'طلب $orderType الخاص بك $statusText',
        'type': 'order_status',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': {
          'status': status,
          'orderType': orderType,
        },
      });
    } catch (e) {
      print('خطأ في إرسال إشعار حالة الطلب: $e');
    }
  }

  // إرسال إشعار موافقة المشرف
  static Future<void> sendApprovalNotification({
    required String userId,
    required String userType,
    required bool approved,
  }) async {
    try {
      String title = approved ? 'تمت الموافقة على حسابك' : 'تم رفض طلبك';
      String body = approved 
          ? 'تمت الموافقة على حسابك كـ $userType. يمكنك الآن تسجيل الدخول'
          : 'تم رفض طلب التسجيل كـ $userType. يرجى المراجعة مع الإدارة';
      
      await _firestore.collection('notifications').add({
        'recipientId': userId,
        'title': title,
        'body': body,
        'type': 'approval_status',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': {
          'userType': userType,
          'approved': approved,
        },
      });
    } catch (e) {
      print('خطأ في إرسال إشعار الموافقة: $e');
    }
  }

  static String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'تم قبوله';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'تم إنجازه';
      case 'cancelled':
        return 'تم إلغاؤه';
      default:
        return 'تم تحديثه';
    }
  }

  // الحصول على الإشعارات للمستخدم
  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // تحديد الإشعار كمقروء
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      print('خطأ في تحديد الإشعار كمقروء: $e');
    }
  }

  // حذف الإشعار
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('خطأ في حذف الإشعار: $e');
    }
  }
}
