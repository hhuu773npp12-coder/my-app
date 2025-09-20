import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../citizen/citizen_home.dart';
import '../../widgets/ui.dart';
import '../sorting/first_sort_screen.dart';

/// -------------------- شاشة تسجيل الدخول للمواطن --------------------
class CitizenLoginPage extends StatefulWidget {
  const CitizenLoginPage({super.key});

  @override
  State<CitizenLoginPage> createState() => _CitizenLoginPageState();
}

class _CitizenLoginPageState extends State<CitizenLoginPage> {
  final TextEditingController phoneCtrl = TextEditingController();

  Future<void> _sendRequest() async {
    final phone = phoneCtrl.text.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال رقم الهاتف")),
      );
      return;
    }

    var userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .where('role', isEqualTo: 'citizen')
        .get();

    String userId;

    if (userSnapshot.docs.isEmpty) {
      var docRef = await FirebaseFirestore.instance.collection('users').add({
        "phone": phone,
        "role": "citizen",
        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
      });
      userId = docRef.id;
    } else {
      userId = userSnapshot.docs.first.id;
    }

    final code = (1000 + Random().nextInt(8999)).toString();

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

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CitizenCodePage(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل الدخول للمواطن")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LabeledField(
              label: "رقم الهاتف",
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            primaryButton("طلب تسجيل الدخول", _sendRequest),
            const SizedBox(height: 10),
            // --- زر إنشاء حساب جديد ---
            TextButton.icon(
              icon: const Icon(Icons.person_add, color: Colors.teal),
              label: const Text(
                "تسجيل حساب جديد",
                style: TextStyle(color: Colors.teal),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CitizenRegisterPage()),
                );
              },
            ),
            const SizedBox(height: 20),
            // --- زر العودة إلى الفرز ---
            TextButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.teal),
              label: const Text(
                "العودة إلى الفرز",
                style: TextStyle(color: Colors.teal),
              ),
              onPressed: () async {
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const UserSortScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- شاشة إدخال الكود --------------------
class CitizenCodePage extends StatefulWidget {
  final String userId;
  const CitizenCodePage({super.key, required this.userId});

  @override
  State<CitizenCodePage> createState() => _CitizenCodePageState();
}

class _CitizenCodePageState extends State<CitizenCodePage> {
  final TextEditingController codeCtrl = TextEditingController();

  Future<void> _verifyCode() async {
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
      await prefs.setBool('isCitizenLoggedIn', true);
      await prefs.setString('userId', widget.userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم التحقق بنجاح")),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CitizenHomeScreen(userId: widget.userId),
        ),
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
            LabeledField(
              label: "أدخل الكود الذي أرسله لك الأدمن",
              controller: codeCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            primaryButton("تأكيد", _verifyCode),
          ],
        ),
      ),
    );
  }
}

/// -------------------- شاشة تسجيل المواطن الجديد --------------------
class CitizenRegisterPage extends StatefulWidget {
  const CitizenRegisterPage({super.key});

  @override
  State<CitizenRegisterPage> createState() => _CitizenRegisterPageState();
}

class _CitizenRegisterPageState extends State<CitizenRegisterPage> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();

  Future<void> _registerCitizen() async {
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال جميع البيانات")),
      );
      return;
    }

    // ignore: unused_local_variable
    var docRef = await FirebaseFirestore.instance.collection('users').add({
      "name": name,
      "phone": phone,
      "role": "citizen",
      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم إنشاء الحساب بنجاح")),
    );

    if (!mounted) return;
    Navigator.pop(context); // الرجوع لصفحة تسجيل الدخول
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل حساب جديد")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LabeledField(label: "الاسم", controller: nameCtrl),
            const SizedBox(height: 12),
            LabeledField(
              label: "رقم الهاتف",
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            primaryButton("تسجيل", _registerCitizen),
          ],
        ),
      ),
    );
  }
}
