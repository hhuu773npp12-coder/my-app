import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/quantity_selector.dart';

class SolarOffersScreen extends StatefulWidget {
  final String userId;
  const SolarOffersScreen({super.key, required this.userId});

  @override
  State<SolarOffersScreen> createState() => _SolarOffersScreenState();
}

class _SolarOffersScreenState extends State<SolarOffersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> cart = [];
  Map<String, int> itemQuantities = {};

  void _updateCartItem(String itemKey, Map<String, dynamic> item, int quantity) {
    setState(() {
      // إزالة المنتج من السلة إذا كان موجوداً
      cart.removeWhere((cartItem) => 
          cartItem['offerId'] == item['offerId']);
      
      // إضافة المنتج بالكمية الجديدة إذا كانت أكبر من صفر
      if (quantity > 0) {
        cart.add({
          'offerId': item['offerId'],
          'title': item['title'],
          'details': item['details'],
          'basePrice': item['basePrice'],
          'quantity': quantity,
          'totalPrice': item['totalPrice'],
          'ownerId': item['ownerId'],
        });
      }
      
      // تحديث كمية المنتج في الخريطة
      itemQuantities[itemKey] = quantity;
    });
  }

  Future<void> _placeOrder() async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة! يرجى إضافة منتجات أولاً')),
      );
      return;
    }

    // حساب المجموع الإجمالي
    double totalAmount = cart.fold(0, (sum, item) => sum + (item['totalPrice'] ?? 0));

    // تأكيد الطلب
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تأكيد طلب أنظمة الطاقة الشمسية"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("هل تريد إرسال الطلب بمبلغ ${totalAmount.toStringAsFixed(0)} د.ع؟"),
            const SizedBox(height: 8),
            const Text(
              "ملاحظة: سيتم إرسال الطلب للمالك للموافقة والتنسيق للتركيب.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // إرسال الطلب لقاعدة البيانات
      await _firestore.collection('solar_orders').add({
        'userId': widget.userId,
        'items': cart,
        'totalAmount': totalAmount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'orderDate': DateTime.now().toIso8601String(),
      });

      // مسح السلة
      setState(() {
        cart.clear();
        itemQuantities.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ تم إرسال طلبك بنجاح! سيتم التواصل معك قريباً."),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ حدث خطأ في إرسال الطلب: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "سلة أنظمة الطاقة الشمسية",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: cart.isEmpty
                  ? const Center(
                      child: Text(
                        "السلة فارغة",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: cart.length,
                      itemBuilder: (_, index) {
                        final item = cart[index];
                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            title: Text(item['title'] ?? 'نظام طاقة شمسية'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('الكمية: ${item['quantity']}'),
                                Text('السعر الإجمالي: ${(item['totalPrice'] ?? 0).toStringAsFixed(0)} د.ع'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  cart.removeAt(index);
                                });
                                Navigator.pop(context);
                                _showCart(); // إعادة فتح السلة
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (cart.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "المجموع الإجمالي: ${cart.fold(0.0, (sum, item) => sum + (item['totalPrice'] ?? 0)).toStringAsFixed(0)} د.ع",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _placeOrder();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text("إرسال الطلب"),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("عروض أنظمة الطاقة الشمسية"),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _showCart,
              ),
              if (cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Text(
                      '${cart.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('solar_offers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('خطأ في تحميل العروض: ${snapshot.error}'),
            );
          }

          final offers = snapshot.data?.docs ?? [];

          if (offers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.solar_power, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد عروض متاحة حالياً',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index].data() as Map<String, dynamic>;
              final offerId = offers[index].id;
              final title = offer['title'] ?? 'نظام طاقة شمسية';
              final details = offer['details'] ?? 'لا توجد تفاصيل';
              final basePrice = (offer['price'] ?? 0).toDouble();
              
              String itemKey = 'solar_$offerId';
              
              // الخدمات الإضافية لأنظمة الطاقة الشمسية
              List<ServiceFee> additionalServices = [
                const ServiceFee(
                  name: 'رسوم التركيب',
                  amount: 5000,
                  isPercentage: false,
                ),
                const ServiceFee(
                  name: 'ضمان الصيانة',
                  amount: 3,
                  isPercentage: true,
                ),
                const ServiceFee(
                  name: 'رسوم التوصيل',
                  amount: 2000,
                  isPercentage: false,
                ),
              ];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // معلومات العرض
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            details,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.solar_power,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'طاقة شمسية',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // محدد الكمية
                    QuantitySelector(
                      itemName: title,
                      basePrice: basePrice,
                      additionalServices: additionalServices,
                      onQuantityChanged: (quantity, totalPrice) {
                        _updateCartItem(
                          itemKey,
                          {
                            'offerId': offerId,
                            'title': title,
                            'details': details,
                            'basePrice': basePrice,
                            'totalPrice': totalPrice,
                            'ownerId': offer['ownerId'],
                          },
                          quantity,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
