import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/sorting/first_sort_screen.dart';
// استيراد شاشة الهوم من ملف منفصل
import 'features/electrician/electrician_home_screen.dart';
import 'widgets/ui.dart';

/// ------------------ شاشة تسجيل الكهربائي ------------------
class ElectricianRegisterScreen extends StatefulWidget {
  const ElectricianRegisterScreen({super.key});

  @override
  State<ElectricianRegisterScreen> createState() =>
      _ElectricianRegisterScreenState();
}

class _ElectricianRegisterScreenState extends State<ElectricianRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController skillsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<File> workImages = [];

  Future<void> pickImage() async {
    if (workImages.length >= 3) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("❌ يمكنك رفع 3 صور فقط")));
      return;
    }
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        workImages.add(File(picked.path));
      });
    }
  }

  String generateCode() => (1000 + Random().nextInt(9000)).toString();

  Future<void> registerElectrician() async {
    if (!_formKey.currentState!.validate()) return;
    if (workImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ يجب رفع صور لأعمالك")));
      return;
    }

    try {
      List<String> uploadedUrls = [];
      for (var file in workImages) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("users/${DateTime.now().millisecondsSinceEpoch}.jpg");
        await ref.putFile(file);
        uploadedUrls.add(await ref.getDownloadURL());
      }

      String code = generateCode();

      var userRef = await FirebaseFirestore.instance.collection("users").add({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "skills": skillsController.text.trim(),
        "workImages": uploadedUrls,
        "role": "electrician",
        "approved": false,
        "loginCode": code,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم إرسال طلب التسجيل للأدمن")));

      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => PendingApprovalScreen(userId: userRef.id)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ خطأ أثناء التسجيل: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل الكهربائي")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // زر العودة إلى الفرز
              primaryButton("⬅️ العودة إلى الفرز", () {
                Navigator.pop(context);
              }),
              const SizedBox(height: 15),
              TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "الاسم"),
                  validator: (v) =>
                      v == null || v.isEmpty ? "الرجاء إدخال الاسم" : null),
              const SizedBox(height: 15),
              TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: "رقم الهاتف"),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.isEmpty
                      ? "الرجاء إدخال رقم الهاتف"
                      : null),
              const SizedBox(height: 15),
              TextFormField(
                  controller: skillsController,
                  decoration: const InputDecoration(labelText: "المهارات"),
                  maxLines: 4,
                  validator: (v) =>
                      v == null || v.isEmpty ? "الرجاء إدخال المهارات" : null),
              const SizedBox(height: 15),
              Row(
                children: [
                  primaryButton("إضافة صورة", pickImage),
                  const SizedBox(width: 10),
                  Expanded(child: Text("✅ ${workImages.length} / 3 صور")),
                ],
              ),
              const SizedBox(height: 25),
              primaryButton("تسجيل", registerElectrician),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------ شاشة انتظار الموافقة ------------------
class PendingApprovalScreen extends StatefulWidget {
  final String userId;
  const PendingApprovalScreen({super.key, required this.userId});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طلبك قيد المراجعة")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data!;
          bool approved = userData["approved"] ?? false;

          if (approved) {
            Future.microtask(() async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool("isLoggedIn", true);
              await prefs.setString("userId", widget.userId);
              await prefs.setString("role", "electrician");
              if (!mounted) return;
              Navigator.pushReplacement(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ElectricianHomeScreen(userId: widget.userId)));
            });
          }

          return const Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
                SizedBox(height: 20),
                Text("تم إرسال طلبك إلى الأدمن\nيرجى الانتظار لحين الموافقة.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18)),
              ]));
        },
      ),
    );
  }
}

class ElectricianLoginScreen extends StatefulWidget {
  const ElectricianLoginScreen({super.key});

  @override
  State<ElectricianLoginScreen> createState() => _ElectricianLoginScreenState();
}

class _ElectricianLoginScreenState extends State<ElectricianLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAlreadyLoggedIn();
  }

  Future<void> _checkAlreadyLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final userId = prefs.getString('userId') ?? '';
    final role = prefs.getString('role') ?? '';

    if (isLoggedIn && userId.isNotEmpty && role == "electrician") {
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ElectricianHomeScreen(userId: userId)));
    }
  }

  Future<void> loginElectrician() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("phone", isEqualTo: phoneController.text.trim())
          .where("role", isEqualTo: "electrician")
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ البيانات غير موجودة")));
        return;
      }

      var doc = snapshot.docs.first;
      if (!(doc["approved"] ?? false)) {
        if (!mounted) return;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => PendingApprovalScreen(userId: doc.id)));
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ElectricianHomeScreen(userId: doc.id)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول الكهربائي")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: "رقم الهاتف"),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 25),
              ElevatedButton(
                  onPressed: loginElectrician,
                  child: const Text("تسجيل الدخول")),
              const SizedBox(height: 15),
              TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ElectricianRegisterScreen())),
                  child: const Text("تسجيل جديد")),
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
      ),
    );
  }
}
