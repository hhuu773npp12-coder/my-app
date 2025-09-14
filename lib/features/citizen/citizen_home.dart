// citizen_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../widgets/ui.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';

// استدعاء واجهات الأيقونات والخدمات
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';
import '../notifications/notifications_screen.dart';

// صفحات الطلبات لكل خدمة
import 'requests/request_taxi.dart';
import 'requests/request_blacksmith.dart';
import 'requests/request_electrician.dart';
import 'requests/request_kiahaml.dart';
import 'requests/request_plumber.dart';
import 'requests/request_student_transport.dart';
import 'requests/request_technician.dart';
import 'requests/request_tuktuk.dart';
import 'requests/ziyarah_campaigns.dart';
import 'requests/request_stoota.dart';
import '../../FoodOrderScreen.dart';
import 'dart:async';

class CitizenHomeScreen extends StatefulWidget {
  final String userId; // معرف اليوزر الموحد
  const CitizenHomeScreen({super.key, required this.userId});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  int balance = 0;
  late StreamSubscription<DocumentSnapshot> _balanceSub;
  List<DocumentSnapshot> offers = [];

  @override
  void initState() {
    super.initState();
    _listenBalance();
    _loadOffers();
  }

  @override
  void dispose() {
    _balanceSub.cancel();
    super.dispose();
  }

