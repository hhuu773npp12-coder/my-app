import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'vehicle_sort_screen.dart';
import 'admin_sort_screen.dart';
import 'crafts_sort_screen.dart';
import '../auth/restaurant_auth_screen.dart';
import '../auth/citizen_auth_screen.dart';

class UserSortScreen extends StatefulWidget {
  const UserSortScreen({super.key});

  @override
  State<UserSortScreen> createState() => _UserSortScreenState();
}

class _UserSortScreenState extends State<UserSortScreen> {
  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!mounted) return; // ✅ حماية BuildContext

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("تم السماح بالإشعارات");
      String? token = await messaging.getToken();
      debugPrint("Device Token: $token");
    } else {
      debugPrint("لم يتم السماح بالإشعارات");
    }

    // الاستماع للرسائل أثناء فتح التطبيق
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        debugPrint('عنوان: ${message.notification!.title}');
        debugPrint('نص: ${message.notification!.body}');
      }
    });
  }

  Future<void> _finishFirstRun(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('firstRunUserSort', false);

    if (!mounted) return; // ✅ حماية BuildContext

    Widget nextScreen;

    switch (role) {
      case 'مواطن':
        nextScreen = const CitizenLoginScreen();
        break;
      case 'صاحب مركبة':
        nextScreen = const VehicleSortScreen();
        break;
      case 'صاحب حرفة':
        nextScreen = const CraftsSortScreen();
        break;
      case 'صاحب مطعم':
        nextScreen = const RestaurantLoginScreen();
        break;
      case 'الأدمن':
        nextScreen = const AdminSortScreen();
        break;
      default:
        nextScreen = const Scaffold(
          body: Center(child: Text('واجهة غير محددة')),
        );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  Future<void> _confirmRole(String role) async {
    if (!mounted) return;

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
      _finishFirstRun(role);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {'title': 'مواطن', 'icon': Icons.person},
      {'title': 'صاحب مركبة', 'icon': Icons.directions_car},
      {'title': 'صاحب حرفة', 'icon': Icons.handyman},
      {'title': 'صاحب مطعم', 'icon': Icons.restaurant},
      {'title': 'الأدمن', 'icon': Icons.admin_panel_settings},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('حدد نوعك:')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _confirmRole(items[i]['title'] as String),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          Colors.blueAccent.withAlpha(25), // ✅ بديل withOpacity
                      child: Icon(items[i]['icon'] as IconData,
                          color: Colors.blueAccent),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      items[i]['title'] as String,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
