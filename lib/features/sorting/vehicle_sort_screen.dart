import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../driver_login.dart';
import '../../kia_passenger_login.dart';
import '../../stuta_login.dart';
import '../../kia_login.dart';
import '../../tuktuk_login.dart';
import '../../taxi_login.dart';

class VehicleSortScreen extends StatefulWidget {
  const VehicleSortScreen({super.key});

  @override
  State<VehicleSortScreen> createState() => _VehicleSortScreenState();
}

class _VehicleSortScreenState extends State<VehicleSortScreen> {
  Future<void> _finishFirstRun(String role, Widget page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firstRunVehicle', false); // حفظ أنه تم الدخول

    if (!mounted) return; // حماية من استخدام context بعد async
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _confirmAndNavigate(String role, Widget page) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الاختيار"),
        content: Text("هل أنت متأكد أنك ترغب باختيار \"$role\"؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("إلغاء")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("تأكيد")),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      _finishFirstRun(role, page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'name': 'صاحب التكسي',
        'icon': Icons.local_taxi,
        'page': const TaxiLoginPage(),
        'color': Colors.yellow
      },
      {
        'name': 'صاحب التكتك',
        'icon': Icons.two_wheeler,
        'page': const TuktukLoginPage(),
        'color': Colors.orange
      },
      {
        'name': 'صاحب كيا حمل',
        'icon': Icons.local_shipping,
        'page': const KiaLoginScreen(),
        'color': Colors.blueGrey
      },
      {
        'name': 'صاحب ستوتة',
        'icon': Icons.electric_scooter,
        'page': const StutaLoginScreen(),
        'color': Colors.purple
      },
      {
        'name': 'صاحب كيا نقل الركاب',
        'icon': Icons.people,
        'page': const KiaPassengerLoginScreen(),
        'color': Colors.blue
      },
      {
        'name': 'صاحب دراجة',
        'icon': Icons.motorcycle,
        'page': const DriverLoginScreen(),
        'color': Colors.green
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('حدد نوع مركبتك:')),
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
                onTap: () => _confirmAndNavigate(
                    item['name'] as String, item['page'] as Widget),
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
