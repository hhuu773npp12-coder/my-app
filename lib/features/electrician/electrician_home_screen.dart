import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';
import '../notifications/notifications_screen.dart';
import '../craftsman/craftsman_orders_screen.dart';

class ElectricianHomeScreen extends StatefulWidget {
  final String userId;
  const ElectricianHomeScreen({super.key, required this.userId});

  @override
  State<ElectricianHomeScreen> createState() => _ElectricianHomeScreenState();
}

class _ElectricianHomeScreenState extends State<ElectricianHomeScreen> {
  String? userId; // المستخدم الموحد
  bool isActive = true;
  int balance = 0;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString("userId");
    });

    if (userId != null) {
      _listenBalance();
    }
  }

  void _listenBalance() {
    FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        setState(() {
          balance = (doc.data()?["balance"] ?? 0).toInt();
          isActive = doc.data()?["active"] ?? true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("مسيباوي"),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // أيقونات الوصول السريع
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTopIcon(context, "ملفي", Icons.person, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(userId: userId!),
                      ),
                    );
                  }),
                  _buildTopIcon(
                      context, "المحفظة", Icons.account_balance_wallet, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WalletPage(userId: userId!),
                      ),
                    );
                  }),
                  Column(
                    children: [
                      const Icon(Icons.monetization_on,
                          color: Colors.green, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        "${_formatBalance(balance)} د.ع",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  _buildTopIcon(context, "الطلبات", Icons.work, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CraftsmanOrdersScreen(
                          craftsmanId: userId!,
                          craftsmanType: 'electrician',
                        ),
                      ),
                    );
                  }),
                  _buildTopIcon(context, "الإشعارات", Icons.notifications, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            NotificationsPage(userId: userId ?? ""),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // زر التبديل بين نشط / غير نشط
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.green : Colors.grey,
                  minimumSize: const Size(120, 40),
                ),
                onPressed: () {
                  setState(() => isActive = !isActive);
                  FirebaseFirestore.instance
                      .collection("users")
                      .doc(userId)
                      .update({"active": isActive});
                },
                child: Text(isActive ? "نشط" : "غير نشط",
                    style: const TextStyle(fontSize: 16)),
              ),
            ),

            const Divider(),

            // تبويب "طلباتي"
            const TabBar(
              labelColor: Colors.blueAccent,
              indicatorColor: Colors.blueAccent,
              tabs: [
                Tab(text: "قيد التنفيذ"),
                Tab(text: "مكتملة"),
                Tab(text: "مرفوضة"),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  _buildOrdersList("in-progress"),
                  _buildOrdersList("completed"),
                  _buildOrdersList("rejected"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // تنسيق الرصيد مع الفواصل
  String _formatBalance(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
  }

  // دالة لإضافة رصيد للمحفظة (محفوظة للاستخدام المستقبلي)
// ignore: unused_element
  Future<void> _addBalance(int amount) async {
    if (userId == null) return;
    final doc = FirebaseFirestore.instance.collection("users").doc(userId);
    await doc.update({"balance": FieldValue.increment(amount)});
  }

  // أيقونات الوصول السريع
  Widget _buildTopIcon(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 30, color: Colors.blueAccent),
          const SizedBox(height: 6),
          Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // عرض الطلبات حسب الحالة
  Widget _buildOrdersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("orders")
          .where("electricianId", isEqualTo: userId)
          .where("status", isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(
            child: Text("لا توجد طلبات",
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final data = orders[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(8),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.work, color: Colors.blueAccent),
                title: Text("العميل: ${data["customerName"] ?? ""}"),
                subtitle: Text("📍 ${data["location"] ?? ""}"),
                trailing: Text(
                  data["status"] ?? "",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
