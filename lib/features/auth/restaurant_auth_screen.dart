import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'code_verification_screen.dart';
import '../sorting/first_sort_screen.dart';
import 'waiting_approval_screen.dart';

class RestaurantLoginScreen extends StatefulWidget {
  const RestaurantLoginScreen({super.key});

  @override
  State<RestaurantLoginScreen> createState() => _RestaurantLoginScreenState();
}

class _RestaurantLoginScreenState extends State<RestaurantLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _loginRestaurant();
      } else {
        await _registerRestaurant();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginRestaurant() async {
    final phone = _phoneController.text.trim();

    // البحث عن المطعم في قاعدة البيانات
    final querySnapshot = await FirebaseFirestore.instance
        .collection('restaurants')
        .where('phone', isEqualTo: phone)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('رقم الهاتف غير مسجل');
    }

    final restaurantData = querySnapshot.docs.first;
    final restaurantId = restaurantData.id;

    // إنشاء كود تحقق من 4 أرقام
    final code = (1000 + (restaurantId.hashCode % 9000)).toString();

    // حفظ الكود في قاعدة البيانات
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .update({
      'loginCode': code,
      'codeGeneratedAt': FieldValue.serverTimestamp(),
    });

    // إرسال الكود للأدمن
    await FirebaseFirestore.instance.collection('admin_notifications').add({
      'type': 'login_code',
      'userId': restaurantId,
      'userType': 'restaurant',
      'phone': phone,
      'code': code,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CodeVerificationScreen(
            userId: restaurantId,
            userType: 'restaurant',
            phone: phone,
          ),
        ),
      );
    }
  }

  Future<void> _registerRestaurant() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    // التحقق من عدم وجود مطعم بنفس رقم الهاتف
    final existingQuery = await FirebaseFirestore.instance
        .collection('restaurants')
        .where('phone', isEqualTo: phone)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      throw 'رقم الهاتف مسجل مسبقاً';
    }

    // إنشاء حساب جديد
    final docRef =
        await FirebaseFirestore.instance.collection('restaurants').add({
      'name': name,
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'isApproved': false,
    });

    final restaurantId = docRef.id;

    // حفظ بيانات تسجيل الدخول
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isRestaurantOwnerLoggedIn', true);
    await prefs.setString('restaurantOwnerId', restaurantId);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingApprovalScreen(
            userId: restaurantId,
            userType: 'مطعم',
            collection: 'restaurants',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'تسجيل دخول المطعم' : 'تسجيل مطعم جديد'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),

              if (!_isLogin) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المطعم',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال اسم المطعم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال رقم الهاتف';
                  }
                  if (value.length < 11) {
                    return 'رقم الهاتف يجب أن يكون 11 رقم على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 24),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLogin ? 'تسجيل الدخول' : 'إنشاء حساب'),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _formKey.currentState?.reset();
                  });
                },
                child: Text(
                  _isLogin ? 'ليس لديك حساب؟ سجل الآن' : 'لديك حساب؟ سجل دخولك',
                ),
              ),

              const SizedBox(height: 16),

              // زر العودة للفرز
              TextButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const UserSortScreen()),
                  );
                },
                icon: const Icon(Icons.arrow_back, color: Colors.grey),
                label: const Text(
                  'العودة للفرز',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
