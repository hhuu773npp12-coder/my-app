import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:badges/badges.dart' as badges;

import 'package:mesaybawi/features/profile/profile_screen.dart';
import 'package:mesaybawi/features/wallet/wallet_screen.dart';
import 'package:mesaybawi/features/notifications/notifications_screen.dart';
import 'package:mesaybawi/features/admin/enhanced_order_sharing.dart';
import 'package:mesaybawi/features/admin/craftsman_order_sharing.dart';

class AdminHomePage extends StatefulWidget {
  final String adminId;
  const AdminHomePage({super.key, required this.adminId});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  final List<String> _tabs = ["الطلبات", "إنشاء حملات", "ضبط الخطوط"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مسيباوي", textAlign: TextAlign.center),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.person, size: 28),
                  tooltip: "الملف الشخصي",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: widget.adminId),
                      ),
                    );
                  },
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.account_balance_wallet, size: 28),
                      tooltip: "المحفظة",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WalletPage(userId: widget.adminId),
                          ),
                        );
                      },
                    ),
                    const Text("0.00 د.ع")
                  ],
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("loginRequests")
                      .where("read", isEqualTo: false)
                      .where("adminId", isEqualTo: widget.adminId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int newCount =
                        snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return badges.Badge(
                      position: badges.BadgePosition.topEnd(top: -5, end: -5),
                      showBadge: newCount > 0,
                      badgeContent: Text(
                        newCount.toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.lock, size: 28),
                        tooltip: "كود تسجيل الدخول",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminCodesPage(adminId: widget.adminId),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, size: 28),
                  tooltip: "الإشعارات",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            NotificationsPage(userId: widget.adminId),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: _tabs
            .map(
              (title) => BottomNavigationBarItem(
                icon: _buildIconForTab(title),
                label: title,
              ),
            )
            .toList(),
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  Widget _buildIconForTab(String tab) {
    switch (tab) {
      case "الطلبات":
        return const Icon(Icons.list_alt);
      case "إنشاء حملات":
        return const Icon(Icons.campaign);
      case "ضبط الخطوط":
        return const Icon(Icons.directions_bus);
      default:
        return const Icon(Icons.circle);
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return OrdersTab(adminId: widget.adminId);
      case 1:
        return CampaignsTab(adminId: widget.adminId);
      case 2:
        return AdminLineControlTab(adminId: widget.adminId);
      default:
        return const Center(child: Text("غير متاح"));
    }
  }
}

/// ===== واجهة الأكواد للأدمن =====
class AdminCodesPage extends StatelessWidget {
  final String adminId;
  const AdminCodesPage({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("أكواد تسجيل الدخول")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("loginRequests")
            .where("adminId", isEqualTo: adminId)
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("لا توجد طلبات دخول حالياً"));
          }

