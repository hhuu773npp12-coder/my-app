// lib/features/blacksmith/blacksmith_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../wallet/wallet_screen.dart';
import '../notifications/notifications_screen.dart';
import '../craftsman/craftsman_orders_screen.dart';
import '../profile/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlacksmithHomeScreen extends StatefulWidget {
  final String userId;
  const BlacksmithHomeScreen({super.key, required this.userId});

  @override
  State<BlacksmithHomeScreen> createState() => _BlacksmithHomeScreenState();
}

class _BlacksmithHomeScreenState extends State<BlacksmithHomeScreen> {
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
    if (!mounted) return; // ✅ حل التحذير
    setState(() => userId = prefs.getString("userId"));

    if (userId != null) {
      _listenUserData();
    }
  }

  void _listenUserData() {
    FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
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
        title: const Text("مسيباوي"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔹 شريط الأيقونات
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // البروفايل
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: userId!),
                      ),
                    );
                  },
                ),

                // المحفظة مع الرصيد
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.account_balance_wallet),
                      onPressed: () {
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WalletPage(userId: userId!),
                          ),
                        );
                      },
                    ),
                    Text(
                      "${_formatBalance(balance)} د.ع",
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                // الطلبات
                IconButton(
                  icon: const Icon(Icons.work),
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CraftsmanOrdersScreen(
                          craftsmanId: userId!,
                          craftsmanType: 'blacksmith',
                        ),
                      ),
                    );
                  },
                ),

                // الإشعارات
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NotificationsPage(userId: userId!)),
                    );
                  },
                ),
              ],
            ),
          ),

          // زر الحالة
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.green : Colors.grey,
              ),
              onPressed: () {
                setState(() => isActive = !isActive);
                FirebaseFirestore.instance
                    .collection("users")
                    .doc(userId)
                    .update({"active": isActive});
              },
              child: Text(isActive ? "نشط" : "غير نشط"),
            ),
          ),

          const Divider(),

          // الطلبات
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("orders")
                  .where("blacksmithId", isEqualTo: userId)
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
                          onPressed: () =>
                              _showOrderDetails(context, doc.id, data),
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

  // 🔹 عرض تفاصيل الطلب
  void _showOrderDetails(
      BuildContext ctx, String orderId, Map<String, dynamic> data) {
    if (!mounted) return; // ✅
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text("تفاصيل الطلب #$orderId"),
        content: Text(data["details"] ?? "لا توجد تفاصيل"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (!mounted) return;
              Navigator.push(
                ctx,
                MaterialPageRoute(
                    builder: (_) =>
                        BlacksmithOrderTrackingScreen(orderId: orderId)),
              );
            },
            child: const Text("قبول"),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection("orders")
                  .doc(orderId)
                  .update({"status": "rejected"});
              Navigator.pop(ctx);
            },
            child: const Text("رفض"),
          ),
        ],
      ),
    );
  }

  // 🔹 تنسيق الرصيد
  String _formatBalance(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
  }
}

// 🔹 شاشة تتبع الطلب
class BlacksmithOrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const BlacksmithOrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("متابعة الطلب")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection("orders")
                  .doc(orderId)
                  .update({"status": "arrived"});
            },
            child: const Text("لقد وصلت"),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection("orders")
                  .doc(orderId)
                  .update({"status": "canceled"});
            },
            child: const Text("إلغاء"),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            onPressed: () async {
              final fs = FirebaseFirestore.instance;
              await fs
                  .collection("orders")
                  .doc(orderId)
                  .update({"status": "completed"});

              final snap = await fs.collection("orders").doc(orderId).get();
              final data = snap.data();
              if (data != null) {
                final price = (data["price"] ?? 0).toDouble();
                final id = data["blacksmithId"];
                const rate = 0.1;
                final comm = price * rate;

                final ref = fs.collection("users").doc(id);
                await fs.runTransaction((t) async {
                  final s = await t.get(ref);
                  final bal = (s.data()?["balance"] ?? 0).toDouble();
                  t.update(ref, {"balance": bal - comm});
                });
              }

              if (!context.mounted) return; // ✅
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("✅ تم إنهاء الطلب وتم خصم العمولة")),
              );
            },
            child: const Text("تم الطلب"),
          ),
        ]),
      ),
    );
  }
}
