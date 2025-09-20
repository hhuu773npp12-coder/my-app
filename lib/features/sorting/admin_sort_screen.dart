import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/owner_register.dart';
import '../auth/admin_register.dart';

class AdminSortScreen extends StatefulWidget {
  const AdminSortScreen({super.key});

  @override
  State<AdminSortScreen> createState() => _AdminSortScreenState();
}

class _AdminSortScreenState extends State<AdminSortScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _finishFirstRun(Widget loginPage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firstRunAdmin', false);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => loginPage),
    );
  }

  Future<void> _confirmAndNavigate(String role, Widget page) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("تأكيد الاختيار"),
        content: Text("هل أنت متأكد أنك ترغب باختيار \"$role\"؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _finishFirstRun(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فرز الأدمن')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _confirmAndNavigate(
                    "مشرف (أدمن)", const AdminLoginScreen()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          size: 40, color: Colors.blueAccent),
                      SizedBox(width: 16),
                      Text("مشرف (أدمن)",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _confirmAndNavigate("مالك", const OwnerLogin()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, size: 40, color: Colors.green),
                      SizedBox(width: 16),
                      Text("مالك",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