          return ListView(
            children: docs.map((d) {
              var data = d.data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.lock),
                title: Text("📞 ${data['phone']}"),
                subtitle: Text("🔑 الكود: ${data['code']}"),
                trailing: Text(
                  data['timestamp'] != null
                      ? (data['timestamp'] as Timestamp).toDate().toString()
                      : "",
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// ===== واجهة الطلبات =====
class OrdersTab extends StatefulWidget {
  final String adminId;
  const OrdersTab({super.key, required this.adminId});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: "طلبات التسجيل"),
            Tab(text: "طلبات الخدمة"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildRegistrationRequests(),
              _buildServiceRequests(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("registrationRequests")
          .where("adminId", isEqualTo: widget.adminId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد طلبات تسجيل حالياً"));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text("📞 ${data['phone']}"),
                subtitle: Text("👤 ${data['name']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        await doc.reference.update({"status": "approved"});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await doc.reference.update({"status": "rejected"});
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildServiceRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("serviceRequests")
          .where("adminId", isEqualTo: widget.adminId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد طلبات خدمة حالياً"));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String serviceType = data['serviceType'] ?? data['service'] ?? '';
            IconData serviceIcon = _getServiceIcon(serviceType);
            Color serviceColor = _getServiceColor(serviceType);

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: serviceColor,
                  child: Icon(serviceIcon, color: Colors.white),
                ),
                title: Text("${_getServiceDisplayName(serviceType)}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("📞 ${data['phone'] ?? 'غير محدد'}"),
                    Text("👤 ${data['customerName'] ?? 'غير محدد'}"),
                    Text(
                        "📍 ${data['location'] ?? data['address'] ?? 'غير محدد'}"),
                    if (data['urgencyLevel'] != null)
                      Text("⚡ الأولوية: ${data['urgencyLevel']}"),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _shareServiceRequestEnhanced(data),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text("مشاركة"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: serviceColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    Text(
                      _getServiceCategory(serviceType),
                      style: TextStyle(
                        fontSize: 10,
                        color: serviceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// ===== مشاركة الطلب المحسنة =====
  Future<void> _shareServiceRequestEnhanced(
      Map<String, dynamic> serviceData) async {
    // تحديد نوع الخدمة لاختيار الواجهة المناسبة
    String serviceType =
        serviceData['serviceType'] ?? serviceData['service'] ?? '';

    // قائمة خدمات التوصيل
    List<String> deliveryServices = [
      'delivery',
      'taxi',
      'tuktuk',
      'kia',
      'restaurant'
    ];

    // قائمة خدمات الحرف
    List<String> craftServices = [
      'electrician',
      'plumber',
      'blacksmith',
      'cooling',
      'carpenter',
      'painter',
      'tiler',
      'mechanic'
    ];

    if (craftServices.contains(serviceType)) {
      // استخدام واجهة أصحاب الحرف
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CraftsmanOrderSharingScreen(
            jobData: serviceData,
            adminId: widget.adminId,
          ),
        ),
      );
    } else {
      // استخدام واجهة السائقين (التوصيل)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnhancedOrderSharingScreen(
            orderData: serviceData,
            adminId: widget.adminId,
          ),
        ),
      );
    }
  }

  /// ===== مشاركة الطلب مع السائقين (النظام القديم) =====
  Future<void> _shareServiceRequest(Map<String, dynamic> serviceData) async {
    int mealPrice = (serviceData['mealPrice'] ?? 0) as int;
    int deliveryFee = (serviceData['deliveryFee'] ?? 0) as int;
    int serviceFee = (serviceData['serviceFee'] ?? 1000) as int;

    int totalPrice = mealPrice + serviceFee + deliveryFee;

    // حساب عدد السواق
    int driversCount = (totalPrice ~/ 30000) + 1;

    int adjustedDeliveryFee = deliveryFee * driversCount;
    int driverShare = (adjustedDeliveryFee / driversCount).round();

    // جلب السائقين النشطين
    var usersSnap = await FirebaseFirestore.instance
        .collection("users")
        .where("type", isEqualTo: serviceData['userType'])
        .where("active", isEqualTo: true)
        .limit(driversCount)
        .get();

    if (!mounted) return; // ✅ منع استخدام context إذا الشاشة مغلقة

    List<Map<String, dynamic>> users =
        usersSnap.docs.map((d) => d.data()).toList();

    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لا يوجد سواق متاحين حالياً")),
      );
      return;
    }

    // إنشاء الطلب لكل سائق
    for (var u in users) {
      await FirebaseFirestore.instance.collection("assignedRequests").add({
        "serviceRequestId": serviceData['id'],
        "userId": u['id'],
        "userName": u['name'],
        "mealPrice": mealPrice + serviceFee,
        "deliveryFee": driverShare,
        "totalForDriver": mealPrice + serviceFee + driverShare,
        "status": "pending",
        "assignedAt": FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return; // ✅ تأكيد إضافي
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ تم توزيع الطلب على $driversCount سواق")),
    );
  }

  String _getServiceCategory(String serviceType) {
    List<String> craftServices = [
      'electrician',
      'plumber',
      'blacksmith',
      'cooling'
    ];
    List<String> deliveryServices = [
      'delivery',
      'taxi',
      'tuktuk',
      'restaurant'
    ];

    if (craftServices.contains(serviceType.toLowerCase())) {
      return 'حرفة';
    } else if (deliveryServices.contains(serviceType.toLowerCase())) {
      return 'نقل';
    } else {
      return 'خدمة';
    }
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'electrician':
        return Icons.electrical_services;
      case 'plumber':
        return Icons.plumbing;
      case 'blacksmith':
        return Icons.build;
      case 'cooling':
        return Icons.ac_unit;
      case 'delivery':
        return Icons.delivery_dining;
      case 'taxi':
        return Icons.local_taxi;
      case 'tuktuk':
        return Icons.motorcycle;
      case 'restaurant':
        return Icons.restaurant;
      default:
        return Icons.work;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'electrician':
        return Colors.amber;
      case 'plumber':
        return Colors.blue;
      case 'blacksmith':
        return Colors.grey;
      case 'cooling':
        return Colors.lightBlue;
      case 'delivery':
        return Colors.green;
      case 'taxi':
        return Colors.yellow;
      case 'tuktuk':
        return Colors.orange;
      case 'restaurant':
        return Colors.red;
      default:
        return Colors.purple;
    }
  }

  String _getServiceDisplayName(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'electrician':
        return 'كهربائي';
      case 'plumber':
        return 'سباك';
      case 'blacksmith':
        return 'حداد';
      case 'cooling':
        return 'تبريد وتكييف';
      case 'delivery':
        return 'توصيل';
      case 'taxi':
        return 'تاكسي';
      case 'tuktuk':
        return 'توك توك';
      case 'restaurant':
        return 'مطعم';
      default:
        return serviceType;
    }
  }
}

/// ===== واجهة الحملات =====
class CampaignsTab extends StatefulWidget {
  final String adminId;
  const CampaignsTab({super.key, required this.adminId});

  @override
  State<CampaignsTab> createState() => _CampaignsTabState();
}

class _CampaignsTabState extends State<CampaignsTab> {
  final _titleCtrl = TextEditingController();
  final _countCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  DateTime? _startDate;

  Future<void> _createCampaign() async {
    if (_titleCtrl.text.isEmpty ||
        _countCtrl.text.isEmpty ||
        _priceCtrl.text.isEmpty ||
        _startDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ يرجى إدخال جميع الحقول")),
      );
      return;
    }

    int count = int.parse(_countCtrl.text);
    double price = double.parse(_priceCtrl.text);
    double total = count * price;

    var docRef = await FirebaseFirestore.instance.collection("campaigns").add({
      "title": _titleCtrl.text,
      "count": count,
      "price": price,
      "total": total,
      "startDate": _startDate,
      "createdAt": DateTime.now(),
      "status": "pending",
      "adminId": widget.adminId,
    });

    await FirebaseFirestore.instance.collection("citizensCampaigns").add({
      "campaignId": docRef.id,
      "status": "pending",
      "participants": [],
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم إنشاء الحملة")),
    );

    _titleCtrl.clear();
    _countCtrl.clear();
    _priceCtrl.clear();
    setState(() => _startDate = null);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: "عنوان الحملة"),
          ),
          TextField(
            controller: _countCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "عدد المشاركين"),
          ),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "السعر لكل فرد"),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _startDate == null
                      ? "لم يتم اختيار الموعد"
                      : "موعد: ${_startDate.toString().substring(0, 16)}",
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _startDate = picked);
                  }
                },
                child: const Text("اختيار موعد"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _createCampaign,
            child: const Text("إنشاء الحملة"),
          ),
        ],
      ),
    );
  }
}

