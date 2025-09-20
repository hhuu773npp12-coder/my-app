// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/profile/profile_screen.dart';
import 'features/wallet/wallet_screen.dart';

class TuktukHomeScreen extends StatefulWidget {
  final String userId; // معرف المستخدم
  const TuktukHomeScreen({super.key, required this.userId});

  @override
  State<TuktukHomeScreen> createState() => _TuktukHomeScreenState();
}

class _TuktukHomeScreenState extends State<TuktukHomeScreen> {
  bool isActive = true;
  String driverId = "";
  double walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  // 🔹 تحميل بيانات السائق من SharedPreferences وFirestore
  Future<void> _loadDriverData() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('userId'); // معرف المستخدم الموحد
    if (uid == null) return;

    setState(() {
      driverId = uid;
    });

    // جلب حالة النشاط والرصيد
    final doc = await FirebaseFirestore.instance
        .collection("tuktuk_drivers")
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

  // تحديث رصيد المحفظة بعد أي عملية
  Future<void> _updateWalletBalance(double amount) async {
    if (driverId.isEmpty) return;
    final driverRef =
        FirebaseFirestore.instance.collection("tuktuk_drivers").doc(driverId);
    await driverRef.update({
      "balance": FieldValue.increment(amount),
    });
    await _loadDriverData(); // إعادة تحميل الرصيد لتحديث الواجهة
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
        title: const Text("مسيباوي"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // أيقونات تحت العنوان
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
                            builder: (_) => ProfilePage(
                                userId:
                                    driverId))); // يعتمد على المستخدم الموحد
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
                                builder: (_) => WalletPage(
                                    userId:
                                        driverId))); // يعتمد على المستخدم الموحد
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
                                TuktukOrdersScreen(driverId: driverId)));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, size: 30),
                  onPressed: () {
                    Navigator.pushNamed(context, "/notifications");
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          // زر الحالة
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.green : Colors.grey),
              onPressed: () {
                setState(() => isActive = !isActive);
                FirebaseFirestore.instance
                    .collection("tuktuk_drivers")
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

// ------------------- شاشة الطلبات -------------------
class TuktukOrdersScreen extends StatelessWidget {
  final String driverId;
  const TuktukOrdersScreen({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الطلبات")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("tuktuk_orders")
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
                  title: Text("🚕 الطلب #${doc.id}"),
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
                          final scaffoldContext = context; // حفظ الـ context
                          Navigator.push(
                              scaffoldContext,
                              MaterialPageRoute(
                                  builder: (_) => TuktukOrderTrackingScreen(
                                      driverId: driverId,
                                      orderId: doc.id,
                                      price: (data["price"] ?? 0).toDouble())));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection("tuktuk_orders")
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

// ------------------- متابعة الرحلة -------------------
class TuktukOrderTrackingScreen extends StatefulWidget {
  final String driverId;
  final String orderId;
  final double price;

  const TuktukOrderTrackingScreen(
      {super.key,
      required this.driverId,
      required this.orderId,
      required this.price});

  @override
  State<TuktukOrderTrackingScreen> createState() =>
      _TuktukOrderTrackingScreenState();
}

class _TuktukOrderTrackingScreenState extends State<TuktukOrderTrackingScreen> {
  bool reachedCustomer = false;
  bool tripStarted = false;

  @override
  Widget build(BuildContext context) {
    final scaffoldContext = context; // حماية الـ context

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
                        .collection("tuktuk_orders")
                        .doc(widget.orderId)
                        .update({"status": "arrived_customer"});
                  },
                  child: const Text("تم الوصول إلى موقع الزبون")),
            if (reachedCustomer && !tripStarted)
              ElevatedButton(
                  onPressed: () {
                    setState(() => tripStarted = true);
                    FirebaseFirestore.instance
                        .collection("tuktuk_orders")
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
                        .collection("tuktuk_orders")
                        .doc(widget.orderId)
                        .update({"status": "canceled"});
                    Navigator.pop(scaffoldContext);
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
                      .collection("tuktuk_orders")
                      .doc(widget.orderId)
                      .update({"status": "completed"});

                  // خصم العمولة 10% من الرصيد
                  final driverRef = firestore
                      .collection("tuktuk_drivers")
                      .doc(widget.driverId);

                  await firestore.runTransaction((transaction) async {
                    final snapshot = await transaction.get(driverRef);
                    final currentBalance =
                        (snapshot.data()?["balance"] ?? 0).toDouble();
                    final commission = widget.price * 0.10;
                    final newBalance =
                        currentBalance + widget.price - commission;

                    transaction.update(driverRef, {"balance": newBalance});
                  });

                  if (!mounted) return; // حماية الـ State
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "✅ تم اتمام الرحلة وتم تحديث الرصيد بعد خصم العمولة")),
                  );

                  // ignore: use_build_context_synchronously
                  Navigator.pop(scaffoldContext);
                },
                child: const Text("تم اتمام الرحلة"),
              ),
          ],
        ),
      ),
    );
  }
}
