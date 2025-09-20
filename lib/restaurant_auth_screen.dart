// lib/features/restaurant/restaurant_screens.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/ui.dart'; // زر رئيسي جاهز
import 'features/restaurant/restaurant_dashboard.dart';

// ------------------ تسجيل الدخول ------------------
class RestaurantLoginScreen extends StatefulWidget {
  const RestaurantLoginScreen({super.key});
  @override
  State<RestaurantLoginScreen> createState() => _RestaurantLoginScreenState();
}

class _RestaurantLoginScreenState extends State<RestaurantLoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  Future<void> _login() async {
    String name = nameController.text.trim();
    String phone = phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال الاسم ورقم الهاتف")),
      );
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection("restaurants")
        .where("name", isEqualTo: name)
        .where("phone", isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ البيانات غير موجودة")),
      );
      return;
    }

    final restaurantId = snapshot.docs.first.id;
    final isApproved = snapshot.docs.first.get("isApproved") ?? false;

    if (!isApproved) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PendingApprovalScreen(restaurantId: restaurantId),
        ),
      );
      return;
    }

    // توليد كود وإرساله للأدمن
    String code = (1000 + Random().nextInt(9000)).toString();
    await FirebaseFirestore.instance.collection("admin_codes").add({
      "userId": restaurantId,
      "userName": name,
      "role": "restaurant",
      "phone": phone,
      "code": code,
      "used": false,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantCodeScreen(userId: restaurantId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول صاحب المطعم")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "الاسم",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "رقم الهاتف",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            primaryButton(
              "تسجيل جديد",
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RestaurantRegisterScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            primaryButton("تسجيل الدخول", _login),
          ],
        ),
      ),
    );
  }
}

// ------------------ شاشة انتظار الموافقة ------------------
class PendingApprovalScreen extends StatelessWidget {
  final String restaurantId;
  const PendingApprovalScreen({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("restaurants")
          .doc(restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final isApproved = snapshot.data!['isApproved'] ?? false;
          if (isApproved) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RestaurantLoginScreen(),
                  ),
                );
              }
            });
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text("طلبك قيد المراجعة")),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
                SizedBox(height: 20),
                Text(
                  "تم إرسال طلبك إلى الأدمن",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "لا يمكنك تسجيل الدخول إلا بعد الموافقة.\n"
                  "سوف يتم الاتصال بك لتوقيع عقد مع الشركة.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------ واجهة إدخال الكود ------------------
class RestaurantCodeScreen extends StatefulWidget {
  final String userId;
  const RestaurantCodeScreen({super.key, required this.userId});

  @override
  State<RestaurantCodeScreen> createState() => _RestaurantCodeScreenState();
}

class _RestaurantCodeScreenState extends State<RestaurantCodeScreen> {
  final TextEditingController codeController = TextEditingController();

  Future<void> _verifyCode() async {
    final code = codeController.text.trim();
    if (code.isEmpty || code.length != 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ أدخل كود مكون من 4 أرقام")),
      );
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection("admin_codes")
        .where("userId", isEqualTo: widget.userId)
        .where("code", isEqualTo: code)
        .where("used", isEqualTo: false)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update({"used": true});

      // حفظ تسجيل الدخول بنظام المستخدم الموحد
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', widget.userId);
      await prefs.setString('userRole', 'restaurant');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantOwnerApp(restaurantId: widget.userId),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextFormField(
              controller: codeController,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "الكود",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            primaryButton("تأكيد الكود", _verifyCode),
          ],
        ),
      ),
    );
  }
}

// ------------------ تسجيل صاحب المطعم ------------------
class RestaurantRegisterScreen extends StatefulWidget {
  const RestaurantRegisterScreen({super.key});

  @override
  State<RestaurantRegisterScreen> createState() =>
      _RestaurantRegisterScreenState();
}

class _RestaurantRegisterScreenState extends State<RestaurantRegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  Future<void> _register() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال جميع البيانات")),
      );
      return;
    }

    final restaurantRef =
        await FirebaseFirestore.instance.collection("restaurants").add({
      "name": name,
      "phone": phone,
      "isApproved": false,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PendingApprovalScreen(restaurantId: restaurantRef.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل صاحب المطعم")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "الاسم",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "رقم الهاتف",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            primaryButton("تسجيل", _register),
          ],
        ),
      ),
    );
  }
}
