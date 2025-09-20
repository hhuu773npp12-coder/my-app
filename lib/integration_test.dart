// lib/integration_test.dart
import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'services/payment_service.dart';
import 'services/rating_service.dart';
import 'services/analytics_service.dart';
import 'services/offline_service.dart';
import 'services/security_service.dart';
import 'utils/ui_improvements.dart';

/// اختبار التكامل بين جميع الميزات الجديدة
class IntegrationTestScreen extends StatefulWidget {
  final String userId;

  const IntegrationTestScreen({super.key, required this.userId});

  @override
  State<IntegrationTestScreen> createState() => _IntegrationTestScreenState();
}

class _IntegrationTestScreenState extends State<IntegrationTestScreen> {
  final List<Map<String, dynamic>> _testResults = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار التكامل'),
        backgroundColor: UIImprovements.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isRunning ? null : _runIntegrationTests,
              style: ElevatedButton.styleFrom(
                backgroundColor: UIImprovements.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isRunning
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تشغيل اختبارات التكامل'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      result['success'] ? Icons.check_circle : Icons.error,
                      color: result['success'] ? Colors.green : Colors.red,
                    ),
                    title: Text(result['test']),
                    subtitle: Text(result['message']),
                    trailing: Text(
                      '${result['duration']}ms',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runIntegrationTests() async {
    setState(() {
      _isRunning = true;
      _testResults.clear();
    });

    // اختبار خدمة الإشعارات
    await _testNotificationService();

    // اختبار خدمة الدفع
    await _testPaymentService();

    // اختبار خدمة التقييمات
    await _testRatingService();

    // اختبار خدمة التحليلات
    await _testAnalyticsService();

    // اختبار خدمة العمل بدون إنترنت
    await _testOfflineService();

    // اختبار خدمة الأمان
    await _testSecurityService();

    // اختبار التكامل بين الخدمات
    await _testServiceIntegration();

    setState(() {
      _isRunning = false;
    });

    // عرض النتائج النهائية
    _showTestSummary();
  }

  Future<void> _testNotificationService() async {
    final stopwatch = Stopwatch()..start();

    try {
      await NotificationService().sendNotificationToUser(
        userId: widget.userId,
        title: 'اختبار الإشعارات',
        body: 'هذا اختبار للتأكد من عمل الإشعارات',
        data: {'test': 'true'},
      );

      stopwatch.stop();
      _addTestResult('خدمة الإشعارات', true, 'تم إرسال الإشعار بنجاح',
          stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _addTestResult(
          'خدمة الإشعارات', false, 'خطأ: $e', stopwatch.elapsedMilliseconds);
    }
  }

  Future<void> _testPaymentService() async {
    final stopwatch = Stopwatch()..start();

    try {
      final balance = await PaymentService.getWalletBalance(widget.userId);
      print('رصيد المحفظة: $balance'); // لتجنب unused_local_variable

      if (balance == 0.0) {
        await PaymentService.createWallet(widget.userId);
      }

      stopwatch.stop();
      _addTestResult('خدمة الدفع', true, 'رصيد المحفظة: $balance د.ع',
          stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _addTestResult(
          'خدمة الدفع', false, 'خطأ: $e', stopwatch.elapsedMilliseconds);
    }
  }

  Future<void> _testRatingService() async {
    final stopwatch = Stopwatch()..start();

    try {
      final stats = await RatingService.getProviderRatingStats('test_provider');
      final avgRating = stats['averageRating'] as double;

      stopwatch.stop();
      _addTestResult(
          'خدمة التقييمات',
          true,
          'متوسط التقييم: ${avgRating.toStringAsFixed(1)}',
          stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _addTestResult(
          'خدمة التقييمات', false, 'خطأ: $e', stopwatch.elapsedMilliseconds);
    }
  }

  Future<void> _testAnalyticsService() async {
    final stopwatch = Stopwatch()..start();

    try {
      await AnalyticsService.logEvent(
        eventName: 'integration_test',
        userId: widget.userId,
        parameters: {'test_type': 'integration'},
      );

      stopwatch.stop();
      _addTestResult('خدمة التحليلات', true, 'تم تسجيل الحدث بنجاح',
          stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _addTestResult(
          'خدمة التحليلات', false, 'خطأ: $e', stopwatch.elapsedMilliseconds);
    }
  }

  Future<void> _testOfflineService() async {
    final stopwatch = Stopwatch()..start();

    try {
      await OfflineService().saveOfflineData('test_key', {'test': 'data'});
      final data = await OfflineService().getOfflineData('test_key');

      stopwatch.stop();
      _addTestResult(
          'خدمة العمل بدون إنترنت',
          data != null,
          data != null ? 'تم حفظ واسترجاع البيانات' : 'فشل في حفظ البيانات',
          stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _addTestResult('خدمة العمل بدون إنترنت', false, 'خطأ: $e',
          stopwatch.elapsedMilliseconds);
    }
  }

  Future<void> _testSecurityService() async {
    final stopwatch = Stopwatch()..start();

    try {
      final salt = SecurityService.generateSalt();
      final hashedPassword = SecurityService.hashPassword('test123', salt);
      print('Hashed password: $hashedPassword'); // لتجنب unused_local_variable

      final isValidPhone = SecurityService.isValidIraqiPhone('07701234567');
      final passwordStrength =
          SecurityService.checkPasswordStrength('Test123!');

      stopwatch.stop();
      _addTestResult(
          'خدمة الأمان',
          true,
          'تشفير: ✓, هاتف صحيح: $isValidPhone, قوة كلمة المرور: ${passwordStrength['strength']}',
          stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _addTestResult(
          'خدمة الأمان', false, 'خطأ: $e', stopwatch.elapsedMilliseconds);
    }
  }

  Future<void> _testServiceIntegration() async {
    final stopwatch = Stopwatch()..start();

    try {
      await AnalyticsService.logEvent(
        eventName: 'service_request',
        userId: widget.userId,
        parameters: {'service_type': 'integration_test'},
      );

      final balance = await PaymentService.getWalletBalance(widget.userId);
      print('رصيد المحفظة (تكامل): $balance'); // لتجنب التحذير

      await NotificationService().sendNotificationToUser(
        userId: widget.userId,
        title: 'اختبار التكامل مكتمل',
        body: 'تم اختبار جميع الخدمات بنجاح',
        data: {'integration_test': 'completed'},
      );

      stopwatch.stop();
      _addTestResult('التكامل بين الخدمات', true,
          'تم اختبار السيناريو المتكامل بنجاح', stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      _addTestResult('التكامل بين الخدمات', false, 'خطأ: $e',
          stopwatch.elapsedMilliseconds);
    }
  }

  void _addTestResult(String test, bool success, String message, int duration) {
    setState(() {
      _testResults.add({
        'test': test,
        'success': success,
        'message': message,
        'duration': duration,
      });
    });
  }

  void _showTestSummary() {
    final totalTests = _testResults.length;
    final passedTests = _testResults.where((r) => r['success']).length;
    final failedTests = totalTests - passedTests;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نتائج الاختبار'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إجمالي الاختبارات: $totalTests'),
            Text('نجح: $passedTests',
                style: const TextStyle(color: Colors.green)),
            Text('فشل: $failedTests',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            Text(
              failedTests == 0
                  ? '🎉 جميع الاختبارات نجحت!'
                  : '⚠️ بعض الاختبارات فشلت، يرجى المراجعة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: failedTests == 0 ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }
}
