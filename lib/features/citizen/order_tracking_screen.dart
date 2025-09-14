import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String userId;

  const OrderTrackingScreen({super.key, required this.userId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع الطلبات'),
        centerTitle: true,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.green,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: "في انتظار الموافقة"),
                Tab(text: "قيد التحضير"),
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
      ),
    );
  }

  Widget _buildPendingOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("restaurant_pending_orders")
          .where("customerId", isEqualTo: widget.userId)
          .where("status", isEqualTo: "pending_restaurant_approval")
          .orderBy("createdAt", descending: true)
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
                Icon(Icons.schedule, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("لا توجد طلبات في انتظار الموافقة",
                    style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;

            return _buildOrderCard(data, "pending", Colors.orange);
          },
        );
      },
    );
  }

  Widget _buildActiveOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bike_delivery_orders")
          .where("customerId", isEqualTo: widget.userId)
          .where("status", whereIn: [
            "pending_bike_assignment",
            "assigned_to_bike",
            "in_preparation",
            "ready_for_pickup",
            "on_the_way"
          ])
          .orderBy("createdAt", descending: true)
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
                Icon(Icons.delivery_dining, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("لا توجد طلبات قيد التحضير",
                    style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;

            return _buildOrderCard(
                data, data['status'], _getStatusColor(data['status']));
          },
        );
      },
    );
  }

  Widget _buildCompletedOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bike_delivery_orders")
          .where("customerId", isEqualTo: widget.userId)
          .where("status", whereIn: ["completed", "cancelled"])
          .orderBy("createdAt", descending: true)
          .limit(20)
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
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("لا توجد طلبات مكتملة", style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;

            return _buildOrderCard(
                data, data['status'], _getStatusColor(data['status']));
          },
        );
      },
    );
  }

  Widget _buildOrderCard(
      Map<String, dynamic> data, String status, Color statusColor) {
    final items = data['items'] as List<dynamic>? ?? [];
    final totalAmount = data['totalAmount'] ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;

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
        title: Text('طلب بقيمة $totalAmount د.ع'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 ${_formatTimestamp(createdAt)}'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(status),
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
                const Text('تفاصيل الطلب:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${item['name']} - ${item['price']} د.ع'),
                    )),
                const SizedBox(height: 16),
                _buildOrderProgress(status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderProgress(String status) {
    List<String> steps = [
      "pending_restaurant_approval",
      "approved_by_restaurant",
      "pending_bike_assignment",
      "assigned_to_bike",
      "in_preparation",
      "ready_for_pickup",
      "on_the_way",
      "completed"
    ];

    List<String> stepLabels = [
      "في انتظار موافقة المطعم",
      "وافق المطعم",
      "البحث عن سائق",
      "تم تعيين سائق",
      "قيد التحضير",
      "جاهز للاستلام",
      "في الطريق إليك",
      "تم التسليم"
    ];

    int currentStepIndex = steps.indexOf(status);
    if (currentStepIndex == -1) currentStepIndex = 0;

    return Column(
      children: List.generate(stepLabels.length, (index) {
        bool isCompleted = index <= currentStepIndex;
        bool isCurrent = index == currentStepIndex;

        return Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stepLabels[index],
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "pending_restaurant_approval":
        return Colors.orange;
      case "approved_by_restaurant":
        return Colors.blue;
      case "pending_bike_assignment":
        return Colors.purple;
      case "assigned_to_bike":
        return Colors.indigo;
      case "in_preparation":
        return Colors.amber;
      case "ready_for_pickup":
        return Colors.teal;
      case "on_the_way":
        return Colors.cyan;
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
      case "pending_restaurant_approval":
        return "في انتظار موافقة المطعم";
      case "approved_by_restaurant":
        return "وافق المطعم";
      case "pending_bike_assignment":
        return "البحث عن سائق";
      case "assigned_to_bike":
        return "تم تعيين سائق";
      case "in_preparation":
        return "قيد التحضير";
      case "ready_for_pickup":
        return "جاهز للاستلام";
      case "on_the_way":
        return "في الطريق إليك";
      case "completed":
        return "تم التسليم";
      case "cancelled":
        return "ملغي";
      default:
        return "غير محدد";
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case "pending_restaurant_approval":
        return Icons.schedule;
      case "approved_by_restaurant":
        return Icons.check_circle;
      case "pending_bike_assignment":
        return Icons.search;
      case "assigned_to_bike":
        return Icons.person;
      case "in_preparation":
        return Icons.restaurant;
      case "ready_for_pickup":
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
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
