// lib/features/tuktuk/tuktuk_auth.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tuktuk_home_screen.dart';
import 'features/sorting/first_sort_screen.dart';
import 'widgets/ui.dart';

/// ------------------- شاشة تسجيل دخول صاحب التكتك بنظام اليوزر -------------------
class TuktukLoginPage extends StatefulWidget {
  const TuktukLoginPage({super.key});

  @override
  State<TuktukLoginPage> createState() => _TuktukLoginPageState();
}

class _TuktukLoginPageState extends State<TuktukLoginPage> {
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAlreadyLoggedIn();
  }

  Future<void> _checkAlreadyLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isTuktukLoggedIn') ?? false;
    if (isLoggedIn) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => const TuktukHomeScreen(userId: 'driverId')),
      );
    }
  }

  Future<void> _login() async {
    final phone = phoneCtrl.text.trim();
    final name = nameCtrl.text.trim();

    if (phone.isEmpty || name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ الرجاء إدخال الاسم ورقم الهاتف")),
      );
      return;
    }

    try {
      // البحث عن صاحب التكتك
      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .where('role', isEqualTo: 'tuktuk')
          .get();

      String userId;

      if (snapshot.docs.isEmpty) {
        // إنشاء المستخدم إذا لم يكن موجودًا
        var docRef = await FirebaseFirestore.instance.collection('users').add({
          "phone": phone,
          "name": name,
          "role": "tuktuk",
          "status": "pending",
          "createdAt": FieldValue.serverTimestamp(),
        });
        userId = docRef.id;
      } else {
        userId = snapshot.docs.first.id;
      }

      // توليد كود تسجيل الدخول
      String code = (1000 + Random().nextInt(8999)).toString();

      await FirebaseFirestore.instance.collection('login_requests').add({
        "userId": userId,
        "phone": phone,
        "code": code,
        "timestamp": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم إرسال طلب تسجيل الدخول للأدمن")),
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TuktukCodePage(userId: userId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ حدث خطأ: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول صاحب التكتك")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(label: "الاسم", controller: nameCtrl),
            const SizedBox(height: 12),
            LabeledField(
              label: "رقم الهاتف",
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            primaryButton(
              "إنشاء حساب جديد",
              () {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TuktukRegisterScreen()),
                );
              },
              color: Colors.green,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.teal),
              label: const Text(
                "العودة إلى الفرز",
                style: TextStyle(color: Colors.teal),
              ),
              onPressed: () {
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const UserSortScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            primaryButton("تسجيل الدخول", _login),
          ],
        ),
      ),
    );
  }
}

/// --------------------- شاشة إدخال الكود ---------------------
class TuktukCodePage extends StatefulWidget {
  final String userId;
  const TuktukCodePage({super.key, required this.userId});

  @override
  State<TuktukCodePage> createState() => _TuktukCodePageState();
}

class _TuktukCodePageState extends State<TuktukCodePage> {
  final TextEditingController codeCtrl = TextEditingController();

  Future<void> _verifyCode() async {
    if (codeCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ الرجاء إدخال الكود")),
      );
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('login_requests')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ لم يتم العثور على أي كود دخول")),
        );
        return;
      }

      final correctCode = snapshot.docs.first['code'];

      if (codeCtrl.text.trim() == correctCode.toString()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isTuktukLoggedIn', true);
        await prefs.setString('userId', widget.userId);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم التحقق بنجاح")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => TuktukHomeScreen(userId: widget.userId)),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ الكود غير صحيح")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ حدث خطأ: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدخال الكود")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LabeledField(
              label: "أدخل الكود الذي أرسله لك الأدمن",
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 20),
            primaryButton("تأكيد", _verifyCode),
          ],
        ),
      ),
    );
  }
}

/// --------------------- شاشة انتظار الموافقة ---------------------
class PendingApprovalScreen extends StatelessWidget {
  final String phone;
  const PendingApprovalScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طلبك قيد المراجعة")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phone)
            .where('role', isEqualTo: 'tuktuk')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final querySnapshot = snapshot.data as QuerySnapshot;

          if (querySnapshot.docs.isEmpty) {
            return const Center(child: Text("لم يتم العثور على بياناتك"));
          }

          final userData = querySnapshot.docs.first;

          if (userData['status'] == 'approved') {
            Future.microtask(() {
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TuktukLoginPage()),
              );
            });
          }

          return const Center(child: Text("طلبك قيد المراجعة..."));
        },
      ),
    );
  }
}

/// --------------------- شاشة تسجيل التكتك ---------------------
class TuktukRegisterScreen extends StatefulWidget {
  const TuktukRegisterScreen({super.key});

  @override
  State<TuktukRegisterScreen> createState() => _TuktukRegisterScreenState();
}

class _TuktukRegisterScreenState extends State<TuktukRegisterScreen> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final carNameCtrl = TextEditingController();
  final carColorCtrl = TextEditingController();
  final carNumberCtrl = TextEditingController();
  final seatsCtrl = TextEditingController();

  Future<void> _register() async {
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال كل البيانات")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('users').add({
      "name": name,
      "phone": phone,
      "role": "tuktuk",
      "status": "pending",
      "carName": carNameCtrl.text.trim(),
      "carColor": carColorCtrl.text.trim(),
      "carNumber": carNumberCtrl.text.trim(),
      "seats": seatsCtrl.text.trim(),
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم إرسال طلب التسجيل")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PendingApprovalScreen(phone: phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل صاحب التكتك")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            LabeledField(label: "الاسم", controller: nameCtrl),
            const SizedBox(height: 12),
            LabeledField(
                label: "رقم الهاتف",
                controller: phoneCtrl,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            LabeledField(label: "اسم السيارة", controller: carNameCtrl),
            const SizedBox(height: 12),
            LabeledField(label: "لون السيارة", controller: carColorCtrl),
            const SizedBox(height: 12),
            LabeledField(label: "رقم السيارة", controller: carNumberCtrl),
            const SizedBox(height: 12),
            LabeledField(
                label: "عدد الركاب",
                controller: seatsCtrl,
                keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            primaryButton("تسجيل", _register),
          ],
        ),
      ),
    );
  }
}
