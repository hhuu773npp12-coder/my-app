import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../wallet/wallet_screen.dart';
import '../craftsman/craftsman_orders_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';

class PlumberHomeScreen extends StatefulWidget {
  final String userId;
  const PlumberHomeScreen({super.key, required this.userId});

  @override
  State<PlumberHomeScreen> createState() => _PlumberHomeScreenState();
}

class _PlumberHomeScreenState extends State<PlumberHomeScreen> {
  String? userId;
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
      userId = prefs.getString("userId"); // ✅ جلب اليوزر الموحد
    });

    if (userId != null) {
      _listenUserData();
    }
  }

  void _listenUserData() {
    FirebaseFirestore.instance
        .collection("users") // ✅ جدول موحد
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

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text("مسيباوي")),
      ),
      body: Column(
        children: [
          // 🔹 شريط الأيقونات تحت العنوان
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(userId: userId!),
                    ),
                  ),
                ),
                // 🔹 الرصيد
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.account_balance_wallet),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletPage(userId: userId!),
                        ),
                      ),
                    ),
                    Text(
                      "${_formatBalance(balance)} د.ع",
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.work),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CraftsmanOrdersScreen(
                        craftsmanId: userId!,
                        craftsmanType: 'plumber',
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsPage(userId: userId!),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // 🔹 زر الحالة
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.green : Colors.grey,
              ),
              onPressed: () {
                setState(() => isActive = !isActive);
                FirebaseFirestore.instance
                    .collection("users") // ✅ جدول موحد
                    .doc(userId)
                    .update({"active": isActive});
              },
              child: Text(isActive ? "نشط" : "غير نشط"),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 دالة تنسيق الرصيد
  String _formatBalance(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
  }
}

// 🔹 شاشة الطلبات
class OrdersScreen extends StatelessWidget {
  final String plumberId;
  const OrdersScreen({super.key, required this.plumberId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("طلباتي"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "قيد التنفيذ"),
              Tab(text: "منجزة"),
              Tab(text: "مرفوضة"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            OrdersList(plumberId: plumberId, status: "in-progress"),
            OrdersList(plumberId: plumberId, status: "completed"),
            OrdersList(plumberId: plumberId, status: "rejected"),
          ],
        ),
      ),
    );
  }
}

// 🔹 قائمة الطلبات حسب الحالة
class OrdersList extends StatelessWidget {
  final String plumberId;
  final String status;
  const OrdersList({super.key, required this.plumberId, required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("orders") // ✅ جدول موحد
          .where("plumberId", isEqualTo: plumberId)
          .where("status", isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(child: Text("لا توجد طلبات"));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final doc = orders[i];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                title: Text("الطلب #${doc.id}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("👤 الاسم: ${data["customerName"] ?? ""}"),
                    Text("📍 الموقع: ${data["location"] ?? ""}"),
                    Text("📞 الهاتف: ${data["phone"] ?? ""}"),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
