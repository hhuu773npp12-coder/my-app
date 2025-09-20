// lib/screens/admin_register_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/ui.dart';
import '../admin/admin_dashboard.dart'; // رابط AdminHomePage
import '../sorting/first_sort_screen.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final List<String> secretCodes = [
    "5648930127",
    "5864937952",
    "6987541022",
    "5566778899",
    "3318652098",
    "0286379210",
    "7832014296",
    "1980376890",
    "4762108329",
    "9830247562",
  ];

  Future<void> _registerAdmin() async {
    String name = _nameController.text.trim();
    String phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال جميع البيانات")),
      );
      return;
    }

    if (!RegExp(r'^(07\d{9})$').hasMatch(phone)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📵 الرجاء إدخال رقم عراقي صحيح")),
      );
      return;
    }

    var snapshot = await FirebaseFirestore.instance.collection("admins").get();
    int currentAdmins = snapshot.docs.length;

    if (currentAdmins >= 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🚫 تم الوصول للحد الأقصى (10 أدمن)")),
      );
      return;
    }

    String assignedCode = secretCodes[currentAdmins];

    var docRef = await FirebaseFirestore.instance.collection("admins").add({
      "name": name,
      "phone": phone,
      "secretCode": assignedCode,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // حفظ adminId في SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("adminId", docRef.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم التسجيل بنجاح")),
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل الأدمن")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            inputField("اسم الأدمن", _nameController),
            const SizedBox(height: 10),
            inputField("رقم الهاتف", _phoneController,
                inputType: TextInputType.phone),
            const SizedBox(height: 20),
            primaryButton("تسجيل", _registerAdmin),
            secondaryButton("عودة لتسجيل الدخول", () {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  Future<void> _loginAdmin() async {
    String name = _nameController.text.trim();
    String phone = _phoneController.text.trim();
    String code = _codeController.text.trim();

    if (name.isEmpty || phone.isEmpty || code.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال جميع البيانات")),
      );
      return;
    }

    var snapshot = await FirebaseFirestore.instance
        .collection("admins")
        .where("name", isEqualTo: name)
        .where("phone", isEqualTo: phone)
        .where("secretCode", isEqualTo: code)
        .get();

    if (snapshot.docs.isNotEmpty) {
      String adminId = snapshot.docs.first.id;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdminLoggedIn', true);
      await prefs.setString("adminId", adminId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم تسجيل الدخول بنجاح")),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminHomePage(adminId: adminId)),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ البيانات غير صحيحة")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول الأدمن")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- حقول تسجيل الدخول ---
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "اسم الأدمن",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "رقم الهاتف",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              obscureText: true,
              maxLength: 10,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "الرمز السري (10 أرقام)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loginAdmin,
              child: const Text("تسجيل الدخول"),
            ),

            const SizedBox(height: 20),

            // --- زر إنشاء حساب جديد ---
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminRegisterScreen()),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text("إنشاء حساب جديد"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            // --- زر إعادة اختيار الفرز ---
            TextButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.teal),
              label: const Text(
                "إعادة اختيار الفرز",
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
