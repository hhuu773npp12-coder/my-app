// taxi_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';
import '../notifications/notifications_screen.dart';

// ------------------- شاشة الرئيسية للسائق -------------------
class TaxiHomeScreen extends StatefulWidget {
  final String userId; // معرف السائق
  const TaxiHomeScreen({super.key, required this.userId});

  @override
  State<TaxiHomeScreen> createState() => _TaxiHomeScreenState();
}

class _TaxiHomeScreenState extends State<TaxiHomeScreen> {
  bool isActive = true;
  late String driverId;
  double walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  Future<void> _loadDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    driverId = prefs.getString('userId') ?? '';
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    if (driverId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection("taxi_drivers")
        .doc(driverId)
        .get();
    if (!mounted) return;
    if (doc.exists) {
      setState(() {
        walletBalance = (doc.data()?["balance"] ?? 0).toDouble();
        isActive = doc.data()?["active"] ?? true;
      });
    }
  }

  void _toggleActive() {
    setState(() => isActive = !isActive);
    FirebaseFirestore.instance
        .collection("taxi_drivers")
        .doc(driverId)
        .update({"active": isActive});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("مسيباوي"), centerTitle: true),
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
                IconButton(
                  icon: const Icon(Icons.list_alt, size: 30),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                TaxiOrdersScreen(driverId: driverId)));
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
              onPressed: _toggleActive,
              child: Text(isActive ? "نشط" : "غير نشط"),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------- شاشة الطلبات -------------------
class TaxiOrdersScreen extends StatelessWidget {
  final String driverId;
  const TaxiOrdersScreen({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الطلبات")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("taxi_orders")
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
                  title: Text("🚖 الطلب #${doc.id}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("👤 الاسم: ${data["customerName"] ?? ""}"),
                      Text("📞 الهاتف: ${data["phone"] ?? ""}"),
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
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => TaxiOrderTrackingScreen(
                                        driverId: driverId,
                                        orderId: doc.id,
                                        price: (data["price"] ?? 0).toDouble(),
                                      )));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection("taxi_orders")
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

// ------------------- شاشة متابعة الرحلة -------------------
class TaxiOrderTrackingScreen extends StatefulWidget {
  final String driverId;
  final String orderId;
  final double price;

  const TaxiOrderTrackingScreen(
      {super.key,
      required this.driverId,
      required this.orderId,
      required this.price});

  @override
  State<TaxiOrderTrackingScreen> createState() =>
      _TaxiOrderTrackingScreenState();
}

class _TaxiOrderTrackingScreenState extends State<TaxiOrderTrackingScreen> {
  bool reachedCustomer = false;
  bool tripStarted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("متابعة الرحلة")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!reachedCustomer)
              ElevatedButton(
                  onPressed: () {
                    setState(() => reachedCustomer = true);
                    FirebaseFirestore.instance
                        .collection("taxi_orders")
                        .doc(widget.orderId)
                        .update({"status": "arrived_customer"});
                  },
                  child: const Text("تم الوصول إلى موقع الزبون")),
            if (reachedCustomer && !tripStarted)
              ElevatedButton(
                  onPressed: () {
                    setState(() => tripStarted = true);
                    FirebaseFirestore.instance
                        .collection("taxi_orders")
                        .doc(widget.orderId)
                        .update({"status": "trip_started"});
                  },
                  child: const Text("بدأ الرحلة")),
            if (tripStarted)
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection("taxi_orders")
                        .doc(widget.orderId)
                        .update({"status": "canceled"});
                    Navigator.pop(context);
                  },
                  child: const Text("إلغاء الرحلة")),
            if (tripStarted)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent),
                onPressed: () async {
                  final firestore = FirebaseFirestore.instance;

                  // تحديث حالة الطلب إلى مكتمل
                  await firestore
                      .collection("taxi_orders")
                      .doc(widget.orderId)
                      .update({"status": "completed"});

                  // تحديث الرصيد بعد خصم 10% للمالك
                  final driverRef =
                      firestore.collection("taxi_drivers").doc(widget.driverId);
                  final ownerRef =
                      firestore.collection("app_owner").doc("owner");

                  await firestore.runTransaction((transaction) async {
                    final driverSnapshot = await transaction.get(driverRef);
                    final ownerSnapshot = await transaction.get(ownerRef);

                    final driverBalance =
                        (driverSnapshot.data()?["balance"] ?? 0).toDouble();
                    final ownerBalance =
                        (ownerSnapshot.data()?["balance"] ?? 0).toDouble();

                    final commission = widget.price * 0.10;
                    final newDriverBalance =
                        driverBalance + widget.price - commission;
                    final newOwnerBalance = ownerBalance + commission;

                    transaction
                        .update(driverRef, {"balance": newDriverBalance});
                    transaction.update(ownerRef, {"balance": newOwnerBalance});
                  });

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "✅ تم اتمام الرحلة وتم تحويل 10% من السعر للمالك")),
                  );

                  Navigator.pop(context);
                },
                child: const Text("تم اتمام الرحلة"),
              ),
          ],
        ),
      ),
    );
  }
}
