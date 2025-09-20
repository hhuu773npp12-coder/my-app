import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/blacksmith/blacksmith_home_screen.dart';
import 'features/sorting/first_sort_screen.dart';
import '../../widgets/ui.dart';

/// ------------------ شاشة تسجيل دخول الحداد ------------------
class BlacksmithLoginScreen extends StatefulWidget {
  const BlacksmithLoginScreen({super.key});

  @override
  State<BlacksmithLoginScreen> createState() => _BlacksmithLoginScreenState();
}

class _BlacksmithLoginScreenState extends State<BlacksmithLoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  Future<void> loginBlacksmith() async {
    String name = nameController.text.trim();
    String phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال الاسم ورقم الهاتف")),
      );
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection("blacksmiths")
          .where("name", isEqualTo: name)
          .where("phone", isEqualTo: phone)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        var doc = snapshot.docs.first;

        if (doc["approved"] == true) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BlacksmithCodeScreen(userId: doc.id),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("⏳ طلبك بانتظار موافقة الأدمن، سيتم الاتصال بك")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ البيانات غير صحيحة")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول الحداد")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "الاسم"),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "رقم الهاتف"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 30),
            primaryButton("تسجيل الدخول", loginBlacksmith),
            const SizedBox(height: 15),
            primaryButton("إنشاء حساب جديد", () {
              if (!mounted) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BlacksmithRegisterScreen()));
            }),
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

/// ------------------ شاشة تسجيل الحداد ------------------
class BlacksmithRegisterScreen extends StatefulWidget {
  const BlacksmithRegisterScreen({super.key});

  @override
  State<BlacksmithRegisterScreen> createState() =>
      _BlacksmithRegisterScreenState();
}

class _BlacksmithRegisterScreenState extends State<BlacksmithRegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController skillsController = TextEditingController();

  final List<File> workImages = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage() async {
    if (workImages.length >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يمكنك رفع 3 صور فقط")),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!mounted) return;
      setState(() {
        workImages.add(File(image.path));
      });
    }
  }

  String generateCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  Future<void> saveBlacksmithData() async {
    String name = nameController.text.trim();
    String phone = phoneController.text.trim();
    String skills = skillsController.text.trim();

    if (name.isEmpty || phone.isEmpty || skills.isEmpty || workImages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى ملء جميع الحقول وإضافة صور")),
      );
      return;
    }

    try {
      List<String> imageUrls = [];
      for (int i = 0; i < workImages.length; i++) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("blacksmiths")
            .child("${DateTime.now().millisecondsSinceEpoch}_$i.jpg");

        await ref.putFile(workImages[i]);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      String code = generateCode();

      var blacksmithRef =
          await FirebaseFirestore.instance.collection("blacksmiths").add({
        "name": name,
        "phone": phone,
        "skills": skills,
        "images": imageUrls,
        "approved": false,
        "code": code,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection("admin_codes").add({
        "userId": blacksmithRef.id,
        "userName": name,
        "role": "blacksmith",
        "phone": phone,
        "code": code,
        "used": false,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "✅ تم إرسال طلبك إلى الأدمن، سيتم الاتصال بك لتوقيع العقد")),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BlacksmithLoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ خطأ أثناء التسجيل: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل الحداد")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "الاسم"),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "رقم الهاتف"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: skillsController,
              decoration: const InputDecoration(labelText: "المهارات"),
              maxLines: 4,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                primaryButton("إضافة صورة من الأعمال", pickImage),
                const SizedBox(width: 10),
                Text("✅ ${workImages.length} صور مختارة"),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              children: workImages.map((file) {
                return Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.file(file,
                      width: 80, height: 80, fit: BoxFit.cover),
                );
              }).toList(),
            ),
            const SizedBox(height: 25),
            primaryButton("تسجيل", saveBlacksmithData),
          ],
        ),
      ),
    );
  }
}

/// ------------------ شاشة إدخال الكود ------------------
class BlacksmithCodeScreen extends StatefulWidget {
  final String userId;
  const BlacksmithCodeScreen({super.key, required this.userId});

  @override
  State<BlacksmithCodeScreen> createState() => _BlacksmithCodeScreenState();
}

class _BlacksmithCodeScreenState extends State<BlacksmithCodeScreen> {
  final TextEditingController codeController = TextEditingController();

  Future<void> verifyCode() async {
    String inputCode = codeController.text.trim();
    if (inputCode.isEmpty || inputCode.length != 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال كود مكون من 4 أرقام")),
      );
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection("admin_codes")
          .where("userId", isEqualTo: widget.userId)
          .where("code", isEqualTo: inputCode)
          .where("used", isEqualTo: false)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({"used": true});

        // حفظ حالة تسجيل الدخول بنظام المستخدم الموحد
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', widget.userId);
        await prefs.setString('userRole', 'blacksmith');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم تسجيل الدخول بنجاح")),
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BlacksmithHomeScreen(userId: widget.userId),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ الكود غير صحيح أو تم استخدامه")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("خطأ أثناء التحقق: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدخال الكود")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("أدخل الكود المكون من 4 أرقام",
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextFormField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: "الكود",
                hintText: "XXXX",
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 30),
            primaryButton("تأكيد", verifyCode),
          ],
        ),
      ),
    );
  }
}
