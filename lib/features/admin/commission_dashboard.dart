import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CommissionDashboard extends StatefulWidget {
  final String adminId;

  const CommissionDashboard({super.key, required this.adminId});

  @override
  State<CommissionDashboard> createState() => _CommissionDashboardState();
}

class _CommissionDashboardState extends State<CommissionDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String selectedPeriod = 'monthly';
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة العمولات'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          _buildDateSelector(),
          Expanded(
            child: _buildCommissionStats(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('الفترة: ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButton<String>(
              value: selectedPeriod,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('يومي')),
                DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
                DropdownMenuItem(value: 'monthly', child: Text('شهري')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedPeriod = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('التاريخ: ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    selectedDate = date;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getCommissionStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('لا توجد بيانات عمولات للفترة المحددة'),
          );
        }

        return _buildCommissionList(snapshot.data!.docs);
      },
    );
  }

  Stream<QuerySnapshot> _getCommissionStream() {
    DateTime startDate, endDate;

    switch (selectedPeriod) {
      case 'daily':
        startDate =
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        endDate = startDate.add(const Duration(days: 1));
        break;
      case 'weekly':
        startDate =
            selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
        break;
      case 'monthly':
      default:
        startDate = DateTime(selectedDate.year, selectedDate.month, 1);
        endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
        break;
    }

    return _firestore
        .collection('commission_logs')
        .where('timestamp', isGreaterThanOrEqualTo: startDate)
        .where('timestamp', isLessThan: endDate)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Widget _buildCommissionList(List<QueryDocumentSnapshot> docs) {
    double totalCommission = 0;
    Map<String, double> serviceCommissions = {};
    Map<String, int> serviceOrders = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final commission = (data['commission'] ?? 0).toDouble();
      final service = data['service'] ?? 'غير محدد';

      totalCommission += commission;
      serviceCommissions[service] =
          (serviceCommissions[service] ?? 0) + commission;
      serviceOrders[service] = (serviceOrders[service] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSummaryCard(totalCommission, docs.length),
          const SizedBox(height: 16),
          _buildServiceBreakdown(serviceCommissions, serviceOrders),
          const SizedBox(height: 16),
          _buildRecentTransactions(docs.take(10).toList()),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double total, int orderCount) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'ملخص العمولات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Colors.green, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '${total.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text('إجمالي العمولات'),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.shopping_cart,
                        color: Colors.blue, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '$orderCount',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text('عدد الطلبات'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceBreakdown(
      Map<String, double> serviceCommissions, Map<String, int> serviceOrders) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفصيل العمولات حسب الخدمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...serviceCommissions.entries.map((entry) {
              final service = entry.key;
              final commission = entry.value;
              final orders = serviceOrders[service] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(service,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('$orders طلب',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text(
                      '${commission.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(List<QueryDocumentSnapshot> docs) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'آخر المعاملات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final commission = (data['commission'] ?? 0).toDouble();
              final service = data['service'] ?? 'غير محدد';
              final timestamp =
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final providerId = data['providerId'] ?? 'غير محدد';

              return ListTile(
                leading: const Icon(Icons.monetization_on, color: Colors.green),
                title: Text('$service - ${commission.toStringAsFixed(0)} د.ع'),
                subtitle: Text('مقدم الخدمة: $providerId'),
                trailing: Text(
                  DateFormat('HH:mm\ndd/MM').format(timestamp),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
