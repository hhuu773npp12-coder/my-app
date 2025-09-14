import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  final String userId;
  const NotificationsPage({super.key, required this.userId});

  @override
  State<NotificationsPage> createState() => NotificationsPageState();
}

class NotificationsPageState extends State<NotificationsPage> {
  String? userRole;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!mounted) return; // ✅ التأكد من أن الـ widget ما زال موجودًا

      if (userDoc.exists) {
        setState(() {
          userRole = userDoc.data()?['role'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ خطأ أثناء جلب بيانات المستخدم: $e")),
      );
    }
  }

  // ✅ تعليم الإشعار كمقروء
  Future<void> _markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الإشعارات")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔹 شريط الأيقونات
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTopIcon(context, "ملفي", Icons.account_circle, () {
                        if (!mounted) return;
                        Navigator.pushNamed(context, "/profile",
                            arguments: widget.userId);
                      }),
                      _buildTopIcon(
                          context, "المحفظة", Icons.account_balance_wallet, () {
                        if (!mounted) return;
                        Navigator.pushNamed(context, "/wallet",
                            arguments: widget.userId);
                      }),
                      // 🔹 أيقونة الإشعارات مع عداد غير المقروءة
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('notifications')
                            .where('role', isEqualTo: userRole)
                            .where('read', isEqualTo: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          int unreadCount = 0;
                          if (snapshot.hasData) {
                            unreadCount = snapshot.data!.docs.length;
                          }
                          return Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications, size: 30),
                                onPressed: () {},
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    constraints: const BoxConstraints(
                                        minWidth: 20, minHeight: 20),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      _buildTopIcon(context, "طلباتي", Icons.list_alt, () {
                        if (!mounted) return;
                        Navigator.pushNamed(context, "/orders",
                            arguments: widget.userId);
                      }),
                    ],
                  ),
                ),

                const Divider(),

                // 🔹 قائمة الإشعارات
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.userId)
                        .collection('notifications')
                        .where('role', isEqualTo: userRole)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text("لا توجد إشعارات"));
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final isRead = data['read'] ?? false;
                          final timestamp = data['timestamp'] as Timestamp?;
                          final formattedDate = timestamp != null
                              ? DateFormat("yyyy-MM-dd HH:mm")
                                  .format(timestamp.toDate())
                              : "";

                          return ListTile(
                            tileColor: isRead ? Colors.white : Colors.blue[50],
                            leading: const Icon(Icons.notifications_active),
                            title: Text(data['title'] ?? "بدون عنوان"),
                            subtitle: Text(data['message'] ?? ""),
                            trailing: Text(
                              formattedDate,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () {
                              if (!isRead) {
                                _markAsRead(docs[index].id);
                              }
                            },
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

  Widget _buildTopIcon(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // ✅ استبدال withOpacity deprecated
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.blueAccent.withAlpha(25),
            child: Icon(icon, size: 30, color: Colors.blueAccent),
          ),
          const SizedBox(height: 6),
          Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
