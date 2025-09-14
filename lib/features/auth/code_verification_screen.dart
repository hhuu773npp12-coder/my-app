import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../citizen/citizen_home_screen.dart';
import 'restaurant_auth_screen.dart';
import '../sorting/first_sort_screen.dart';

class CodeVerificationScreen extends StatefulWidget {
  final String userId;
  final String userType;
  final String phone;

  const CodeVerificationScreen({
    super.key,
    required this.userId,
    required this.userType,
    required this.phone,
  });

  @override
  State<CodeVerificationScreen> createState() => _CodeVerificationScreenState();
}

class _CodeVerificationScreenState extends State<CodeVerificationScreen> {
  final _codeController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final inputCode = _codeController.text.trim();

    if (inputCode.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال كود مكون من 4 أرقام')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String collection = '';
      switch (widget.userType) {
        case 'citizen':
          collection = 'citizens';
          break;
        case 'restaurant':
          collection = 'restaurants';
          break;
        default:
          collection = widget.userType;
      }

      final doc =
          await _firestore.collection(collection).doc(widget.userId).get();
      final data = doc.data();

      if (data != null && data['loginCode'] == inputCode) {
        // حفظ حالة تسجيل الدخول
        final prefs = await SharedPreferences.getInstance();

        switch (widget.userType) {
          case 'citizen':
            await prefs.setBool('isCitizenLoggedIn', true);
            await prefs.setString('citizenId', widget.userId);
            break;
          case 'restaurant':
            await prefs.setBool('isRestaurantLoggedIn', true);
            await prefs.setString('restaurantId', widget.userId);
            break;
        }

        // مسح الكود من قاعدة البيانات
        await _firestore.collection(collection).doc(widget.userId).update({
          'loginCode': FieldValue.delete(),
        });

        if (mounted) {
          Widget homeScreen;
          switch (widget.userType) {
            case 'citizen':
              homeScreen = CitizenHomeScreen(citizenId: widget.userId);
              break;
            case 'restaurant':
              homeScreen =
                  const RestaurantLoginScreen(); // Replace with actual restaurant home
              break;
            default:
              homeScreen = const UserSortScreen();
          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => homeScreen),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الكود غير صحيح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحقق من الكود'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 50),

            // أيقونة الكود
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.orange,
              child: Icon(Icons.security, size: 60, color: Colors.white),
            ),

            const SizedBox(height: 30),

            const Text(
              'تم إرسال كود التحقق للأدمن',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              'سيقوم الأدمن بإرسال الكود إلى رقم: ${widget.phone}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            // حقل إدخال الكود
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                labelText: 'أدخل الكود المكون من 4 أرقام',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),

            const SizedBox(height: 30),

            // زر التحقق
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'تحقق من الكود',
                      style: TextStyle(fontSize: 18),
                    ),
            ),

            const SizedBox(height: 20),

            // زر العودة
            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const UserSortScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'العودة للفرز',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
