// lib/main.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:math';
import 'features/delivery_bike/bike_dashboard.dart';
import 'features/sorting/first_sort_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final userId = prefs.getString('userId') ?? '';
  final userRole = prefs.getString('userRole') ?? '';

  runApp(MyApp(
    isLoggedIn: isLoggedIn,
    userId: userId,
    userRole: userRole,
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String userId;
  final String userRole;

  const MyApp(
      {super.key,
      required this.isLoggedIn,
      required this.userId,
      required this.userRole});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen;

    if (isLoggedIn) {
      if (userRole == 'driver') {
        homeScreen = DriverHomeScreen(userId: userId);
      } else {
        homeScreen =
            const Scaffold(body: Center(child: Text("دور المستخدم غير معروف")));
      }
    } else {
      homeScreen = const DriverLoginScreen();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تطبيق المستخدم',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: homeScreen,
    );
  }
}

/// ------------------ شاشة تسجيل الدخول للسائق ------------------
class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Future<void> _loginDriver() async {
    String name = _nameController.text.trim();
    String phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال الاسم ورقم الهاتف")),
      );
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection("drivers")
          .where("name", isEqualTo: name)
          .where("phone", isEqualTo: phone)
          .where("approved", isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var driverDoc = snapshot.docs.first;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverCodeInputScreen(driverId: driverDoc.id),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("❌ البيانات غير صحيحة أو لم يتم قبول طلبك بعد")),
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
      appBar: AppBar(title: const Text("تسجيل دخول السائق")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "الاسم"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "رقم الهاتف"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 25),
            ElevatedButton(
                onPressed: _loginDriver, child: const Text("تسجيل الدخول")),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () {
                if (!mounted) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DriverRegisterScreen()));
              },
              child: const Text("إنشاء حساب جديد"),
            ),
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

/// ------------------ شاشة تسجيل السائق ------------------
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bikeTypeController = TextEditingController();
  File? bikeImageFile;

  String generateCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  Future<void> _pickBikeImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        bikeImageFile = File(pickedFile.path);
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم اختيار صورة الدراجة")));
    }
  }

  Future<void> _registerDriver() async {
    String name = _nameController.text.trim();
    String phone = _phoneController.text.trim();
    String bikeType = _bikeTypeController.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        bikeType.isEmpty ||
        bikeImageFile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ يرجى إدخال جميع البيانات")));
      return;
    }

    String code = generateCode();

    try {
      var driverRef =
          await FirebaseFirestore.instance.collection("drivers").add({
        "name": name,
        "phone": phone,
        "bikeType": bikeType,
        "bikeImage": bikeImageFile!.path,
        "approved": false,
        "code": code,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection("admin_codes").add({
        "driverId": driverRef.id,
        "driverName": name,
        "code": code,
        "createdAt": FieldValue.serverTimestamp(),
        "used": false,
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverRequestSentScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ خطأ أثناء التسجيل: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل السائق")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "الاسم")),
            const SizedBox(height: 15),
            TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "رقم الهاتف"),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 15),
            TextField(
                controller: _bikeTypeController,
                decoration: const InputDecoration(labelText: "نوع الدراجة")),
            const SizedBox(height: 15),
            ElevatedButton(
                onPressed: _pickBikeImage,
                child: const Text("📸 إضافة صورة الدراجة")),
            const SizedBox(height: 25),
            ElevatedButton(
                onPressed: _registerDriver,
                child: const Text("🚀 التسجيل الآن")),
          ],
        ),
      ),
    );
  }
}

/// ------------------ شاشة تأكيد إرسال الطلب ------------------
class DriverRequestSentScreen extends StatelessWidget {
  const DriverRequestSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تم إرسال الطلب")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "تم إرسال طلبك إلى المشرفين\nسوف يتم الاتصال بك لتوقيع العقد",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (!context.mounted) return;
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DriverLoginScreen()));
              },
              child: const Text("العودة إلى تسجيل الدخول"),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------ شاشة إدخال الكود ------------------
class DriverCodeInputScreen extends StatefulWidget {
  final String driverId;
  const DriverCodeInputScreen({super.key, required this.driverId});

  @override
  State<DriverCodeInputScreen> createState() => _DriverCodeInputScreenState();
}

class _DriverCodeInputScreenState extends State<DriverCodeInputScreen> {
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
          .collection("admin_codes")
          .where("driverId", isEqualTo: widget.driverId)
          .where("code", isEqualTo: inputCode)
          .where("used", isEqualTo: false)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({"used": true});

        // حفظ حالة تسجيل الدخول ونظام المستخدم الموحد
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', widget.driverId);
        await prefs.setString('userRole', 'driver');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم تسجيل الدخول بنجاح")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverHomeScreen(userId: widget.driverId),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ: $e")),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("أدخل الكود المكون من 4 أرقام"),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "XXXX",
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: verifyCode, child: const Text("تأكيد")),
          ],
        ),
      ),
    );
  }
}
