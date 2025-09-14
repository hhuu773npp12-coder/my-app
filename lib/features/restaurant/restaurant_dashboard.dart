import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/restaurant_management_service.dart';

void main() {
  runApp(const RestaurantOwnerApp());
}

class RestaurantOwnerApp extends StatelessWidget {
  final String? restaurantId;

  const RestaurantOwnerApp({super.key, this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مسيباوي',
      theme: ThemeData(primarySwatch: Colors.green, fontFamily: 'Arial'),
      home: const RestaurantOwnerDashboard(),
    );
  }
}

class RestaurantOwnerDashboard extends StatefulWidget {
  final String? restaurantId;
  const RestaurantOwnerDashboard({super.key, this.restaurantId});

  @override
  // ignore: library_private_types_in_public_api
  _RestaurantOwnerDashboardState createState() =>
      _RestaurantOwnerDashboardState();
}

class _RestaurantOwnerDashboardState extends State<RestaurantOwnerDashboard> {
  int _selectedIndex = 0;
  bool isRestaurantOpen = true;
  String restaurantId = 'default_restaurant'; // يجب تمرير المعرف الفعلي

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    restaurantId = widget.restaurantId ?? 'default_restaurant';
    _pages = [
      OrdersPage(restaurantId: restaurantId),
      const AddOfferPage(),
      RestaurantStatusPage(restaurantId: restaurantId),
    ];
    _loadRestaurantStatus();
  }

  Future<void> _loadRestaurantStatus() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();
      if (doc.exists) {
        setState(() {
          isRestaurantOpen =
              (doc.data() as Map<String, dynamic>)['isOpen'] ?? true;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _toggleRestaurantStatus() async {
    try {
      await RestaurantManagementService.updateRestaurantStatus(
          restaurantId, !isRestaurantOpen);
      setState(() {
        isRestaurantOpen = !isRestaurantOpen;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isRestaurantOpen ? 'تم فتح المطعم' : 'تم إغلاق المطعم'),
            backgroundColor: isRestaurantOpen ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث حالة المطعم: $e')),
        );
      }
    }
  }

  void _onIconTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مسيباوي - لوحة المطعم"),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            child: ElevatedButton.icon(
              onPressed: _toggleRestaurantStatus,
              icon: Icon(
                isRestaurantOpen
                    ? Icons.store
                    : Icons.store_mall_directory_outlined,
                color: Colors.white,
              ),
              label: Text(
                isRestaurantOpen ? 'مفتوح' : 'مغلق',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRestaurantOpen ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onIconTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: "الطلبات"),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_box), label: "إضافة عروض"),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics), label: "الإحصائيات"),
        ],
      ),
    );
  }
}

