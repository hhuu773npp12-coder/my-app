import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/profile/profile_screen.dart';
import 'features/wallet/wallet_screen.dart';
import 'features/notifications/notifications_screen.dart';

class KiaPassengerMain extends StatefulWidget {
  final String userId; // معرف اليوزر الموحد
  const KiaPassengerMain({super.key, required this.userId});
  @override
  State<KiaPassengerMain> createState() => _KiaPassengerMainState();
}

class _KiaPassengerMainState extends State<KiaPassengerMain> {
  int _selectedIndex = 0;
  String? expandedOrderId;
  int balance = 0;
  String? userId;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  /// 🔹 تحميل المستخدم الموحد (من FirebaseAuth أو SharedPreferences)
  void _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString('userId');

    if (storedId != null) {
      userId = storedId;
      _listenBalance();
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      userId = currentUser.uid;
      await prefs.setString('userId', userId!);
      _listenBalance();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ لم يتم العثور على المستخدم الحالي")),
        );
      });
    }
  }

  /// 🔹 الاستماع للتغيرات في الرصيد
  void _listenBalance() {
    if (userId == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          balance = snapshot.data()?['balance'] ?? 0;
        });
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> get _pages => [
        buildMainOrders(),
        ProfilePage(userId: userId ?? ''),
        WalletPage(userId: userId ?? ''),
        NotificationsPage(userId: userId ?? ''),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("مسيباوي"), centerTitle: true),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.home), label: "الرئيسية"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: "الملف"),
          BottomNavigationBarItem(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.account_balance_wallet),
                if (balance > 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "$balance د.ع",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: "المحفظة",
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: "الإشعارات"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.list), label: "الطلبات"),
        ],
      ),
    );
  }

  /// 🏠 الرئيسية (طلبات الخطوط + الحملات)
  Widget buildMainOrders() {
    if (userId == null) {
      return const Center(child: Text("❌ المستخدم غير موجود"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where("userId", isEqualTo: userId)
          .where("status", whereIn: ["pending", "approved"]).snapshots(),
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
            final orderId = doc.id;

            if (data['type'] == 'line') {
              return buildLineOrderCard(orderId, data);
            } else if (data['type'] == 'campaign') {
              return buildCampaignOrderCard(orderId, data);
            } else {
              return const SizedBox.shrink();
            }
          }).toList(),
        );
      },
    );
  }

  /// 🚌 كارت طلب خط
  Widget buildLineOrderCard(String orderId, Map<String, dynamic> data) {
    final bool expanded = expandedOrderId == orderId;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          ListTile(
            title: Text("📘 ${data["school"]}"),
            subtitle: Text("عدد الطلاب: ${data["students"].length}"),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              setState(() {
                expandedOrderId = expanded ? null : orderId;
              });
            },
          ),
          if (!expanded)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => approveOrder(orderId, 0.1),
                    child: const Text("موافقة")),
                TextButton(
                    onPressed: () => rejectOrder(orderId),
                    child: const Text("رفض")),
              ],
            ),
          if (expanded)
            Column(
              children: [
                ...data["students"].map<Widget>((s) => ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(s["name"]),
                      subtitle: Text("📍 ${s["location"]} - ☎ ${s["phone"]}"),
                    )),
                ElevatedButton(
                  onPressed: () => completeOrder(orderId),
                  child: const Text("تم الرحلة اليوم"),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 🕋 كارت حملة زيارة
  Widget buildCampaignOrderCard(String orderId, Map<String, dynamic> data) {
    final bool expanded = expandedOrderId == orderId;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          ListTile(
            title: Text("🕋 حملة: ${data["shrine"]}"),
            subtitle: Text("عدد الأشخاص: ${data["members"].length}"),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              setState(() {
                expandedOrderId = expanded ? null : orderId;
              });
            },
          ),
          if (!expanded)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => approveOrder(orderId, 0.1),
                    child: const Text("موافقة")),
                TextButton(
                    onPressed: () => rejectOrder(orderId),
                    child: const Text("رفض")),
              ],
            ),
          if (expanded)
            Column(
              children: [
                ...data["members"].map<Widget>((m) => ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(m["name"]),
                      subtitle: Text("📍 ${m["location"]} - ☎ ${m["phone"]}"),
                    )),
                ElevatedButton(
                  onPressed: () => completeOrder(orderId),
                  child: const Text("تمت الرحلة"),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// ✅ وظائف التحكم بالطلبات
  void approveOrder(String orderId, double commissionRate) async {
    final docRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    final docSnap = await docRef.get();
    final data = docSnap.data();
    if (data == null) return;

    final int price = (data['price'] ?? 0).toInt();
    final int commission = (price * commissionRate).toInt();

    await docRef.update({"status": "approved", "commission": commission});
    setState(() => expandedOrderId = orderId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text("✅ تمت الموافقة، العمولة للإدارة: $commission د.ع")),
    );
  }

  void rejectOrder(String orderId) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({"status": "rejected"});
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("❌ تم رفض الطلب")));
  }

  void completeOrder(String orderId) async {
    if (userId == null) return;
    final docRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    final docSnap = await docRef.get();
    final data = docSnap.data();
    if (data == null) return;

    final int price = (data['price'] ?? 0).toInt();
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    await userRef.update({"balance": FieldValue.increment(-price)});
    await docRef.update({"status": "completed"});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ تم إنهاء الرحلة وخصم $price د.ع من رصيدك")),
    );
  }

  Future<void> addBalance(int amount) async {
    if (userId == null) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    await userRef.update({"balance": FieldValue.increment(amount)});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ تم إضافة $amount د.ع لرصيدك")),
    );
  }
}
