import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../wallet/wallet_screen.dart';

class KiaHomeScreen extends StatefulWidget {
  final String userId; // معرف المستخدم
  const KiaHomeScreen({super.key, required this.userId});

  @override
  State<KiaHomeScreen> createState() => _KiaHomeScreenState();
}

class _KiaHomeScreenState extends State<KiaHomeScreen> {
  String? userId;
  bool isActive = true;
  double walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('userId');
    if (uid != null) {
      setState(() => userId = uid);
      _loadDriverData();
    }
  }

  Future<void> _loadDriverData() async {
    if (userId == null) return;
    FirebaseFirestore.instance
        .collection("kia_drivers")
        .doc(userId!)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        setState(() {
          walletBalance = (doc.data()?["balance"] ?? 0).toDouble();
          isActive = (doc.data()?["active"] ?? true);
        });
      }
    });
  }

  Future<void> _toggleActiveStatus() async {
    if (userId == null) return;
    setState(() => isActive = !isActive);
    await FirebaseFirestore.instance
        .collection("kia_drivers")
        .doc(userId!)
        .update({"active": isActive});
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("مسيباوي - كيا حمل")),
      body: Column(
        children: [
          // ===== شريط الأيقونات =====
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _iconWithLabel(
                  icon: Icons.person,
                  label: "الملف",
                  onTap: () => Navigator.pushNamed(context, "/profile"),
                ),
                _iconWithLabel(
                  icon: Icons.account_balance_wallet,
                  label: "$walletBalance د.ع",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => WalletPage(userId: userId!)),
                  ),
                  badge: walletBalance.toInt().toString(),
                ),
                _iconWithLabel(
                  icon: Icons.notifications,
                  label: "الإشعارات",
                  onTap: () => Navigator.pushNamed(context, "/notifications"),
                ),
                _iconWithLabel(
                  icon: Icons.list_alt,
                  label: "طلباتي",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => KiaOrdersScreen(userId: userId!)),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          // ===== زر النشاط =====
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.green : Colors.grey),
              onPressed: _toggleActiveStatus,
              child: Text(isActive ? "نشط" : "غير نشط"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconWithLabel(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      String? badge}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
                icon: Icon(icon, size: 28, color: Colors.blueAccent),
                onPressed: onTap),
            if (badge != null && badge != "0")
              Positioned(
                right: 0,
                top: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(badge,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white)),
                ),
              )
          ],
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ===== شاشة الطلبات =====
class KiaOrdersScreen extends StatelessWidget {
  final String userId;
  const KiaOrdersScreen({super.key, required this.userId});

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
              Tab(text: "مكتملة"),
              Tab(text: "مرفوضة"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList(userId, "trip_started"),
            _buildOrdersList(userId, "completed"),
            _buildOrdersList(userId, "rejected"),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(String userId, String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("kia_orders")
          .where("driverId", isEqualTo: userId)
          .where("status", isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!.docs;
        if (orders.isEmpty) return const Center(child: Text("لا توجد طلبات"));

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final doc = orders[i];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                title: Text("🚛 الطلب #${doc.id}"),
                subtitle: Text(
                    "الزبون: ${data['customerName'] ?? ''}\nالمكان: ${data['from']} → ${data['to']}\nالحالة: ${data['status'] ?? ''}"),
                trailing: status == "trip_started"
                    ? ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => KiaOrderTrackingScreen(
                                    orderId: doc.id,
                                    driverId: userId,
                                    price: (data['price'] ?? 0).toDouble())),
                          );
                        },
                        child: const Text("متابعة الطلب"),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

// ===== شاشة متابعة الطلب =====
class KiaOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String driverId;
  final double price;

  const KiaOrderTrackingScreen(
      {super.key,
      required this.orderId,
      required this.driverId,
      required this.price});

  @override
  State<KiaOrderTrackingScreen> createState() => _KiaOrderTrackingScreenState();
}

class _KiaOrderTrackingScreenState extends State<KiaOrderTrackingScreen> {
  String status = "trip_started";

  @override
  void initState() {
    super.initState();
    _listenToOrder();
  }

  void _listenToOrder() {
    FirebaseFirestore.instance
        .collection("kia_orders")
        .doc(widget.orderId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          status = data['status'] ?? 'trip_started';
        });
      }
    });
  }

  Future<void> _updateStatus(String newStatus) async {
    final firestore = FirebaseFirestore.instance;

    if (newStatus == "completed") {
      const double commissionRate = 0.1;
      final double commission = widget.price * commissionRate;

      final driverRef =
          firestore.collection("kia_drivers").doc(widget.driverId);
      final ownerRef =
          firestore.collection("admin_users").doc("owner"); // معرف المالك

      await firestore.runTransaction((transaction) async {
        // خصم 10٪ من سعر الطلب من السائق
        final driverSnap = await transaction.get(driverRef);
        final double driverBalance =
            (driverSnap.data()?["balance"] ?? 0).toDouble();
        transaction.update(driverRef, {"balance": driverBalance - commission});

        // إضافة 10٪ إلى رصيد المالك
        final ownerSnap = await transaction.get(ownerRef);
        final double ownerBalance =
            (ownerSnap.data()?["balance"] ?? 0).toDouble();
        transaction.update(ownerRef, {"balance": ownerBalance + commission});

        // تحديث حالة الطلب إلى مكتمل
        transaction.update(
            firestore.collection("kia_orders").doc(widget.orderId),
            {"status": "completed"});
      });
    } else {
      await firestore
          .collection("kia_orders")
          .doc(widget.orderId)
          .update({"status": newStatus});
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم تحديث الحالة إلى $newStatus")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("متابعة الطلب")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: status == "trip_started"
                  ? () => _updateStatus("arrived")
                  : null,
              child: const Text("لقد وصلت إلى موقع العمل"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: status != "completed"
                  ? () => _updateStatus("canceled")
                  : null,
              child: const Text("إلغاء الطلب"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
              onPressed: status != "completed"
                  ? () => _updateStatus("completed")
                  : null,
              child: const Text("تم الطلب"),
            ),
            const SizedBox(height: 12),
            Text("الحالة الحالية: $status",
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
