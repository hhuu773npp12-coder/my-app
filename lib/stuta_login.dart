import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/stuta/stuta_home_screen.dart';
import 'widgets/ui.dart';
import 'features/sorting/first_sort_screen.dart';

/// ----------------- تسجيل الستوتة بالنظام الموحد -----------------
class StutaRegisterScreen extends StatefulWidget {
  const StutaRegisterScreen({super.key});

  @override
  State<StutaRegisterScreen> createState() => _StutaRegisterScreenState();
}

class _StutaRegisterScreenState extends State<StutaRegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController colorController = TextEditingController();

  Future<void> register() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final color = colorController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال الاسم ورقم الهاتف")),
      );
      return;
    }

    final docRef = await FirebaseFirestore.instance.collection('users').add({
      "name": name,
      "phone": phone,
      "role": "stuta",
      "status": "pending",
      "color": color,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم إرسال طلب التسجيل")),
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => PendingApprovalScreen(userId: docRef.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل صاحب الستوتة")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LabeledField(label: "الاسم", controller: nameController),
            const SizedBox(height: 15),
            LabeledField(
                label: "رقم الهاتف",
                controller: phoneController,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 15),
            LabeledField(label: "لون الستوتة", controller: colorController),
            const SizedBox(height: 30),
            primaryButton("تسجيل", register),
          ],
        ),
      ),
    );
  }
}

/// ----------------- تسجيل الدخول -----------------
class StutaLoginScreen extends StatefulWidget {
  const StutaLoginScreen({super.key});

  @override
  State<StutaLoginScreen> createState() => _StutaLoginScreenState();
}

class _StutaLoginScreenState extends State<StutaLoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isStutaLoggedIn') ?? false;
    final userId = prefs.getString('userId') ?? '';
    if (isLoggedIn && userId.isNotEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => StutaHomeScreen(userId: userId)));
    }
  }

  Future<void> login() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("يرجى إدخال الاسم ورقم الهاتف")));
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .where('role', isEqualTo: 'stuta')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("البيانات غير موجودة")));
      return;
    }

    final doc = snapshot.docs.first;
    final data = doc.data();

    if (data['status'] != 'approved') {
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PendingApprovalScreen(userId: doc.id)));
      return;
    }

    final code = _generateCode();
    await FirebaseFirestore.instance.collection('user_login_requests').add({
      "userId": doc.id,
      "name": data['name'],
      "phone": data['phone'],
      "code": code,
      "timestamp": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => StutaCodeScreen(userId: doc.id)));
  }

  String _generateCode() => (1000 + Random().nextInt(8999)).toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول الستوتة")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(label: "الاسم", controller: nameController),
            const SizedBox(height: 15),
            LabeledField(
                label: "رقم الهاتف",
                controller: phoneController,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 30),
            primaryButton("تسجيل الدخول", login),
            const SizedBox(height: 20),
            TextButton.icon(
              icon: const Icon(Icons.person_add, color: Colors.green),
              label: const Text("تسجيل جديد",
                  style: TextStyle(color: Colors.green)),
              onPressed: () {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StutaRegisterScreen()),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.teal),
              label: const Text("العودة إلى الفرز",
                  style: TextStyle(color: Colors.teal)),
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

/// ----------------- إدخال الكود -----------------
class StutaCodeScreen extends StatefulWidget {
  final String userId;
  const StutaCodeScreen({super.key, required this.userId});

  @override
  State<StutaCodeScreen> createState() => _StutaCodeScreenState();
}

class _StutaCodeScreenState extends State<StutaCodeScreen> {
  final TextEditingController codeController = TextEditingController();

  Future<void> verifyCode() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('user_login_requests')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لم يتم العثور على أي كود")));
      return;
    }

    final correctCode = snapshot.docs.first['code'];
    if (codeController.text.trim() == correctCode.toString()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isStutaLoggedIn', true);
      await prefs.setString('userId', widget.userId);

      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => StutaHomeScreen(userId: widget.userId)));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("الكود غير صحيح")));
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
                label: "الكود",
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 4),
            const SizedBox(height: 20),
            primaryButton("تأكيد", verifyCode),
          ],
        ),
      ),
    );
  }
}

/// ----------------- شاشة انتظار الموافقة -----------------
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
          // استخدام addPostFrameCallback لضمان وجود context بعد البناء
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const StutaLoginScreen()));
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
