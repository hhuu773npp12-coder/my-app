import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../blacksmith_login.dart';
import '../../cooling_technician_login.dart';
import '../../electrician_login.dart';
import '../../plumber_login.dart';

class CraftsSortScreen extends StatefulWidget {
  const CraftsSortScreen({super.key});

  @override
  State<CraftsSortScreen> createState() => _CraftsSortScreenState();
}

class _CraftsSortScreenState extends State<CraftsSortScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    await SharedPreferences.getInstance();

    if (!mounted) return; // حماية قبل setState
    setState(() {});
  }

  Future<void> _confirmAndNavigate(String role) async {
    bool? confirmed;

    // حماية dialog من أي مشاكل async
    if (!mounted) return;
    confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تأكيد الاختيار"),
        content: Text('هل أنت متأكد أنك ترغب باختيار "$role"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _finishFirstRun(role);
    }
  }

  Future<void> _finishFirstRun(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firstRunCrafts', false);

    if (!mounted) return; // حماية قبل أي استخدام context
    _navigateToLogin(role);
  }

  void _navigateToLogin(String role) {
    Widget screen;

    switch (role) {
      case 'كهربائي':
        screen = const ElectricianLoginScreen();
        break;
      case 'فني تبريد':
        screen = const CoolingTechnicianLoginScreen();
        break;
      case 'سباك':
        screen = const PlumberLoginScreen();
        break;
      case 'حداد':
        screen = const BlacksmithLoginScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'name': 'كهربائي',
        'icon': Icons.electrical_services,
        'color': Colors.orange
      },
      {'name': 'فني تبريد', 'icon': Icons.ac_unit, 'color': Colors.blue},
      {'name': 'سباك', 'icon': Icons.plumbing, 'color': Colors.green},
      {'name': 'حداد', 'icon': Icons.construction, 'color': Colors.brown},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('حدد مهنتك:')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final item = items[i];
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _confirmAndNavigate(item['name'] as String),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(item['icon'] as IconData,
                          size: 40, color: item['color'] as Color),
                      const SizedBox(width: 16),
                      Text(item['name'] as String,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
