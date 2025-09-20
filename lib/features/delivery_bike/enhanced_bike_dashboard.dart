import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EnhancedBikeDashboard extends StatefulWidget {
  final String bikeId;
  final String bikeName;

  const EnhancedBikeDashboard({
    super.key,
    required this.bikeId,
    required this.bikeName,
  });

  @override
  State<EnhancedBikeDashboard> createState() => _EnhancedBikeDashboardState();
}

class _EnhancedBikeDashboardState extends State<EnhancedBikeDashboard> {
  int _selectedIndex = 0;
  bool isAvailable = true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      BikeOrdersPage(bikeId: widget.bikeId),
      BikeStatsPage(bikeId: widget.bikeId),
      BikeProfilePage(bikeId: widget.bikeId),
    ];
    _loadAvailabilityStatus();
  }

  Future<void> _loadAvailabilityStatus() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.bikeId)
          .get();
      if (doc.exists) {
        setState(() {
          isAvailable =
              (doc.data() as Map<String, dynamic>)['available'] ?? true;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _toggleAvailability() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.bikeId)
          .update({
        'available': !isAvailable,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });

      setState(() {
        isAvailable = !isAvailable;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isAvailable ? 'أصبحت متاحاً للطلبات' : 'أصبحت غير متاح'),
            backgroundColor: isAvailable ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث الحالة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مسيباوي - ${widget.bikeName}'),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            child: ElevatedButton.icon(
              onPressed: _toggleAvailability,
              icon: Icon(
                isAvailable ? Icons.delivery_dining : Icons.pause_circle,
                color: Colors.white,
              ),
              label: Text(
                isAvailable ? 'متاح' : 'غير متاح',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isAvailable ? Colors.green : Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: "الطلبات",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: "الإحصائيات",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "الملف الشخصي",
          ),
        ],
      ),
    );
  }
}

/// صفحة طلبات الدراجة
class BikeOrdersPage extends StatelessWidget {
  final String bikeId;

  const BikeOrdersPage({super.key, required this.bikeId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "طلبات جديدة"),
              Tab(text: "قيد التنفيذ"),
              Tab(text: "مكتملة"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPendingOrders(),
                _buildActiveOrders(),
                _buildCompletedOrders(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bike_order_assignments")
          .where("bikeId", isEqualTo: bikeId)
          .where("status", isEqualTo: "pending")
          .orderBy("assignedAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("لا توجد طلبات جديدة", style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;

            return _buildOrderCard(context, order.id, data, "pending");
          },
        );
      },
    );
  }

  Widget _buildActiveOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bike_order_assignments")
          .where("bikeId", isEqualTo: bikeId)
          .where("status", whereIn: ["accepted", "picked_up", "on_the_way"])
          .orderBy("assignedAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(
            child: Text("لا توجد طلبات قيد التنفيذ",
                style: TextStyle(fontSize: 18)),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;

            return _buildOrderCard(context, order.id, data, data['status']);
          },
        );
      },
    );
  }

  Widget _buildCompletedOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bike_order_assignments")
          .where("bikeId", isEqualTo: bikeId)
          .where("status", whereIn: ["completed", "cancelled"])
          .orderBy("assignedAt", descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(
            child: Text("لا توجد طلبات مكتملة", style: TextStyle(fontSize: 18)),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;

            return _buildOrderCard(context, order.id, data, data['status']);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, String orderId,
      Map<String, dynamic> data, String status) {
    final customerName = data['customerName'] ?? 'غير محدد';
    final customerPhone = data['customerPhone'] ?? 'غير محدد';
    final totalAmount = data['totalAmount'] ?? 0;
    final assignedAt = data['assignedAt'] as Timestamp?;

    Color statusColor = _getStatusColor(status);
    String statusText = _getStatusText(status);

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(
            _getStatusIcon(status),
            color: Colors.white,
          ),
        ),
        title: Text('طلب من $customerName'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📞 $customerPhone'),
            Text('💰 المبلغ: $totalAmount د.ع',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('📅 ${_formatTimestamp(assignedAt)}'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status == "pending") ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _acceptOrder(context, orderId),
                          icon: const Icon(Icons.check),
                          label: const Text('قبول الطلب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rejectOrder(context, orderId),
                          icon: const Icon(Icons.close),
                          label: const Text('رفض'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (status == "accepted") ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        _updateOrderStatus(context, orderId, "picked_up"),
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('تم استلام الطلب'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                  ),
                ] else if (status == "picked_up") ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        _updateOrderStatus(context, orderId, "on_the_way"),
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('في الطريق للعميل'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ] else if (status == "on_the_way") ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        _updateOrderStatus(context, orderId, "completed"),
                    icon: const Icon(Icons.done_all),
                    label: const Text('تم التسليم'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "accepted":
        return Colors.blue;
      case "picked_up":
        return Colors.purple;
      case "on_the_way":
        return Colors.indigo;
      case "completed":
        return Colors.green;
      case "cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case "pending":
        return "في انتظار الرد";
      case "accepted":
        return "مقبول";
      case "picked_up":
        return "تم الاستلام";
      case "on_the_way":
        return "في الطريق";
      case "completed":
        return "مكتمل";
      case "cancelled":
        return "ملغي";
      default:
        return "غير محدد";
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case "pending":
        return Icons.schedule;
      case "accepted":
        return Icons.check_circle;
      case "picked_up":
        return Icons.shopping_bag;
      case "on_the_way":
        return Icons.delivery_dining;
      case "completed":
        return Icons.done_all;
      case "cancelled":
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير محدد';
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _acceptOrder(BuildContext context, String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection("bike_order_assignments")
          .doc(orderId)
          .update({
        "status": "accepted",
        "acceptedAt": FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول الطلب'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في قبول الطلب: $e')),
        );
      }
    }
  }

  Future<void> _rejectOrder(BuildContext context, String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection("bike_order_assignments")
          .doc(orderId)
          .update({
        "status": "cancelled",
        "cancelledAt": FieldValue.serverTimestamp(),
        "cancelReason": "رفض من السائق",
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض الطلب'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفض الطلب: $e')),
        );
      }
    }
  }

  Future<void> _updateOrderStatus(
      BuildContext context, String orderId, String newStatus) async {
    try {
      Map<String, dynamic> updateData = {
        "status": newStatus,
        "${newStatus}At": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection("bike_order_assignments")
          .doc(orderId)
          .update(updateData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('تم تحديث حالة الطلب إلى ${_getStatusText(newStatus)}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث الطلب: $e')),
        );
      }
    }
  }
}

