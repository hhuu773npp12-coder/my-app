// lib/screens/owner_login_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../owner_home_page.dart';
import '../sorting/first_sort_screen.dart';

class OwnerLogin extends StatefulWidget {
  const OwnerLogin({super.key});

  @override
  State<OwnerLogin> createState() => _OwnerLoginState();
}

class _OwnerLoginState extends State<OwnerLogin> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  Future<void> _loginOwner() async {
    String name = nameCtrl.text.trim();
    String phone = phoneCtrl.text.trim();
    String password = passwordCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال جميع البيانات")),
      );
      return;
    }

    var snapshot = await FirebaseFirestore.instance
        .collection("owners")
        .where("name", isEqualTo: name)
        .where("phone", isEqualTo: phone)
        .where("password", isEqualTo: password)
        .get();

    if (!mounted) return;

    if (snapshot.docs.isNotEmpty) {
      String ownerId = snapshot.docs.first.id;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isOwnerLoggedIn', true);
      await prefs.setString('ownerId', ownerId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تسجيل الدخول ناجح")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OwnerHomePage(ownerId: ownerId)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ بيانات غير صحيحة")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول المالك")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "اسم المالك"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: "رقم الهاتف"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              decoration:
                  const InputDecoration(labelText: "الرقم السري (10 أرقام)"),
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 10,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loginOwner,
              child: const Text("تسجيل الدخول"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OwnerRegister()),
                );
              },
              child: const Text("تسجيل المالك"),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.teal),
              label: const Text(
                "العودة إلى الفرز",
                style: TextStyle(color: Colors.teal),
              ),
              onPressed: () {
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

class OwnerRegister extends StatefulWidget {
  const OwnerRegister({super.key});

  @override
  State<OwnerRegister> createState() => _OwnerRegisterState();
}

class _OwnerRegisterState extends State<OwnerRegister> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();

  Future<void> _registerOwner() async {
    String name = nameCtrl.text.trim();
    String phone = phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال جميع البيانات")),
      );
      return;
    }

    var snapshot = await FirebaseFirestore.instance.collection("owners").get();

    if (!mounted) return;

    if (snapshot.docs.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🚫 تم الوصول للحد الأقصى (2 مالك)")),
      );
      return;
    }

    String password = snapshot.docs.isEmpty ? "5497497320" : "7746521908";

    await FirebaseFirestore.instance.collection("owners").add({
      "name": name,
      "phone": phone,
      "password": password,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text("✅ تم تسجيل المالك بنجاح. الرقم السري: $password")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OwnerLogin()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل المالك")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "اسم المالك"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: "رقم الهاتف"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _registerOwner,
              child: const Text("تسجيل"),
            ),
          ],
        ),
      ),
    );
  }
}
