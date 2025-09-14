import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  final String userId; // ربط الملف الشخصي بالمستخدم الموحد
  const ProfilePage({super.key, required this.userId});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  File? _image;
  String userName = "اسم المستخدم";
  String phoneNumber = "07700000000";
  String? imageUrl;
  bool isLoading = false;

  final firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ✅ جلب بيانات المستخدم
  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot doc =
          await firestore.collection("users").doc(widget.userId).get();
      if (doc.exists && mounted) {
        setState(() {
          userName = doc["name"] ?? "اسم المستخدم";
          phoneNumber = doc["phone"] ?? "07700000000";
          imageUrl = doc["imageUrl"];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ أثناء جلب البيانات: $e")),
        );
      }
    }
  }

  // ✅ رفع صورة جديدة وتحديثها
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      File file = File(picked.path);
      if (mounted) setState(() => isLoading = true);

      try {
        String fileName =
            "${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        UploadTask uploadTask = FirebaseStorage.instance
            .ref()
            .child("profile_images")
            .child(fileName)
            .putFile(file);

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await firestore.collection("users").doc(widget.userId).update({
          "imageUrl": downloadUrl,
        });

        if (mounted) {
          setState(() {
            _image = file;
            imageUrl = downloadUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ تم تحديث الصورة بنجاح")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ حدث خطأ أثناء رفع الصورة: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  // ✅ تعديل الاسم أو رقم الهاتف
  Future<void> _editField(String field, String currentValue) async {
    TextEditingController controller =
        TextEditingController(text: currentValue);

    String? result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("تعديل $field"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "أدخل $field الجديد"),
        ),
        actions: [
          TextButton(
            child: const Text("إلغاء"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("حفظ"),
            onPressed: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (mounted) setState(() => isLoading = true);
      try {
        await firestore.collection("users").doc(widget.userId).update({
          field == "الاسم" ? "name" : "phone": result,
        });

        if (mounted) {
          setState(() {
            if (field == "الاسم") userName = result;
            if (field == "رقم الهاتف") phoneNumber = result;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ تم حفظ التعديلات بنجاح")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ حدث خطأ أثناء الحفظ: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  // ✅ تسجيل الخروج
  void _logout() async {
    if (mounted) Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الملف الشخصي")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _image != null
                      ? FileImage(_image!)
                      : (imageUrl != null ? NetworkImage(imageUrl!) : null)
                          as ImageProvider?,
                  child: (_image == null && imageUrl == null)
                      ? const Text("👤", style: TextStyle(fontSize: 40))
                      : null,
                ),
                Positioned(
                  bottom: -5,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: Colors.blue, size: 35),
                    onPressed: isLoading ? null : _pickImage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(userName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed:
                      isLoading ? null : () => _editField("الاسم", userName),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(phoneNumber,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: isLoading
                      ? null
                      : () => _editField("رقم الهاتف", phoneNumber),
                ),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text("تسجيل الخروج"),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
