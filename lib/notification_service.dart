// ignore: duplicate_ignore
// ignore: file_names
// اسم الملف: notification_service.dart

// ignore_for_file: file_names

import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

/// ===========================
/// خدمة إرسال الإشعارات عبر Firebase Cloud Messaging (FCM)
/// ===========================
class NotificationService {
  /// ضع مفتاح FCM الخاص بك هنا
  static const String _serverKey = "YOUR_FCM_SERVER_KEY";

  /// إرسال إشعار إلى جهاز معين باستخدام التوكن
  ///
  /// [token] : توكن جهاز المستقبل
  /// [title] : عنوان الإشعار
  /// [body] : نص الإشعار
  /// [data] : بيانات إضافية يمكن إرسالها مع الإشعار
  static Future<void> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("https://fcm.googleapis.com/fcm/send"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "key=$_serverKey",
        },
        body: jsonEncode({
          "to": token,
          "notification": {
            "title": title,
            "body": body,
          },
          "data": data ?? {},
        }),
      );

      if (response.statusCode != 200) {
        // إذا فشل الإرسال، اعرض رسالة خطأ
        throw Exception("❌ فشل إرسال الإشعار: ${response.body}");
      }
    } catch (e) {
      // يمكنك إضافة سجل أو معالجة الخطأ هنا
      rethrow; // لإلقاء الخطأ للمعالج الأعلى
    }
  }
}