  void _listenBalance() {
    _balanceSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          balance = snapshot.data()?['balance'] ?? 0;
        });
      }
    });
  }

  Future<void> _loadOffers() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('offers')
        .orderBy('createdAt', descending: true)
        .get();
    if (!mounted) return;
    setState(() {
      offers = snapshot.docs;
    });
  }

  // دالة لإظهار أيقونة مناسبة حسب نوع العرض
  Widget _getOfferIcon(String title) {
    IconData icon;
    Color color;

    if (title.contains('طاقة') || title.contains('شمسي')) {
      icon = Icons.wb_sunny;
      color = Colors.orange;
    } else if (title.contains('حملة') || title.contains('زيارة')) {
      icon = Icons.tour;
      color = Colors.green;
    } else if (title.contains('تدريب') || title.contains('كورس')) {
      icon = Icons.school;
      color = Colors.blue;
    } else {
      icon = Icons.local_offer;
      color = Colors.purple;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.3),
          ],
        ),
      ),
      child: Icon(
        icon,
        size: 60,
        color: color,
      ),
    );
  }

  void _showEnhancedOfferDialog(DocumentSnapshot offer) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    LatLng? selectedLocation;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.green.shade400],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    offer['title'].toString().contains('طاقة')
                        ? Icons.wb_sunny
                        : Icons.tour,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "التسجيل في: ${offer['title']}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            titlePadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),

                    // حقل الاسم
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "الاسم الكامل *",
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // حقل رقم الهاتف
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "رقم الهاتف *",
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // حقل العنوان
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: "العنوان التفصيلي *",
                        prefixIcon: const Icon(Icons.home),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // زر تحديد الموقع
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          selectedLocation == null
                              ? Icons.location_on
                              : Icons.my_location, // ✅ بديل check_location
                        ),
                        label: Text(selectedLocation == null
                            ? "تحديد موقعك الحالي *"
                            : "✅ تم تحديد الموقع"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedLocation == null
                              ? Colors.blue
                              : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            // استخدام خدمة الموقع المحسنة
                            LatLng location = await LocationService.instance
                                .getCurrentLatLng();
                            if (!mounted) return;
                            setState(() {
                              selectedLocation = location;
                            });
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("خطأ في تحديد الموقع: $e")),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // حقل الملاحظات
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "ملاحظات إضافية (اختياري)",
                        prefixIcon: const Icon(Icons.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),

                    if (offer['price'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.monetization_on,
                                color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              "السعر: ${offer['price']} د.ع",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (nameController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty ||
                            addressController.text.trim().isEmpty ||
                            selectedLocation == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "⚠️ يرجى ملء جميع الحقول المطلوبة وتحديد الموقع"),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        setState(() => isSubmitting = true);

                        try {
                          await FirebaseFirestore.instance
                              .collection('admin_orders')
                              .add({
                            'userId': widget.userId,
                            'offerId': offer.id,
                            'offerTitle': offer['title'],
                            'name': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'address': addressController.text.trim(),
                            'notes': notesController.text.trim(),
                            'location': {
                              'lat': selectedLocation!.latitude,
                              'lng': selectedLocation!.longitude,
                            },
                            'price': offer['price'],
                            'status': 'pending',
                            'type': 'offer_registration',
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          // إنشاء إشعار للإدارة
                          await FirebaseFirestore.instance
                              .collection('admin_notifications')
                              .add({
                            'title': 'تسجيل جديد في العرض',
                            'body':
                                'تم تسجيل ${nameController.text.trim()} في ${offer['title']}',
                            'type': 'offer_registration',
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          if (!mounted) return;
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "✅ تم إرسال طلب التسجيل بنجاح!\nسيتم الاتصال بك قريباً"),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("❌ حدث خطأ: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => isSubmitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text("تسجيل",
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("المسيباوي"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // شريط الأيقونات العلوي (ملف شخصي، محفظة، إشعارات)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTopIcon(context, "المحفظة", Icons.account_balance_wallet,
                    () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => WalletPage(userId: widget.userId)));
                }),
                _buildTopIcon(context, "ملفي", Icons.account_circle, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfilePage(userId: widget.userId)));
                }),
                _buildTopIcon(context, "الإشعارات", Icons.notifications, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              NotificationsPage(userId: widget.userId)));
                }),
              ],
            ),
          ),

          const Divider(thickness: 1),

          // عرض العروض والحملات بشكل كروت محسنة
          Container(
            height: 200,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: offers.isEmpty
                ? const Center(
                    child: Text(
                      "لا توجد عروض أو حملات حالياً",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: offers.length,
                    itemBuilder: (context, index) {
                      var offer = offers[index];
                      return GestureDetector(
                        onTap: () => _showEnhancedOfferDialog(offer),
                        child: Container(
                          width: 180,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.shade50,
                                    Colors.green.shade50,
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // صورة العرض أو أيقونة
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(15),
                                          topRight: Radius.circular(15),
                                        ),
                                        color: Colors.white,
                                      ),
                                      child: offer['imageUrl'] != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(15),
                                                topRight: Radius.circular(15),
                                              ),
                                              child: Image.network(
                                                offer['imageUrl'],
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return _getOfferIcon(
                                                      offer['title'] ?? '');
                                                },
                                              ),
                                            )
                                          : _getOfferIcon(offer['title'] ?? ''),
                                    ),
                                  ),
                                  // معلومات العرض
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            offer['title'] ?? "",
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (offer['price'] != null)
                                            Text(
                                              "${offer['price']} د.ع",
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              "اضغط للتسجيل",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(thickness: 1),

          // شبكة أيقونات طلب الخدمات
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildServiceIcon(
                    context,
                    " طلب تكسي ",
                    Icons.local_taxi,
                    () => _navigateTo(
                        context, RequestTaxi(userId: widget.userId))),
                _buildServiceIcon(
                    context,
                    " طلب سباك",
                    Icons.plumbing,
                    () => _navigateTo(
                        context, RequestPlumber(userId: widget.userId))),
                _buildServiceIcon(
                    context,
                    " طلب كهربائي",
                    Icons.electrical_services,
                    () => _navigateTo(
                        context, RequestElectrician(userId: widget.userId))),
                _buildServiceIcon(
                    context,
                    " طلب تكتك",
                    Icons.electric_rickshaw,
                    () => _navigateTo(
                        context, RequestTuktuk(userId: widget.userId))),
                _buildServiceIcon(
                    context,
                    " طلب ستوتا",
                    Icons.school,
                    () => _navigateTo(
                        context, RequestStoota(userId: widget.userId))),
                _buildServiceIcon(
                    context,
                    "طلب كيا حمل",
                    Icons.local_shipping,
                    () => _navigateTo(
                        context, RequestKiahaml(userId: widget.userId))),
                _buildServiceIcon(
                    context,
                    "حملات زيارة المراقد المقدسة ",
                    Icons.campaign,
                    () => _navigateTo(
                        context,
                        CampaignBookingScreen(
                            userId: widget.userId,
                            campaignId: "campaignId",
                            title: "title",
                            price: 0000))),
                _buildServiceIcon(
                    context,
                    "طلب طعام",
                    Icons.fastfood,
                    () => _navigateTo(
                        context, FoodOrderScreen(userId: widget.userId))),
                _buildServiceIcon(
                    context,
                    " طلب فني تبريد",
                    Icons.engineering,
                    () => _navigateTo(
                        context, RequestTechnician(userId: widget.userId))),
                _buildServiceIcon(
                    context,
                    "التسجيل في خط ",
                    Icons.school_outlined,
                    () => _navigateTo(context,
                        RequestStudentTransportScreen(userId: widget.userId))),
                _buildServiceIcon(
                    context,
                    " طلب حداد",
                    Icons.handyman,
                    () => _navigateTo(
                        context, RequestBlacksmith(userId: widget.userId))),
              ],
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
          CircleAvatar(
            radius: 28,
            backgroundColor:
                Colors.blueAccent.withValues(alpha: 0.1), // ✅ بديل withOpacity
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

  Widget _buildServiceIcon(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor:
                Colors.green.withValues(alpha: 0.2), // ✅ بديل withOpacity
            child: Icon(icon, size: 32, color: Colors.green[700]),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
