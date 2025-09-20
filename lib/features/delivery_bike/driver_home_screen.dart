import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';
import '../notifications/notifications_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final String userId;
  const DriverHomeScreen({super.key, required this.userId});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool isActive = true;
  String driverId = "";
  double walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('userId');
    if (uid == null) return;

    setState(() {
      driverId = uid;
    });

    final doc = await FirebaseFirestore.instance
        .collection("delivery_drivers")
        .doc(driverId)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      if (!mounted) return;
      setState(() {
        walletBalance = (data["balance"] ?? 0).toDouble();
        isActive = data["active"] ?? true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (driverId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("مسيباوي - سائق التوصيل"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.person, size: 30),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfilePage(userId: driverId)));
                  },
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.account_balance_wallet, size: 30),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => WalletPage(userId: driverId)));
                      },
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Text("${walletBalance.toInt()} د.ع",
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("assignedRequests")
                      .where("driverId", isEqualTo: driverId)
                      .where("status", isEqualTo: "pending")
                      .snapshots(),
                  builder: (context, snapshot) {
                    int newOrdersCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.list_alt, size: 30),
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        DeliveryOrdersScreen(driverId: driverId)));
                          },
                        ),
                        if (newOrdersCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$newOrdersCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, size: 30),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                NotificationsPage(userId: driverId)));
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.green : Colors.grey),
              onPressed: () {
                setState(() => isActive = !isActive);
                FirebaseFirestore.instance
                    .collection("delivery_drivers")
                    .doc(driverId)
                    .update({"active": isActive});
              },
              child: Text(isActive ? "نشط" : "غير نشط"),
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryOrdersScreen extends StatelessWidget {
  final String driverId;
  const DeliveryOrdersScreen({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طلبات التوصيل")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("delivery_orders")
            .where("driverId", isEqualTo: driverId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!.docs;
          if (orders.isEmpty) {
            return const Center(child: Text("لا توجد طلبات متاحة"));
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final doc = orders[i];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text("🚚 الطلب #${doc.id}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("👤 العميل: ${data["customerName"] ?? ""}"),
                      Text("📞 الهاتف: ${data["phone"] ?? ""}"),
                      Text("📍 من: ${data["from"] ?? ""}"),
                      Text("🏁 إلى: ${data["to"] ?? ""}"),
                      Text("💰 السعر: ${data["price"] ?? ""} د.ع"),
                      Text("الحالة: ${data["status"] ?? "جديد"}"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection("delivery_orders")
                              .doc(doc.id)
                              .update({"status": "accepted"});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection("delivery_orders")
                              .doc(doc.id)
                              .update({"status": "rejected"});
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
