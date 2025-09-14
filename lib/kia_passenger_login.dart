import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ui.dart';
import 'kia_passenger_home_screen.dart'; // الشاشة الرئيسية
import 'features/sorting/first_sort_screen.dart';

/// ===========================
/// شاشة تسجيل دخول صاحب كيا الركاب
/// ===========================
class KiaPassengerLoginScreen extends StatefulWidget {
  const KiaPassengerLoginScreen({super.key});

  @override
  State<KiaPassengerLoginScreen> createState() =>
      _KiaPassengerLoginScreenState();
}

class _KiaPassengerLoginScreenState extends State<KiaPassengerLoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isKiaPassengerLoggedIn') ?? false;
    final userId = prefs.getString('kiaPassengerUserId') ?? '';

    if (isLoggedIn && userId.isNotEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => KiaPassengerMain(userId: userId)),
      );
    }
  }

  Future<void> loginPassenger() async {
    String name = nameController.text.trim();
    String phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ الرجاء إدخال الاسم ورقم الهاتف")),
      );
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("kia_passengers")
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

      final doc = snapshot.docs.first;
      final userId = doc.id;
      final data = doc.data();

      if (data['isApproved'] == true) {
        String code = (1000 + Random().nextInt(8999)).toString();
        await FirebaseFirestore.instance
            .collection("kia_passengers")
            .doc(userId)
            .update({"loginCode": code});

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => KiaPassengerCodeScreen(userId: userId)),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => PendingRequestScreen(userId: userId)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ حدث خطأ: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل دخول صاحب كيا الركاب")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LabeledField(label: "الاسم", controller: nameController),
            const SizedBox(height: 20),
            PhoneField(controller: phoneController),
            const SizedBox(height: 30),
            primaryButton("تسجيل جديد", () {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const KiaPassengerRegisterScreen()),
              );
            }),
            const SizedBox(height: 15),
            primaryButton("تسجيل الدخول", loginPassenger),
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

/// ===========================
/// شاشة إدخال الكود
/// ===========================
class KiaPassengerCodeScreen extends StatefulWidget {
  final String userId;
  const KiaPassengerCodeScreen({super.key, required this.userId});

  @override
  State<KiaPassengerCodeScreen> createState() => _KiaPassengerCodeScreenState();
}

class _KiaPassengerCodeScreenState extends State<KiaPassengerCodeScreen> {
  final TextEditingController codeController = TextEditingController();

  Future<void> verifyCode() async {
    final inputCode = codeController.text.trim();
    if (inputCode.length != 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ الكود يجب أن يكون 4 أرقام")),
      );
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection("kia_passengers")
        .doc(widget.userId)
        .get();
    final data = doc.data();

    if (data != null && data["loginCode"] == inputCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isKiaPassengerLoggedIn', true);
      await prefs.setString('kiaPassengerUserId', widget.userId);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => KiaPassengerMain(userId: widget.userId)),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: codeController,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "الكود"),
            ),
            const SizedBox(height: 30),
            primaryButton("تأكيد", verifyCode),
          ],
        ),
      ),
    );
  }
}

/// ===========================
/// شاشة تسجيل مستخدم جديد
/// ===========================
class KiaPassengerRegisterScreen extends StatefulWidget {
  const KiaPassengerRegisterScreen({super.key});

  @override
  State<KiaPassengerRegisterScreen> createState() =>
      _KiaPassengerRegisterScreenState();
}

class _KiaPassengerRegisterScreenState
    extends State<KiaPassengerRegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController carNameController = TextEditingController();
  final TextEditingController carColorController = TextEditingController();
  final TextEditingController carNumberController = TextEditingController();
  final TextEditingController passengersController = TextEditingController();

  String? carNumberImage;
  String? carImage;

  Future<void> pickImage(bool isCarNumber) async {
    setState(() {
      if (isCarNumber) {
        carNumberImage = "📷 تم اختيار صورة رقم السيارة";
      } else {
        carImage = "📷 تم اختيار صورة السيارة";
      }
    });
  }

  Future<void> registerPassenger() async {
    String name = nameController.text.trim();
    String phone = phoneController.text.trim();
    String carName = carNameController.text.trim();
    String carColor = carColorController.text.trim();
    String carNumber = carNumberController.text.trim();
    int passengers = int.tryParse(passengersController.text.trim()) ?? 0;

    if (name.isEmpty ||
        phone.isEmpty ||
        carName.isEmpty ||
        carColor.isEmpty ||
        carNumber.isEmpty ||
        passengers == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى ملء جميع الحقول")),
      );
      return;
    }

    try {
      final docRef =
          await FirebaseFirestore.instance.collection("kia_passengers").add({
        "name": name,
        "phone": phone,
        "carName": carName,
        "carColor": carColor,
        "carNumber": carNumber,
        "passengers": passengers,
        "carImage": carImage ?? "",
        "carNumberImage": carNumberImage ?? "",
        "isApproved": false,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => PendingRequestScreen(userId: docRef.id)),
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
      appBar: AppBar(title: const Text("تسجيل صاحب كيا الركاب")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(label: "الاسم", controller: nameController),
            const SizedBox(height: 15),
            PhoneField(controller: phoneController),
            const SizedBox(height: 15),
            LabeledField(label: "اسم السيارة", controller: carNameController),
            const SizedBox(height: 15),
            LabeledField(label: "لون السيارة", controller: carColorController),
            const SizedBox(height: 15),
            LabeledField(label: "رقم السيارة", controller: carNumberController),
            const SizedBox(height: 15),
            Row(
              children: [
                primaryButton("إضافة صورة رقم السيارة", () => pickImage(true)),
                const SizedBox(width: 10),
                Expanded(child: Text(carNumberImage ?? "لم يتم الاختيار")),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                primaryButton("إضافة صورة السيارة", () => pickImage(false)),
                const SizedBox(width: 10),
                Expanded(child: Text(carImage ?? "لم يتم الاختيار")),
              ],
            ),
            const SizedBox(height: 15),
            LabeledField(
              label: "عدد الركاب",
              controller: passengersController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 25),
            primaryButton("تسجيل", registerPassenger),
          ],
        ),
      ),
    );
  }
}

/// ===========================
/// شاشة الطلب قيد المراجعة
/// ===========================
class PendingRequestScreen extends StatelessWidget {
  final String userId;
  const PendingRequestScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طلبك قيد المراجعة")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("kia_passengers")
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!;
          bool isApproved = data["isApproved"] ?? false;

          if (isApproved) {
            Future.microtask(() async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isKiaPassengerLoggedIn', true);
              await prefs.setString('kiaPassengerUserId', userId);

              Navigator.pushReplacement(
                // ignore: use_build_context_synchronously
                context,
                MaterialPageRoute(
                    builder: (_) => KiaPassengerMain(userId: userId)),
              );
            });
          }

          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
                SizedBox(height: 20),
                Text(
                  "تم إرسال طلبك إلى المشرفين",
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
          );
        },
      ),
    );
  }
}
