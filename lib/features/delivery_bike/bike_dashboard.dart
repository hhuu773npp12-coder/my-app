import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';
import '../notifications/notifications_screen.dart';

class DriverHomeScreen extends StatelessWidget {
  final String userId; // المستخدم الموحد
  const DriverHomeScreen({super.key, required this.userId});

  Color _statusColor(String status) {
    switch (status) {
      case "in_progress":
        return Colors.orange.shade300;
      case "completed":
        return Colors.green.shade300;
      case "rejected":
        return Colors.red.shade300;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مسيباوي",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔹 الشريط العلوي مع الصورة والرصيد والإشعارات والطلبات
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection("users")
                .doc(userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()));
              }
              final data = snapshot.data!.data() as Map<String, dynamic>;

              final userName = data["name"] ?? "المستخدم"; // الآن مستخدم
              final imageUrl = data["imageUrl"];
              final balance = (data["balance"] ?? 0).toDouble();

              return Container(
                padding: const EdgeInsets.all(10),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // صورة الملف الشخصي
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfilePage(userId: userId)),
                      ),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundImage:
                            imageUrl != null ? NetworkImage(imageUrl) : null,
                        child: imageUrl == null
                            ? const Icon(Icons.person, size: 30)
                            : null,
                      ),
                    ),
                    Column(
                      children: [
                        Text(userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        IconButton(
                          tooltip: "المحفظة",
                          icon: const Icon(Icons.account_balance_wallet,
                              size: 30),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => WalletPage(userId: userId)),
                          ),
                        ),
                        Text("$balance د.ع",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    IconButton(
                      tooltip: "الإشعارات",
                      icon: const Icon(Icons.notifications, size: 30),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => NotificationsPage(userId: userId)),
                      ),
                    ),
                    IconButton(
                      tooltip: "طلباتي",
                      icon: const Icon(Icons.list_alt, size: 30),
                      onPressed: () => _showOrdersDialog(context),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // 🔹 الطلبات الجديدة
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("orders")
                  .where("driverId", isEqualTo: userId)
                  .where("status", isEqualTo: "new")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!.docs;
                if (orders.isEmpty) {
                  return const Center(child: Text("لا توجد طلبات جديدة"));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final data = order.data() as Map<String, dynamic>;
                      final orderId = order.id;

                      return Card(
                        color: _statusColor(data["status"] ?? ""),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: ListTile(
                          title:
                              Text("الطلب من ${data["restaurant"] ?? "مطعم"}"),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("👤 ${data["customerName"] ?? ""}"),
                              Text("📍 ${data["location"] ?? ""}"),
                              Text("📞 ${data["phone"] ?? ""}"),
                              Text("💵 ${data["price"] ?? 0} د.ع"),
                              Text("🚚 توصيل: ${data["deliveryFee"] ?? 0} د.ع"),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                tooltip: "قبول الطلب",
                                onPressed: () async {
                                  final mealPrice =
                                      (data["price"] ?? 0).toDouble();
                                  final deliveryFee =
                                      (data["deliveryFee"] ?? 0).toDouble();

                                  final commission = 1000 + (deliveryFee * 0.1);
                                  final totalDeduction = mealPrice + commission;

                                  final userRef = FirebaseFirestore.instance
                                      .collection("users")
                                      .doc(userId);

                                  await FirebaseFirestore.instance
                                      .runTransaction((transaction) async {
                                    final userSnap =
                                        await transaction.get(userRef);
                                    final currentBalance =
                                        (userSnap["balance"] ?? 0).toDouble();

                                    if (currentBalance >= totalDeduction) {
                                      transaction.update(userRef, {
                                        "balance":
                                            currentBalance - totalDeduction,
                                      });

                                      transaction.update(
                                        FirebaseFirestore.instance
                                            .collection("orders")
                                            .doc(orderId),
                                        {"status": "in_progress"},
                                      );
                                    } else {
                                      if (!context.mounted) {
                                        return; // حماية context
                                      }
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "رصيدك غير كافي لقبول هذا الطلب")),
                                      );
                                    }
                                  });
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                tooltip: "رفض الطلب",
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection("orders")
                                      .doc(orderId)
                                      .update({"status": "rejected"});
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showOrdersDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text("طلباتي"),
              bottom: const TabBar(
                tabs: [
                  Tab(text: "قيد التنفيذ"),
                  Tab(text: "المنجزة"),
                  Tab(text: "المرفوضة"),
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
      },
    );
  }

  Widget _buildOrdersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("orders")
          .where("driverId", isEqualTo: userId)
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

        return ListView(
          children: orders.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text("📍 ${data["location"] ?? ""}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("💵 ${data["price"] ?? 0} د.ع"),
                  Text("🚚 توصيل: ${data["deliveryFee"] ?? 0} د.ع"),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