/// --- صفحة الطلبات المحسنة ---
class OrdersPage extends StatelessWidget {
  final String restaurantId;
  const OrdersPage({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          RestaurantManagementService.getRestaurantPendingOrders(restaurantId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("لا توجد طلبات معلقة", style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final orderId = doc.id;
            final items = data['items'] as List<dynamic>? ?? [];
            final totalAmount = data['totalAmount'] ?? 0;
            final customerName = data['customerName'] ?? 'غير محدد';
            final customerPhone = data['customerPhone'] ?? 'غير محدد';

            return Card(
              margin: const EdgeInsets.all(8),
              elevation: 4,
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text('${index + 1}'),
                ),
                title: Text('طلب من $customerName'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📞 $customerPhone'),
                    Text('💰 المبلغ: $totalAmount د.ع',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('🕒 ${_formatTimestamp(data['createdAt'])}'),
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
                              child: Text(
                                  '• ${item['name']} - ${item['price']} د.ع'),
                            )),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _approveOrder(context, orderId),
                                icon: const Icon(Icons.check),
                                label: const Text('موافق'),
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
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير محدد';
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _approveOrder(BuildContext context, String orderId) async {
    // إظهار حوار لتحديد وقت التحضير
    int? preparationTime = await showDialog<int>(
      context: context,
      builder: (context) => _PreparationTimeDialog(),
    );

    if (preparationTime != null) {
      try {
        await RestaurantManagementService.approveRestaurantOrder(
          orderId,
          'restaurant_id', // يجب تمرير المعرف الفعلي
          preparationTimeMinutes: preparationTime,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم قبول الطلب وإرساله للدراجات'),
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
  }

  Future<void> _rejectOrder(BuildContext context, String orderId) async {
    String? reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectionReasonDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        await RestaurantManagementService.rejectRestaurantOrder(
            orderId, reason);
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
  }
}

/// --- متابعة الطلب ---
class OrderTrackingPage extends StatefulWidget {
  final String orderId;
  const OrderTrackingPage({required this.orderId, super.key});

  @override
  // ignore: library_private_types_in_public_api
  _OrderTrackingPageState createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  int _status = 0;
  final steps = [
    "قيد التجهيز",
    "تم التجهيز",
    "تم تسليم الطلب للسائق",
    "تم الطلب"
  ];

  @override
  Widget build(BuildContext context) {
    final orderRef =
        FirebaseFirestore.instance.collection("orders").doc(widget.orderId);

    return Scaffold(
      appBar: AppBar(title: Text("متابعة الطلب ${widget.orderId}")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: steps.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(
                    index <= _status
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: index <= _status ? Colors.green : Colors.grey,
                  ),
                  title: Text(steps[index]),
                  onTap: () async {
                    setState(() => _status = index);
                    await orderRef.update({"statusIndex": _status});
                    if (_status == steps.length - 1) {
                      await orderRef.update({"status": "completed"});
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// --- حوار وقت التحضير ---
class _PreparationTimeDialog extends StatefulWidget {
  @override
  _PreparationTimeDialogState createState() => _PreparationTimeDialogState();
}

class _PreparationTimeDialogState extends State<_PreparationTimeDialog> {
  int selectedTime = 15;
  final List<int> timeOptions = [10, 15, 20, 25, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('وقت تحضير الطلب'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('كم دقيقة تحتاج لتحضير هذا الطلب؟'),
          const SizedBox(height: 16),
          DropdownButton<int>(
            value: selectedTime,
            items: timeOptions
                .map((time) => DropdownMenuItem(
                      value: time,
                      child: Text('$time دقيقة'),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedTime = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, selectedTime),
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}

/// --- حوار سبب الرفض ---
class _RejectionReasonDialog extends StatefulWidget {
  @override
  _RejectionReasonDialogState createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final TextEditingController reasonController = TextEditingController();
  String? selectedReason;

  final List<String> commonReasons = [
    'نفدت المكونات',
    'المطعم مشغول جداً',
    'مشكلة تقنية',
    'خارج منطقة التوصيل',
    'سبب آخر',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('سبب رفض الطلب'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...commonReasons.map((reason) => RadioListTile<String>(
                title: Text(reason),
                value: reason,
                // ignore: deprecated_member_use
                groupValue: selectedReason,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  setState(() {
                    selectedReason = value;
                    if (value != 'سبب آخر') {
                      reasonController.text = value!;
                    } else {
                      reasonController.clear();
                    }
                  });
                },
              )),
          if (selectedReason == 'سبب آخر')
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'اكتب السبب',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            String reason = selectedReason == 'سبب آخر'
                ? reasonController.text
                : selectedReason ?? '';
            Navigator.pop(context, reason);
          },
          child: const Text('تأكيد الرفض'),
        ),
      ],
    );
  }
}

/// --- صفحة إحصائيات المطعم ---
class RestaurantStatusPage extends StatelessWidget {
  final String restaurantId;
  const RestaurantStatusPage({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: RestaurantManagementService.getRestaurantStats(restaurantId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard(
                  'طلبات اليوم', '${stats['todayOrders']}', Icons.today),
              _buildStatCard('طلبات الشهر', '${stats['monthlyOrders']}',
                  Icons.calendar_month),
              _buildStatCard(
                  'إيرادات الشهر',
                  '${stats['monthlyRevenue'].toInt()} د.ع',
                  Icons.monetization_on),
              _buildStatCard('متوسط قيمة الطلب',
                  '${stats['averageOrderValue'].toInt()} د.ع', Icons.analytics),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 40, color: Colors.green),
        title: Text(title),
        subtitle: Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// --- إضافة عرض ---
class AddOfferPage extends StatefulWidget {
  const AddOfferPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AddOfferPageState createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text("إضافة عرض جديد",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "اسم العرض")),
          const SizedBox(height: 10),
          TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: "السعر"),
              keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          TextField(
              controller: detailsController,
              decoration: const InputDecoration(labelText: "التفاصيل"),
              maxLines: 3),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text;
              final price = int.tryParse(priceController.text) ?? 0;
              final details = detailsController.text;
              if (name.isNotEmpty && details.isNotEmpty) {
                await FirebaseFirestore.instance.collection("offers").add({
                  "name": name,
                  "price": price,
                  "details": details,
                  "createdAt": FieldValue.serverTimestamp(),
                });
                if (!mounted) return;
                nameController.clear();
                priceController.clear();
                detailsController.clear();
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم إنشاء العرض")));
              }
            },
            child: const Text("إضافة العرض"),
          ),
        ],
      ),
    );
  }
}