/// ===== واجهة خطوط النقل =====
class AdminLineControlTab extends StatelessWidget {
  final String adminId;
  const AdminLineControlTab({super.key, required this.adminId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("transportLines")
          .where("adminId", isEqualTo: adminId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد خطوط نقل مسجلة"));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            List<dynamic> students = data['students'] ?? [];

            List<List<dynamic>> groups = [];
            for (var i = 0; i < students.length; i += 14) {
              groups.add(
                students.sublist(
                  i,
                  (i + 14 > students.length) ? students.length : i + 14,
                ),
              );
            }

            return Card(
              margin: const EdgeInsets.all(8),
              child: ExpansionTile(
                leading: const Icon(Icons.directions_bus),
                title: Text("${data['school']} - ${data['location']}"),
                children: groups
                    .map(
                      (g) => ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: g
                            .map(
                              (s) => ListTile(
                                title: Text(s['name']),
                                subtitle: Text("رصيد: ${s['balance']} د.ع"),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// ===== وظائف مساعدة لتصنيف الخدمات =====
  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'electrician':
        return Icons.electrical_services;
      case 'plumber':
        return Icons.plumbing;
      case 'blacksmith':
        return Icons.build;
      case 'cooling':
        return Icons.ac_unit;
      case 'delivery':
        return Icons.delivery_dining;
      case 'taxi':
        return Icons.local_taxi;
      case 'tuktuk':
        return Icons.motorcycle;
      case 'restaurant':
        return Icons.restaurant;
      default:
        return Icons.miscellaneous_services;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'electrician':
        return Colors.amber;
      case 'plumber':
        return Colors.blue;
      case 'blacksmith':
        return Colors.grey;
      case 'cooling':
        return Colors.lightBlue;
      case 'delivery':
        return Colors.green;
      case 'taxi':
        return Colors.yellow.shade700;
      case 'tuktuk':
        return Colors.orange;
      case 'restaurant':
        return Colors.red;
      default:
        return Colors.purple;
    }
  }

  String _getServiceDisplayName(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'electrician':
        return 'كهربائي';
      case 'plumber':
        return 'سباك';
      case 'blacksmith':
        return 'حداد';
      case 'cooling':
        return 'تبريد وتكييف';
      case 'delivery':
        return 'توصيل';
      case 'taxi':
        return 'تاكسي';
      case 'tuktuk':
        return 'توك توك';
      case 'restaurant':
        return 'مطعم';
      default:
        return serviceType;
    }
  }
}
