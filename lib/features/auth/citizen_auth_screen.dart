import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../citizen/citizen_home_screen.dart';
import 'code_verification_screen.dart';

class CitizenLoginScreen extends StatefulWidget {
  const CitizenLoginScreen({super.key});

  @override
  State<CitizenLoginScreen> createState() => _CitizenLoginScreenState();
}

class _CitizenLoginScreenState extends State<CitizenLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _loginCitizen();
      } else {
        await _registerCitizen();
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

  Future<void> _loginCitizen() async {
    final phone = _phoneController.text.trim();

    // البحث عن المواطن في قاعدة البيانات
    final querySnapshot = await _firestore
        .collection('citizens')
        .where('phone', isEqualTo: phone)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('رقم الهاتف غير مسجل');
    }

    final citizenData = querySnapshot.docs.first;
    final citizenId = citizenData.id;

    // إنشاء كود تحقق من 4 أرقام
    final code = (1000 + (citizenId.hashCode % 9000)).toString();
    
    // حفظ الكود في قاعدة البيانات
    await _firestore.collection('citizens').doc(citizenId).update({
      'loginCode': code,
      'codeGeneratedAt': FieldValue.serverTimestamp(),
    });

    // إرسال الكود للأدمن (محاكاة)
    await _firestore.collection('admin_notifications').add({
      'type': 'login_code',
      'userId': citizenId,
      'userType': 'citizen',
      'phone': phone,
      'code': code,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CodeVerificationScreen(
            userId: citizenId,
            userType: 'citizen',
            phone: phone,
          ),
        ),
      );
    }
  }

  Future<void> _registerCitizen() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    // التحقق من عدم وجود المواطن مسبقاً
    final existingCitizen = await _firestore
        .collection('citizens')
        .where('phone', isEqualTo: phone)
        .get();

    if (existingCitizen.docs.isNotEmpty) {
      throw Exception('رقم الهاتف مسجل مسبقاً');
    }

    // إنشاء حساب جديد
    final citizenRef = await _firestore.collection('citizens').add({
      'name': name,
      'phone': phone,
      'balance': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // حفظ حالة تسجيل الدخول
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCitizenLoggedIn', true);
    await prefs.setString('citizenId', citizenRef.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الحساب بنجاح!')),
      );

      // الانتقال لواجهة المواطن
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CitizenHomeScreen(citizenId: citizenRef.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'تسجيل دخول المواطن' : 'إنشاء حساب مواطن'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // أيقونة المواطن
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              
              const SizedBox(height: 30),

              // حقل الاسم (للتسجيل فقط)
              if (!_isLogin) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال الاسم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // حقل رقم الهاتف
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال رقم الهاتف';
                  }
                  if (value.length < 10) {
                    return 'رقم الهاتف يجب أن يكون 10 أرقام على الأقل';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),


              const SizedBox(height: 24),

              // زر التسجيل/الدخول
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),

              const SizedBox(height: 16),

              // رابط التبديل بين التسجيل والدخول
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _formKey.currentState?.reset();
                  });
                },
                child: Text(
                  _isLogin
                      ? 'ليس لديك حساب؟ إنشاء حساب جديد'
                      : 'لديك حساب؟ تسجيل الدخول',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
