// ignore: duplicate_ignore
// ignore: file_names
// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/fare_calculator.dart';
import '../services/restaurant_management_service.dart';
import 'features/citizen/order_tracking_screen.dart';

class FoodOrderScreen extends StatefulWidget {
  final String userId; // معرف اليوزر الموحد
  const FoodOrderScreen({super.key, required this.userId});

  @override
  State<FoodOrderScreen> createState() => _FoodOrderScreenState();
}

class _FoodOrderScreenState extends State<FoodOrderScreen> {
  List<Map<String, dynamic>> cart = [];
  int serviceFee = 1000;

  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  LatLng? userLocation;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ لم نتمكن من الحصول على موقعك")),
      );
    }
  }

  void addToCart(Map<String, dynamic> item, LatLng restaurantLocation) {
    if (userLocation == null) return;

    int distanceMeters = Geolocator.distanceBetween(
      userLocation!.latitude,
      userLocation!.longitude,
      restaurantLocation.latitude,
      restaurantLocation.longitude,
    ).toInt();

    int deliveryPrice = FareCalculator.taxi(distanceMeters);

    setState(() {
      cart.add({
        'name': item['name'],
        'price': item['price'],
        'restaurant': item['restaurant'],
        'deliveryPrice': deliveryPrice,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تمت إضافة ${item['name']} للسلة")),
    );
  }

  /// 🔹 مجموع أسعار الوجبات فقط
  int getMealsPrice() {
    return cart.fold<int>(
        0, (total, item) => total + (item['price'] ?? 0) as int);
  }

  /// 🔹 حساب عدد السواق المطلوب
  int getDriversCount() {
    int mealsPrice = getMealsPrice();
    if (mealsPrice > 40000) {
      return (mealsPrice / 40000).ceil();
    }
    return 1; // 👈 عالأقل سائق واحد
  }

  /// 🔹 حساب أجرة التوصيل مع القاعدة الجديدة
  int getDeliveryFee() {
    int baseDelivery = cart.fold<int>(
        0, (total, item) => total + (item['deliveryPrice'] ?? 0) as int);
    return baseDelivery * getDriversCount();
  }

  /// 🔹 السعر النهائي
  int getTotalPrice() {
    return getMealsPrice() + getDeliveryFee() + serviceFee;
  }

  void placeOrder() async {
    if (nameController.text.isEmpty ||
        phoneController.text.isEmpty ||
        userLocation == null ||
        cart.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("يرجى إدخال جميع البيانات وإضافة عناصر للسلة")));
      return;
    }

    // تأكيد قبل الإرسال
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("تأكيد الطلب"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("هل تريد إرسال الطلب بمبلغ ${getTotalPrice()} د.ع؟"),
            const SizedBox(height: 8),
            const Text(
              "ملاحظة: سيتم إرسال الطلب للمطعم أولاً للموافقة، ثم للدراجات للتوصيل.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("إلغاء")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("تأكيد")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // تجميع الطلبات حسب المطعم
      Map<String, List<Map<String, dynamic>>> ordersByRestaurant = {};

      for (var item in cart) {
        String restaurantName = item['restaurant'] ?? 'unknown';
        if (!ordersByRestaurant.containsKey(restaurantName)) {
          ordersByRestaurant[restaurantName] = [];
        }
        ordersByRestaurant[restaurantName]!.add(item);
      }

      // إرسال طلب منفصل لكل مطعم
      for (var entry in ordersByRestaurant.entries) {
        String restaurantName = entry.key;
        List<Map<String, dynamic>> restaurantItems = entry.value;

        int restaurantTotal = restaurantItems.fold<int>(
            // ignore: avoid_types_as_parameter_names
            0,
            (sum, item) => sum + (item['price'] as int));

        // البحث عن معرف المطعم
        QuerySnapshot restaurantQuery = await FirebaseFirestore.instance
            .collection('restaurants')
            .where('name', isEqualTo: restaurantName)
            .limit(1)
            .get();

        String restaurantId = restaurantQuery.docs.isNotEmpty
            ? restaurantQuery.docs.first.id
            : 'unknown_restaurant';

        // إرسال الطلب للمطعم باستخدام الخدمة الجديدة
        await RestaurantManagementService.sendFoodOrderToRestaurant(
          restaurantId: restaurantId,
          customerId: widget.userId,
          customerName: nameController.text,
          customerPhone: phoneController.text,
          items: restaurantItems,
          customerLocation: {
            'lat': userLocation!.latitude,
            'lng': userLocation!.longitude,
          },
          totalAmount: restaurantTotal + serviceFee,
        );
      }

      if (!mounted) return;
      setState(() {
        cart.clear();
        nameController.clear();
        phoneController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ تم إرسال طلبك للمطاعم. ستصلك إشعارات عند الموافقة."),
          backgroundColor: Colors.green,
        ),
      );

      // عرض شاشة تتبع الطلب
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(userId: widget.userId),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("طلب الطعام"),
        actions: [
          Stack(
            children: [
              IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    if (!mounted) return;
                    showModalBottomSheet(
                        context: context,
                        builder: (_) => CartSheet(
                              cart: cart,
                              mealsPrice: getMealsPrice(),
                              deliveryFee: getDeliveryFee(),
                              driversCount: getDriversCount(),
                              totalPrice: getTotalPrice(),
                              removeItem: (index) {
                                if (!mounted) return;
                                setState(() {
                                  cart.removeAt(index);
                                });
                              },
                              placeOrder: placeOrder,
                            ));
                  }),
              if (cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Text('${cart.length}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final restaurants = snapshot.data!.docs;
          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (_, index) {
              final restaurant =
                  restaurants[index].data() as Map<String, dynamic>;
              final offers = restaurant['offers'] as List<dynamic>? ?? [];
              final restaurantLat =
                  (restaurant['location']?['lat'] ?? 0.0) as double;
              final restaurantLng =
                  (restaurant['location']?['lng'] ?? 0.0) as double;
              final restaurantLocation = LatLng(restaurantLat, restaurantLng);

              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(restaurant['name'] ?? 'مطعم'),
                  children: offers.map((offer) {
                    return ListTile(
                      title: Text(offer['name']),
                      subtitle: Text('${offer['price']} د.ع'),
                      trailing: ElevatedButton(
                        onPressed: () => addToCart({
                          'name': offer['name'],
                          'price': offer['price'],
                          'restaurant': restaurant['name']
                        }, restaurantLocation),
                        child: const Text("أضف للسلة"),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CartSheet extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final int mealsPrice;
  final int deliveryFee;
  final int driversCount;
  final int totalPrice;
  final Function(int) removeItem;
  final VoidCallback placeOrder;

  const CartSheet({
    super.key,
    required this.cart,
    required this.mealsPrice,
    required this.deliveryFee,
    required this.driversCount,
    required this.totalPrice,
    required this.removeItem,
    required this.placeOrder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("السلة",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cart.length,
              itemBuilder: (_, index) {
                final item = cart[index];
                return ListTile(
                  title: Text(item['name']),
                  subtitle: Text(
                      'السعر: ${item['price']} د.ع + توصيل: ${item['deliveryPrice']} د.ع'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      removeItem(index);
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text("مجموع سعر الوجبات: $mealsPrice د.ع"),
                Text("عدد السواق المطلوب: $driversCount"),
                Text("إجمالي التوصيل (مع القاعدة): $deliveryFee د.ع"),
                Text("السعر النهائي (شامل الخدمة): $totalPrice د.ع"),
                ElevatedButton(
                    onPressed: placeOrder, child: const Text("إرسال الطلب")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
