import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StutaHomeScreen extends StatefulWidget {
  final String userId; // معرف السائق الموحد
  const StutaHomeScreen({super.key, required this.userId});

  @override
  State<StutaHomeScreen> createState() => _StutaHomeScreenState();
}

class _StutaHomeScreenState extends State<StutaHomeScreen> {
  String? userId;
  bool isActive = true;
  double walletBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('userId');
    if (uid != null) {
      setState(() {
        userId = uid;
      });
      _loadWallet();
      _loadActiveStatus();
    }
  }

  Future<void> _loadWallet() async {
    if (userId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection("stuta_drivers")
        .doc(userId)
        .get();
    if (doc.exists) {
      setState(() {
        walletBalance = (doc.data()?["wallet"] ?? 0).toDouble();
      });
    }
  }

  Future<void> _loadActiveStatus() async {
    if (userId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection("stuta_drivers")
        .doc(userId)
        .get();
    if (doc.exists) {
      setState(() {
        isActive = (doc.data()?["active"] ?? true);
      });
    }
  }

  Future<void> _toggleActiveStatus() async {
    if (userId == null) return;
    setState(() => isActive = !isActive);
    await FirebaseFirestore.instance
        .collection("stuta_drivers")
        .doc(userId)
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
      appBar: AppBar(title: const Text("مسيباوي - الستوتة")),
      body: Column(
        children: [
          // ===== الأيقونات الرئيسية =====
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _iconButton(
                  icon: Icons.account_balance_wallet,
                  label: "المحفظة",
                  onTap: () => Navigator.pushNamed(context, "/wallet"),
                  badge: walletBalance.toInt().toString(),
                ),
                _iconButton(
                  icon: Icons.list_alt,
                  label: "الطلبات",
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => OrdersScreen(userId: userId!))),
                ),
                _iconButton(
                  icon: Icons.notifications,
                  label: "الإشعارات",
                  onTap: () => Navigator.pushNamed(context, "/notifications"),
                ),
                _iconButton(
                  icon: Icons.person,
                  label: "الملف الشخصي",
                  onTap: () => Navigator.pushNamed(context, "/profile"),
                ),
              ],
            ),
          ),
          const Divider(),
          // ===== زر الحالة =====
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

  Widget _iconButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      String? badge}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(icon: Icon(icon, size: 30), onPressed: onTap),
            if (badge != null)
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

/// ========== شاشة الطلبات ==========

class OrdersScreen extends StatelessWidget {
  final String userId;
  const OrdersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الطلبات")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("stuta_orders")
            .where("driverId", isEqualTo: userId)
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
                      Text("📍 الانطلاق: ${data["from"] ?? ""}"),
                      Text("🏁 الوجهة: ${data["to"] ?? ""}"),
                      Text("💰 السعر: ${data["price"] ?? ""} د.ع"),
                      Text("الحالة: ${data["status"] ?? "جديد"}"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => StutaOrderTrackingScreen(
                                    orderId: doc.id,
                                    data: data,
                                    userId: userId))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection("stuta_orders")
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

/// ========== متابعة الطلب ==========

class StutaOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final String userId;

  const StutaOrderTrackingScreen(
      {super.key,
      required this.orderId,
      required this.data,
      required this.userId});

  @override
  State<StutaOrderTrackingScreen> createState() =>
      _StutaOrderTrackingScreenState();
}

class _StutaOrderTrackingScreenState extends State<StutaOrderTrackingScreen> {
  int status = 0;
  final List<String> steps = [
    "تم استلام الطلب",
    "جاري التحميل",
    "في الطريق",
    "تم التسليم"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("متابعة الطلب")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LinearProgressIndicator(value: (status + 1) / steps.length),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: steps.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(
                      index <= status
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: index <= status ? Colors.green : Colors.grey,
                    ),
                    title: Text(steps[index]),
                    onTap: () async {
                      setState(() => status = index);
                      await FirebaseFirestore.instance
                          .collection("stuta_orders")
                          .doc(widget.orderId)
                          .update({"status": steps[index]});

                      // عند آخر مرحلة نضيف الخصم 10% من السعر للمالك
                      if (index == steps.length - 1) {
                        final stutaDriverRef = FirebaseFirestore.instance
                            .collection("stuta_drivers")
                            .doc(widget.userId);

                        final ownerRef = FirebaseFirestore.instance
                            .collection("owners")
                            .doc(widget.data["ownerId"]);

                        final price = (widget.data["price"] ?? 0).toDouble();
                        final fee = price * 0.1; // 10% من سعر الطلب

                        FirebaseFirestore.instance
                            .runTransaction((transaction) async {
                          // بيانات السائق
                          final driverSnap =
                              await transaction.get(stutaDriverRef);
                          final driverWallet =
                              (driverSnap.data()?["wallet"] ?? 0).toDouble();

                          // بيانات المالك
                          final ownerSnap = await transaction.get(ownerRef);
                          final ownerWallet =
                              (ownerSnap.data()?["wallet"] ?? 0).toDouble();

                          // تحديث الأرصدة
                          transaction.update(
                              stutaDriverRef, {"wallet": driverWallet - fee});
                          transaction
                              .update(ownerRef, {"wallet": ownerWallet + fee});
                        });
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