/// صفحة إحصائيات الدراجة
class BikeStatsPage extends StatelessWidget {
  final String bikeId;

  const BikeStatsPage({super.key, required this.bikeId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getBikeStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard('طلبات اليوم', '${stats['todayOrders']}',
                  Icons.today, Colors.blue),
              _buildStatCard('طلبات الشهر', '${stats['monthlyOrders']}',
                  Icons.calendar_month, Colors.green),
              _buildStatCard(
                  'الأرباح الشهرية',
                  '${stats['monthlyEarnings'].toInt()} د.ع',
                  Icons.monetization_on,
                  Colors.orange),
              _buildStatCard(
                  'متوسط التقييم',
                  '${stats['averageRating'].toStringAsFixed(1)} ⭐',
                  Icons.star,
                  Colors.amber),
              _buildStatCard(
                  'معدل الإكمال',
                  '${stats['completionRate'].toStringAsFixed(1)}%',
                  Icons.check_circle,
                  Colors.teal),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 40, color: color),
        title: Text(title),
        subtitle: Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<Map<String, dynamic>> _getBikeStats() async {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime startOfMonth = DateTime(today.year, today.month, 1);

    // طلبات اليوم
    QuerySnapshot todayOrders = await FirebaseFirestore.instance
        .collection("bike_order_assignments")
        .where("bikeId", isEqualTo: bikeId)
        .where("assignedAt", isGreaterThan: Timestamp.fromDate(startOfDay))
        .get();

    // طلبات الشهر
    QuerySnapshot monthlyOrders = await FirebaseFirestore.instance
        .collection("bike_order_assignments")
        .where("bikeId", isEqualTo: bikeId)
        .where("assignedAt", isGreaterThan: Timestamp.fromDate(startOfMonth))
        .get();

    // الطلبات المكتملة
    QuerySnapshot completedOrders = await FirebaseFirestore.instance
        .collection("bike_order_assignments")
        .where("bikeId", isEqualTo: bikeId)
        .where("status", isEqualTo: "completed")
        .where("assignedAt", isGreaterThan: Timestamp.fromDate(startOfMonth))
        .get();

    // حساب الأرباح
    double monthlyEarnings = 0;
    for (var doc in completedOrders.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      monthlyEarnings += (data['deliveryFee'] ?? 0).toDouble();
    }

    // حساب معدل الإكمال
    double completionRate = monthlyOrders.docs.isNotEmpty
        ? (completedOrders.docs.length / monthlyOrders.docs.length) * 100
        : 0;

    // جلب التقييمات
    QuerySnapshot ratings = await FirebaseFirestore.instance
        .collection("driverRatings")
        .where("driverId", isEqualTo: bikeId)
        .get();

    double averageRating = 0;
    if (ratings.docs.isNotEmpty) {
      double totalRating = 0;
      for (var doc in ratings.docs) {
        totalRating += (doc.data() as Map<String, dynamic>)['rating'] ?? 0;
      }
      averageRating = totalRating / ratings.docs.length;
    }

    return {
      "todayOrders": todayOrders.docs.length,
      "monthlyOrders": monthlyOrders.docs.length,
      "monthlyEarnings": monthlyEarnings,
      "averageRating": averageRating,
      "completionRate": completionRate,
    };
  }
}

/// صفحة الملف الشخصي للدراجة
class BikeProfilePage extends StatelessWidget {
  final String bikeId;

  const BikeProfilePage({super.key, required this.bikeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(bikeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Text(
                  (data['name'] ?? 'د').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data['name'] ?? 'غير محدد',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                data['phone'] ?? 'غير محدد',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _buildInfoCard(
                  'الرصيد الحالي',
                  '${(data['balance'] ?? 0).toInt()} د.ع',
                  Icons.account_balance_wallet),
              _buildInfoCard(
                  'المنطقة', data['region'] ?? 'غير محدد', Icons.location_on),
              _buildInfoCard(
                  'نوع الخدمة', data['serviceType'] ?? 'غير محدد', Icons.work),
              _buildInfoCard('تاريخ التسجيل', _formatDate(data['createdAt']),
                  Icons.calendar_today),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle:
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'غير محدد';
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
