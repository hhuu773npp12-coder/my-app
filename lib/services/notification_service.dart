// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

/// خدمة الإشعارات المتقدمة
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    // طلب الأذونات
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // تهيئة الإشعارات المحلية
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // الاستماع للإشعارات في المقدمة
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // الاستماع للإشعارات عند فتح التطبيق
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  /// معالجة الإشعارات في المقدمة
  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(
      title: message.notification?.title ?? 'إشعار جديد',
      body: message.notification?.body ?? '',
      payload: json.encode(message.data),
    );
  }

  /// معالجة النقر على الإشعار
  void _handleNotificationTap(RemoteMessage message) {
    // التنقل إلى الشاشة المناسبة حسب نوع الإشعار
    _navigateBasedOnNotification(message.data);
  }

  /// معالجة النقر على الإشعار المحلي
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = json.decode(response.payload!);
      _navigateBasedOnNotification(data);
    }
  }

  /// التنقل حسب نوع الإشعار
  void _navigateBasedOnNotification(Map<String, dynamic> data) {
    final type = data['type'];
    final targetId = data['targetId'];
    
    // يمكن إضافة منطق التنقل هنا حسب نوع الإشعار
    switch (type) {
      case 'new_order':
        // التنقل إلى شاشة الطلبات
        break;
      case 'order_accepted':
        // التنقل إلى تفاصيل الطلب
        break;
      case 'payment_received':
        // التنقل إلى المحفظة
        break;
    }
  }

  /// إرسال إشعار محلي
  Future<void> _showLocalNotification({
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
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// إرسال إشعار لمستخدم محدد
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // الحصول على FCM token للمستخدم
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final fcmToken = userDoc.data()?['fcmToken'];
      if (fcmToken == null) return;

      // حفظ الإشعار في قاعدة البيانات
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // إرسال الإشعار عبر FCM (يحتاج إلى server-side implementation)
      // يمكن استخدام Cloud Functions لهذا الغرض
      
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  /// إرسال إشعار لمجموعة من المستخدمين
  Future<void> sendBulkNotification({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    
    for (final userId in userIds) {
      final notificationRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();
      
      batch.set(notificationRef, {
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
  }

  /// تحديث حالة الإشعار كمقروء
  Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  /// الحصول على عدد الإشعارات غير المقروءة
  Stream<int> getUnreadNotificationsCount(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// حفظ FCM token للمستخدم
  Future<void> saveFCMToken(String userId) async {
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': token});
    }
  }
}

/// أنواع الإشعارات
enum NotificationType {
  newOrder('new_order', 'طلب جديد'),
  orderAccepted('order_accepted', 'تم قبول الطلب'),
  orderCompleted('order_completed', 'تم إكمال الطلب'),
  paymentReceived('payment_received', 'تم استلام الدفعة'),
  newMessage('new_message', 'رسالة جديدة'),
  systemUpdate('system_update', 'تحديث النظام');

  const NotificationType(this.value, this.displayName);
  final String value;
  final String displayName;
}
