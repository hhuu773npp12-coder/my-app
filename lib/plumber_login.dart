import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/ui.dart';
import 'features/plumber/plumber_home_screen.dart';
import 'features/sorting/first_sort_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// ------------------------ تسجيل الدخول ------------------------
class PlumberLoginScreen extends StatefulWidget {
  const PlumberLoginScreen({super.key});

  @override
  State<PlumberLoginScreen> createState() => _PlumberLoginScreenState();
}

class _PlumberLoginScreenState extends State<PlumberLoginScreen> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAlreadyLoggedIn();
  }

  Future<void> _checkAlreadyLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isPlumberLoggedIn') ?? false;
    final userId = prefs.getString('plumberUserId');
    if (isLoggedIn && userId != null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PlumberHomeScreen(userId: userId)),
      );
    }
  }

  Future<void> _login() async {
    String name = nameCtrl.text.trim();
    String phone = phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ الرجاء إدخال الاسم ورقم الهاتف")),
      );
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('plumbers')
          .where('name', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      String userId;
      if (snapshot.docs.isEmpty) {
        var docRef =
            await FirebaseFirestore.instance.collection('plumbers').add({
          "name": name,
          "phone": phone,
          "approved": false,
          "createdAt": FieldValue.serverTimestamp(),
        });
        userId = docRef.id;
      } else {
        userId = snapshot.docs.first.id;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('plumbers')
          .doc(userId)
          .get();

      if (userDoc['approved'] == true) {
        String code = (1000 + Random().nextInt(9000)).toString();
        await FirebaseFirestore.instance.collection('admin_codes').add({
          "plumberId": userId,
          "name": name,
          "code": code,
          "used": false,
          "createdAt": FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PlumberCodeScreen(userId: userId)),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => PendingApprovalScreen(userId: userId)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول السباك")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(label: "الاسم", controller: nameCtrl),
            const SizedBox(height: 15),
            LabeledField(
              label: "رقم الهاتف",
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 30),
            primaryButton("تسجيل الدخول", _login),
            const SizedBox(height: 20),
            TextButton.icon(
              icon: const Icon(Icons.person_add, color: Colors.green),
              label: const Text(
                "إنشاء حساب جديد",
                style: TextStyle(color: Colors.green),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PlumberRegisterScreen()),
                );
              },
            ),
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

// ------------------------ إدخال الكود ------------------------
class PlumberCodeScreen extends StatefulWidget {
  final String userId;
  const PlumberCodeScreen({super.key, required this.userId});

  @override
  State<PlumberCodeScreen> createState() => _PlumberCodeScreenState();
}

class _PlumberCodeScreenState extends State<PlumberCodeScreen> {
  final TextEditingController codeCtrl = TextEditingController();

  Future<void> verifyCode() async {
    String inputCode = codeCtrl.text.trim();
    if (inputCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال الكود")),
      );
      return;
    }

    var snapshot = await FirebaseFirestore.instance
        .collection('admin_codes')
        .where('plumberId', isEqualTo: widget.userId)
        .where('code', isEqualTo: inputCode)
        .where('used', isEqualTo: false)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update({"used": true});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPlumberLoggedIn', true);
      await prefs.setString('plumberUserId', widget.userId);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => PlumberHomeScreen(userId: widget.userId)),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ الكود غير صحيح أو مستخدم")),
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
            LabeledField(
              label: "أدخل الكود الذي أرسله لك الأدمن",
              controller: codeCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            primaryButton("تأكيد", verifyCode),
          ],
        ),
      ),
    );
  }
}

// ------------------------ انتظار الموافقة ------------------------
class PendingApprovalScreen extends StatelessWidget {
  final String userId;
  const PendingApprovalScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طلبك قيد المراجعة")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('plumbers')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          if (data['approved'] == true) {
            Future.microtask(() {
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const PlumberLoginScreen()),
                );
              }
            });
          }

          return const Center(
            child: Text("طلبك قيد المراجعة..."),
          );
        },
      ),
    );
  }
}

// ------------------------ شاشة التسجيل ------------------------
class PlumberRegisterScreen extends StatefulWidget {
  const PlumberRegisterScreen({super.key});

  @override
  State<PlumberRegisterScreen> createState() => _PlumberRegisterScreenState();
}

class _PlumberRegisterScreenState extends State<PlumberRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController skillsController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<File> workImages = [];

  Future<void> pickImage() async {
    if (workImages.length >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ يمكنك رفع 3 صور فقط")),
      );
      return;
    }
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => workImages.add(File(picked.path)));
    }
  }

  String generateCode() => (1000 + Random().nextInt(9000)).toString();

  Future<void> registerPlumber() async {
    if (!_formKey.currentState!.validate()) return;
    if (workImages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يجب رفع صور لأعمالك")),
      );
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
        "role": "plumber",
        "approved": false,
        "loginCode": code,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم إرسال طلب التسجيل للأدمن")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => PendingApprovalScreen(userId: userRef.id)),
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
      appBar: AppBar(title: const Text("تسجيل السباك")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primaryButton("⬅️ العودة إلى الفرز", () {
                Navigator.pop(context);
              }),
              const SizedBox(height: 15),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "الاسم"),
                validator: (v) =>
                    v == null || v.isEmpty ? "الرجاء إدخال الاسم" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "رقم الهاتف"),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.isEmpty ? "الرجاء إدخال رقم الهاتف" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: skillsController,
                decoration: const InputDecoration(labelText: "المهارات"),
                maxLines: 4,
                validator: (v) =>
                    v == null || v.isEmpty ? "الرجاء إدخال المهارات" : null,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  primaryButton("إضافة صورة", pickImage),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text("✅ ${workImages.length} / 3 صور"),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              primaryButton("تسجيل", registerPlumber),
            ],
          ),
        ),
      ),
    );
  }
}
