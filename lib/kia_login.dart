import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/ui.dart';
import 'features/kia/kia_home_screen.dart';
import 'features/sorting/first_sort_screen.dart';

class KiaRegisterScreen extends StatefulWidget {
  const KiaRegisterScreen({super.key});
  @override
  State<KiaRegisterScreen> createState() => _KiaRegisterScreenState();
}

class _KiaRegisterScreenState extends State<KiaRegisterScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final carNameController = TextEditingController();
  final carColorController = TextEditingController();
  final carNumberController = TextEditingController();
  final passengersController = TextEditingController();

  File? carImage;
  File? carNumberImage;
  final picker = ImagePicker();

  Future<void> pickImage(bool isCarNumber) async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isCarNumber) {
          carNumberImage = File(image.path);
        } else {
          carImage = File(image.path);
        }
      });
    }
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final carName = carNameController.text.trim();
    final carColor = carColorController.text.trim();
    final carNumber = carNumberController.text.trim();
    final passengers = passengersController.text.trim();

    if ([name, phone, carName, carColor, carNumber, passengers]
            .any((e) => e.isEmpty) ||
        carImage == null ||
        carNumberImage == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("⚠️ يرجى ملء جميع الحقول وإضافة الصور")));
      return;
    }

    try {
      final carUrl = await FirebaseStorage.instance
          .ref("kia_owners/${DateTime.now().millisecondsSinceEpoch}_car.jpg")
          .putFile(carImage!)
          .then((p0) => p0.ref.getDownloadURL());

      final carNumberUrl = await FirebaseStorage.instance
          .ref(
              "kia_owners/${DateTime.now().millisecondsSinceEpoch}_carNumber.jpg")
          .putFile(carNumberImage!)
          .then((p0) => p0.ref.getDownloadURL());

      final docRef = await FirebaseFirestore.instance.collection("users").add({
        "name": name,
        "phone": phone,
        "role": "kia",
        "status": "pending",
        "carName": carName,
        "carColor": carColor,
        "carNumber": carNumber,
        "passengers": passengers,
        "carImage": carUrl,
        "carNumberImage": carNumberUrl,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => PendingApprovalScreen(userId: docRef.id)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("❌ خطأ أثناء التسجيل: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل صاحب كيا حمل")),
      body: SingleChildScrollView(
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
            LabeledField(label: "اسم السيارة", controller: carNameController),
            const SizedBox(height: 15),
            LabeledField(label: "لون السيارة", controller: carColorController),
            const SizedBox(height: 15),
            LabeledField(label: "رقم السيارة", controller: carNumberController),
            const SizedBox(height: 15),
            Row(
              children: [
                primaryButton("📸 صورة رقم السيارة", () => pickImage(true)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(carNumberImage != null
                        ? "✅ تم الاختيار"
                        : "لم يتم الاختيار")),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                primaryButton("📸 صورة السيارة", () => pickImage(false)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(carImage != null
                        ? "✅ تم الاختيار"
                        : "لم يتم الاختيار")),
              ],
            ),
            const SizedBox(height: 15),
            LabeledField(
                label: "عدد الركاب",
                controller: passengersController,
                keyboardType: TextInputType.number),
            const SizedBox(height: 25),
            primaryButton("تسجيل", register),
          ],
        ),
      ),
    );
  }
}

class KiaLoginScreen extends StatefulWidget {
  const KiaLoginScreen({super.key});
  @override
  State<KiaLoginScreen> createState() => _KiaLoginScreenState();
}

class _KiaLoginScreenState extends State<KiaLoginScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isKiaLoggedIn') ?? false;
    final userId = prefs.getString('userId') ?? '';
    if (isLoggedIn && userId.isNotEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => KiaHomeScreen(userId: userId)));
    }
  }

  Future<void> login() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ يرجى إدخال الاسم ورقم الهاتف")));
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .where('role', isEqualTo: 'kia')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("❌ البيانات غير موجودة أو لم يتم الموافقة بعد")));
      return;
    }

    final doc = snapshot.docs.first;
    if (doc['status'] != 'approved') {
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PendingApprovalScreen(userId: doc.id)));
      return;
    }

    final code = (1000 + Random().nextInt(8999)).toString();
    await FirebaseFirestore.instance.collection('user_login_requests').add({
      "userId": doc.id,
      "name": doc['name'],
      "phone": doc['phone'],
      "code": code,
      "timestamp": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => KiaCodeScreen(userId: doc.id)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول صاحب كيا")),
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
            const SizedBox(height: 15),
            primaryButton("إنشاء حساب جديد", () {
              if (!mounted) return;
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const KiaRegisterScreen()));
            }, color: Colors.green),
            const SizedBox(height: 20),
            TextButton.icon(
              icon: const Icon(Icons.refresh, color: Colors.teal),
              label: const Text("العودة إلى الفرز",
                  style: TextStyle(color: Colors.teal)),
              onPressed: () async {
                if (!mounted) return;
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const UserSortScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class KiaCodeScreen extends StatefulWidget {
  final String userId;
  const KiaCodeScreen({super.key, required this.userId});
  @override
  State<KiaCodeScreen> createState() => _KiaCodeScreenState();
}

class _KiaCodeScreenState extends State<KiaCodeScreen> {
  final codeController = TextEditingController();

  Future<void> verifyCode() async {
    final inputCode = codeController.text.trim();
    if (inputCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("⚠️ يرجى إدخال الكود")));
      return;
    }

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
    if (inputCode == correctCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isKiaLoggedIn', true);
      await prefs.setString('userId', widget.userId);

      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => KiaHomeScreen(userId: widget.userId)));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("❌ الكود غير صحيح")));
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
          children: [
            LabeledField(
                label: "الكود",
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 4),
            const SizedBox(height: 30),
            primaryButton("تأكيد", verifyCode),
          ],
        ),
      ),
    );
  }
}

// تحويل PendingApprovalScreen إلى StatefulWidget لاستخدام mounted
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
          Future.microtask(() {
            if (!mounted) return;
            // ignore: use_build_context_synchronously
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const KiaLoginScreen()));
          });
        }
        return Scaffold(
          appBar: AppBar(title: const Text("طلبك قيد المراجعة")),
          body: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
                SizedBox(height: 20),
                Text(
                  "طلبك قيد المراجعة",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  "تم إرسال طلبك إلى المشرفين\n"
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
