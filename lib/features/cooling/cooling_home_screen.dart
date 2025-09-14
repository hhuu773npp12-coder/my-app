import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../craftsman/craftsman_orders_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';
import '../notifications/notifications_screen.dart';

class CoolingHomeScreen extends StatefulWidget {
  final String userId;
  const CoolingHomeScreen({super.key, required this.userId});

  @override
  State<CoolingHomeScreen> createState() => _CoolingHomeScreenState();
}

class _CoolingHomeScreenState extends State<CoolingHomeScreen> {
  String? userId;
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userId = prefs.getString("userId");
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
      appBar: AppBar(title: const Text("مسيباوي")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.person, size: 30),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(userId: userId!),
                    ),
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .doc(userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final data =
                        snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    final balance = data["balance"] ?? 0;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletPage(userId: userId!),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 30),
                          Text(
                            "$balance د.ع",
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.work, size: 30),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CraftsmanOrdersScreen(
                          craftsmanId: userId!,
                          craftsmanType: 'cooling',
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, size: 30),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.green : Colors.grey,
              ),
              onPressed: () async {
                setState(() => isActive = !isActive);
                await FirebaseFirestore.instance
                    .collection("users")
                    .doc(userId)
                    .update({"active": isActive});
              },
              child: Text(isActive ? "نشط" : "غير نشط"),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("orders")
                  .where("technicianId", isEqualTo: userId)
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
                  itemBuilder: (context, index) {
                    final doc = orders[index];
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
                        trailing: ElevatedButton(
                          onPressed: () {
                            _showOrderDetails(context, doc.id, data);
                          },
                          child: const Text("تفاصيل"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(
      BuildContext context, String orderId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("تفاصيل الطلب #$orderId"),
          content: Text(data["details"] ?? "لا توجد تفاصيل"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CoolingOrderTrackingScreen(orderId: orderId),
                  ),
                );
              },
              child: const Text("قبول الطلب"),
            ),
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection("orders")
                    .doc(orderId)
                    .update({"status": "rejected"});
                Navigator.pop(context);
              },
              child: const Text("رفض"),
            ),
          ],
        );
      },
    );
  }
}

class CoolingOrderTrackingScreen extends StatelessWidget {
  final String orderId;

  const CoolingOrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("متابعة الطلب")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection("orders")
                    .doc(orderId)
                    .update({"status": "arrived"});
              },
              child: const Text("لقد وصلت إلى موقع العمل"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                FirebaseFirestore.instance
                    .collection("orders")
                    .doc(orderId)
                    .update({"status": "canceled"});
              },
              child: const Text("إلغاء الطلب"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
              onPressed: () async {
                final firestore = FirebaseFirestore.instance;

                await firestore.collection("orders").doc(orderId).update({
                  "status": "completed",
                });

                final orderSnap =
                    await firestore.collection("orders").doc(orderId).get();
                final orderData = orderSnap.data();

                if (orderData != null) {
                  final double orderPrice =
                      (orderData["price"] ?? 0).toDouble();
                  final String technicianId = orderData["technicianId"];

                  const double commissionRate = 0.1;
                  final double commission = orderPrice * commissionRate;

                  final userRef =
                      firestore.collection("users").doc(technicianId);

                  await firestore.runTransaction((transaction) async {
                    final snapshot = await transaction.get(userRef);
                    final currentBalance =
                        (snapshot.data()?["balance"] ?? 0).toDouble();

                    transaction.update(userRef, {
                      "balance": currentBalance - commission,
                    });
                  });
                }

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ تم الطلب وتم خصم العمولة")),
                );
              },
              child: const Text("تم الطلب"),
            ),
          ],
        ),
      ),
    );
  }
}

// شاشة عرض طلباتي
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("طلباتي"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "قيد التنفيذ ⏳"),
              Tab(text: "مكتملة ✅"),
              Tab(text: "مرفوضة ❌"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList("in_progress"),
            _buildOrdersList("completed"),
            _buildOrdersList("rejected"),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("orders")
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
          itemBuilder: (context, index) {
            final data = orders[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text("👤 ${data["customerName"] ?? ""}"),
              subtitle: Text("📞 ${data["phone"] ?? ""}"),
              trailing: Text("📍 ${data["location"] ?? ""}"),
            );
          },
        );
      },
    );
  }
}
