import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'features/cooling/cooling_home_screen.dart';
import 'features/sorting/first_sort_screen.dart';
import 'widgets/ui.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// ------------------- تسجيل فني التبريد -------------------
class CoolingTechnicianRegisterScreen extends StatefulWidget {
  const CoolingTechnicianRegisterScreen({super.key});

  @override
  State<CoolingTechnicianRegisterScreen> createState() =>
      _CoolingTechnicianRegisterScreenState();
}

class _CoolingTechnicianRegisterScreenState
    extends State<CoolingTechnicianRegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController skillsController = TextEditingController();

  final List<File> workImages = [];
  final ImagePicker _picker = ImagePicker();

  String generateCode() {
    final random = Random();
    return (1000 + random.nextInt(8999)).toString();
  }

  Future<void> pickImage() async {
    if (workImages.length >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ يمكنك رفع 3 صور فقط")),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        workImages.add(File(image.path));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ تم اختيار صورة رقم ${workImages.length}")),
      );
    }
  }

  Future<void> savecoolData() async {
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
            .child("cooling_technicians")
            .child("${DateTime.now().millisecondsSinceEpoch}_$i.jpg");

        await ref.putFile(workImages[i]);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      String code = generateCode();

      var userRef = await FirebaseFirestore.instance.collection("users").add({
        "name": name,
        "phone": phone,
        "skills": skills,
        "workImages": imageUrls,
        "role": "cooling_technician",
        "approved": false,
        "loginCode": code,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection("admin_codes").add({
        "userId": userRef.id,
        "userName": name,
        "role": "cooling_technician",
        "phone": phone,
        "code": code,
        "used": false,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "✅ تم إرسال طلبك إلى الأدمن، سيتم الاتصال بك بعد الموافقة")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => CoolingTechnicianWaitingScreen(userId: userRef.id)),
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
      appBar: AppBar(title: const Text("تسجيل فني التبريد")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "الاسم"),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "رقم الهاتف"),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: skillsController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "المهارات"),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                ElevatedButton(
                    onPressed: pickImage,
                    child: const Text("إضافة صورة من الأعمال")),
                const SizedBox(width: 10),
                Expanded(child: Text("✅ تم اختيار ${workImages.length} صور")),
              ],
            ),
            const SizedBox(height: 25),
            primaryButton("تسجيل", savecoolData),
          ],
        ),
      ),
    );
  }
}

/// ------------------- شاشة انتظار الموافقة -------------------
class CoolingTechnicianWaitingScreen extends StatefulWidget {
  final String userId;
  const CoolingTechnicianWaitingScreen({super.key, required this.userId});

  @override
  State<CoolingTechnicianWaitingScreen> createState() =>
      _CoolingTechnicianWaitingScreenState();
}

class _CoolingTechnicianWaitingScreenState
    extends State<CoolingTechnicianWaitingScreen> {
  @override
  void initState() {
    super.initState();
    _checkApproval();
  }

  Future<void> _checkApproval() async {
    while (mounted) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && doc['approved'] == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  CoolingTechnicianCodeScreen(userId: widget.userId)),
        );
        break;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("في انتظار الموافقة")),
      body: const Center(
        child: Text(
          "تم إرسال طلبك إلى المشرفين.\nيرجى الانتظار حتى الموافقة على حسابك.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// ------------------- تسجيل الدخول -------------------
class CoolingTechnicianLoginScreen extends StatefulWidget {
  const CoolingTechnicianLoginScreen({super.key});

  @override
  State<CoolingTechnicianLoginScreen> createState() =>
      _CoolingTechnicianLoginScreenState();
}

class _CoolingTechnicianLoginScreenState
    extends State<CoolingTechnicianLoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  Future<void> loginTechnician() async {
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
          .collection("users")
          .where("phone", isEqualTo: phone)
          .where("role", isEqualTo: "cooling_technician")
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var doc = snapshot.docs.first;
        bool approved = doc['approved'] ?? false;

        if (!approved && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => CoolingTechnicianWaitingScreen(userId: doc.id)),
          );
          return;
        }

        // حفظ تسجيل الدخول
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isCoolingLoggedIn", true);
        await prefs.setString("coolingId", doc.id);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CoolingHomeScreen(userId: doc.id)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("❌ البيانات غير صحيحة أو لم يتم تسجيلك بعد")),
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
      appBar: AppBar(title: const Text("تسجيل دخول فني التبريد")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "الاسم")),
            const SizedBox(height: 20),
            TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "رقم الهاتف")),
            const SizedBox(height: 30),
            ElevatedButton(
                onPressed: loginTechnician, child: const Text("تسجيل الدخول")),
            const SizedBox(height: 15),
            OutlinedButton(
              onPressed: () {
                if (!mounted) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const CoolingTechnicianRegisterScreen()));
              },
              child: const Text("إنشاء حساب جديد"),
            ),
            const SizedBox(height: 20),
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
          ],
        ),
      ),
    );
  }
}

/// ------------------- إدخال الكود -------------------
class CoolingTechnicianCodeScreen extends StatefulWidget {
  final String userId;
  const CoolingTechnicianCodeScreen({super.key, required this.userId});

  @override
  State<CoolingTechnicianCodeScreen> createState() =>
      _CoolingTechnicianCodeScreenState();
}

class _CoolingTechnicianCodeScreenState
    extends State<CoolingTechnicianCodeScreen> {
  final TextEditingController codeController = TextEditingController();

  Future<void> verifyCode() async {
    String inputCode = codeController.text.trim();
    if (inputCode.isEmpty || inputCode.length != 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال الكود المكون من 4 أرقام")),
      );
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "cooling_technician")
          .where("loginCode", isEqualTo: inputCode)
          .where(FieldPath.documentId, isEqualTo: widget.userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isCoolingLoggedIn", true);
        await prefs.setString("coolingId", widget.userId);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => CoolingHomeScreen(userId: widget.userId)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("❌ الكود غير صحيح")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ حدث خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدخال الكود")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("أدخل الكود المكون من 4 أرقام",
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(hintText: "XXXX"),
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: verifyCode, child: const Text("تأكيد")),
            const SizedBox(height: 15),
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
          ],
        ),
      ),
    );
  }
}
