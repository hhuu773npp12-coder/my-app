// lib/services/security_service.dart
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math';

/// خدمة الأمان وحماية البيانات
class SecurityService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// تشفير كلمة المرور
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// إنشاء salt عشوائي
  static String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  /// تشفير البيانات الحساسة
  static String encryptData(String data, String key) {
    // تطبيق تشفير بسيط - يُنصح باستخدام مكتبة تشفير أقوى في الإنتاج
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final encrypted = <int>[];

    for (int i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64.encode(encrypted);
  }

  /// فك تشفير البيانات
  static String decryptData(String encryptedData, String key) {
    final keyBytes = utf8.encode(key);
    final encryptedBytes = base64.decode(encryptedData);
    final decrypted = <int>[];

    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return utf8.decode(decrypted);
  }

  /// حفظ البيانات الحساسة بشكل آمن
  static Future<void> storeSecureData(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// استرجاع البيانات الحساسة
  static Future<String?> getSecureData(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// حذف البيانات الحساسة
  static Future<void> deleteSecureData(String key) async {
    await _secureStorage.delete(key: key);
  }

  /// التحقق من صحة رقم الهاتف العراقي
  static bool isValidIraqiPhone(String phone) {
    final phoneRegex = RegExp(r'^07[0-9]{9}$');
    return phoneRegex.hasMatch(phone);
  }

  /// التحقق من صحة البريد الإلكتروني
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// التحقق من قوة كلمة المرور
  static Map<String, dynamic> checkPasswordStrength(String password) {
    int score = 0;
    List<String> feedback = [];

    if (password.length >= 8) {
      score += 1;
    } else {
      feedback.add('يجب أن تكون كلمة المرور 8 أحرف على الأقل');
    }

    if (password.contains(RegExp(r'[A-Z]'))) {
      score += 1;
    } else {
      feedback.add('يجب أن تحتوي على حرف كبير');
    }

    if (password.contains(RegExp(r'[a-z]'))) {
      score += 1;
    } else {
      feedback.add('يجب أن تحتوي على حرف صغير');
    }

    if (password.contains(RegExp(r'[0-9]'))) {
      score += 1;
    } else {
      feedback.add('يجب أن تحتوي على رقم');
    }

    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      score += 1;
    } else {
      feedback.add('يجب أن تحتوي على رمز خاص');
    }

    String strength;
    if (score <= 2) {
      strength = 'ضعيفة';
    } else if (score <= 3) {
      strength = 'متوسطة';
    } else if (score <= 4) {
      strength = 'قوية';
    } else {
      strength = 'قوية جداً';
    }

    return {
      'score': score,
      'strength': strength,
      'feedback': feedback,
    };
  }

  /// تسجيل محاولة دخول مشبوهة
  static Future<void> logSuspiciousActivity({
    required String userId,
    required String activityType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('security_logs').add({
        'userId': userId,
        'activityType': activityType,
        'description': description,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'medium',
      });
    } catch (e) {
      print('Error logging suspicious activity: $e');
    }
  }

  /// فحص معدل الطلبات لمنع الإفراط
  static final Map<String, List<DateTime>> _requestHistory = {};

  static bool checkRateLimit(String userId,
      {int maxRequests = 10, Duration window = const Duration(minutes: 1)}) {
    final now = DateTime.now();
    final userHistory = _requestHistory[userId] ?? [];

    // إزالة الطلبات القديمة
    userHistory.removeWhere((time) => now.difference(time) > window);

    if (userHistory.length >= maxRequests) {
      logSuspiciousActivity(
        userId: userId,
        activityType: 'rate_limit_exceeded',
        description: 'User exceeded rate limit',
        metadata: {'requests_count': userHistory.length},
      );
      return false;
    }

    userHistory.add(now);
    _requestHistory[userId] = userHistory;
    return true;
  }

  /// تنظيف البيانات المدخلة لمنع الحقن
  static String sanitizeInput(String input) {
    return input.replaceAll(RegExp("[<>&\"'`]"), '');
  }

  /// التحقق من صحة الملف المرفوع
  static bool isValidFileType(String fileName, List<String> allowedTypes) {
    final extension = fileName.split('.').last.toLowerCase();
    return allowedTypes.contains(extension);
  }

  /// التحقق من حجم الملف
  static bool isValidFileSize(int fileSizeBytes, int maxSizeMB) {
    final maxSizeBytes = maxSizeMB * 1024 * 1024;
    return fileSizeBytes <= maxSizeBytes;
  }
}

/// خدمة التحقق من الهوية
class AuthenticationService {
  /// إنشاء رمز التحقق
  static String generateVerificationCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  /// التحقق من انتهاء صلاحية الرمز
  static bool isCodeExpired(DateTime createdAt,
      {Duration validity = const Duration(minutes: 5)}) {
    return DateTime.now().difference(createdAt) > validity;
  }

  /// حفظ رمز التحقق
  static Future<void> saveVerificationCode({
    required String phone,
    required String code,
  }) async {
    await FirebaseFirestore.instance
        .collection('verification_codes')
        .doc(phone)
        .set({
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
      'used': false,
    });
  }

  /// التحقق من رمز التحقق
  static Future<bool> verifyCode({
    required String phone,
    required String code,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('verification_codes')
          .doc(phone)
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final savedCode = data['code'];
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      final used = data['used'] ?? false;

      if (used || isCodeExpired(createdAt) || savedCode != code) {
        return false;
      }

      // تحديد الرمز كمستخدم
      await doc.reference.update({'used': true});
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// خدمة حماية البيانات الشخصية
class PrivacyService {
  /// إخفاء جزء من رقم الهاتف
  static String maskPhoneNumber(String phone) {
    if (phone.length < 4) return phone;
    final visiblePart = phone.substring(0, 3);
    final hiddenPart = '*' * (phone.length - 6);
    final lastPart = phone.substring(phone.length - 3);
    return '$visiblePart$hiddenPart$lastPart';
  }

  /// إخفاء جزء من البريد الإلكتروني
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) return email;

    final visiblePart = username.substring(0, 2);
    final hiddenPart = '*' * (username.length - 2);

    return '$visiblePart$hiddenPart@$domain';
  }

  /// تسجيل الوصول للبيانات الحساسة
  static Future<void> logDataAccess({
    required String userId,
    required String dataType,
    required String accessReason,
  }) async {
    await FirebaseFirestore.instance.collection('data_access_logs').add({
      'userId': userId,
      'dataType': dataType,
      'accessReason': accessReason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
