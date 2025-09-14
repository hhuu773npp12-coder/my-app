import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/taxi/taxi_home_screen.dart';
import 'features/sorting/first_sort_screen.dart';

/// ✅ Widget عام للحقول النصية
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLines;

  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }
}

/// ✅ زر عام
Widget primaryButton(String text, VoidCallback onPressed,
    {Color color = Colors.blue}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: onPressed,
      child: Text(text),
    ),
  );
}

/// --------------------- شاشة تسجيل صاحب التكسي ---------------------
class TaxiRegisterPage extends StatefulWidget {
  const TaxiRegisterPage({super.key});

  @override
  State<TaxiRegisterPage> createState() => _TaxiRegisterPageState();
}

class _TaxiRegisterPageState extends State<TaxiRegisterPage> {
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

    final docRef = await FirebaseFirestore.instance.collection('users').add({
      "name": name,
      "phone": phone,
      "role": "taxi",
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
        builder: (_) => PendingApprovalScreen(userId: docRef.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل صاحب التكسي")),
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

/// --------------------- شاشة تسجيل الدخول ---------------------
class TaxiLoginPage extends StatefulWidget {
  const TaxiLoginPage({super.key});

  @override
  State<TaxiLoginPage> createState() => _TaxiLoginPageState();
}

class _TaxiLoginPageState extends State<TaxiLoginPage> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  Future<void> _login() async {
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ أدخل الاسم ورقم الهاتف")),
      );
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .where('role', isEqualTo: 'taxi')
        .get();

    if (snapshot.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ الاسم أو الهاتف غير صحيح")),
      );
      return;
    }

    final userDoc = snapshot.docs.first;
    final userData = userDoc.data();

    if (userData['status'] != 'approved') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PendingApprovalScreen(userId: userDoc.id)),
      );
      return;
    }

    final code = _generateCode();
    await FirebaseFirestore.instance.collection('taxi_login_requests').add({
      "userId": userDoc.id,
      "name": userData['name'],
      "phone": userData['phone'],
      "code": code,
      "timestamp": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaxiCodePage(userId: userDoc.id)),
    );
  }

  String _generateCode() {
    final random = Random();
    return (1000 + random.nextInt(8999)).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول صاحب التكسي")),
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
                keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            primaryButton(
              "إنشاء حساب جديد",
              () {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TaxiRegisterPage()),
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

class TaxiCodePage extends StatefulWidget {
  final String userId;
  const TaxiCodePage({super.key, required this.userId});

  @override
  State<TaxiCodePage> createState() => _TaxiCodePageState();
}

class _TaxiCodePageState extends State<TaxiCodePage> {
  final codeCtrl = TextEditingController();

  Future<void> _verifyCode() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('taxi_login_requests')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ لم يتم العثور على أي كود دخول")),
      );
      return;
    }

    final correctCode = snapshot.docs.first['code'];

    if (codeCtrl.text.trim() == correctCode.toString()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isTaxiLoggedIn', true);
      await prefs.setString('userId', widget.userId);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => TaxiHomeScreen(userId: widget.userId)),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ الكود غير صحيح")),
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
            LabeledField(label: "الكود", controller: codeCtrl),
            const SizedBox(height: 20),
            primaryButton("تأكيد", _verifyCode),
          ],
        ),
      ),
    );
  }
}

/// --------------------- شاشة انتظار الموافقة ---------------------
class PendingApprovalScreen extends StatefulWidget {
  final String userId;
  const PendingApprovalScreen({super.key, required this.userId});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        if (data == null) {
          return const Center(child: Text("لم يتم العثور على بياناتك"));
        }

        if (data['status'] == 'approved') {
          // استخدم Future.microtask للتأكد من تنفيذ Navigator بعد بناء الواجهة
          Future.microtask(() {
            if (!mounted) return;
            Navigator.pushReplacement(
              // ignore: use_build_context_synchronously
              context,
              MaterialPageRoute(builder: (_) => const TaxiLoginPage()),
            );
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text("طلبك قيد المراجعة")),
          body: const Center(child: Text("طلبك قيد المراجعة...")),
        );
      },
    );
  }
}
