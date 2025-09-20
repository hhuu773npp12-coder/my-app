import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'features/profile/profile_screen.dart';
import 'features/wallet/wallet_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'owner_statistics_page.dart';

/// ------------------------- الواجهة الرئيسية للمالك -------------------------
class OwnerHomePage extends StatefulWidget {
  final String ownerId; // ✅ ربط الصفحة باليوزر
  const OwnerHomePage({super.key, required this.ownerId});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initOwnerBalance();
  }

  /// إنشاء رصيد المالك أول مرة (100 مليون)
  Future<void> _initOwnerBalance() async {
    final ownerRef = firestore.collection("users").doc(widget.ownerId);
    final snap = await ownerRef.get();
    if (snap.exists) {
      if (!(snap.data() as Map<String, dynamic>).containsKey("balance")) {
        await ownerRef.update({"balance": 100000000});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مسيباوي"),
        centerTitle: true,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream:
                firestore.collection("users").doc(widget.ownerId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              int balance = snapshot.data?['balance'] ?? 0;
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    "رصيد المالك: $balance د.ع",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // أيقونات تحت العنوان
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // أيقونة الملف الشخصي
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person, size: 30, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(userId: widget.ownerId),
                          ),
                        );
                      },
                    ),
                    const Text("الملف الشخصي", style: TextStyle(fontSize: 12)),
                  ],
                ),
                
                // أيقونة المحفظة مع الرصيد
                Column(
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: firestore.collection("users").doc(widget.ownerId).snapshots(),
                      builder: (context, snapshot) {
                        int balance = 0;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          balance = snapshot.data!['balance'] ?? 0;
                        }
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.account_balance_wallet, size: 30, color: Colors.green),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WalletPage(userId: widget.ownerId),
                                  ),
                                );
                              },
                            ),
                            if (balance > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "${(balance / 1000).toInt()}K",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const Text("المحفظة", style: TextStyle(fontSize: 12)),
                  ],
                ),
                
                // أيقونة الإشعارات
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications, size: 30, color: Colors.orange),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotificationsPage(userId: widget.ownerId),
                          ),
                        );
                      },
                    ),
                    const Text("الإشعارات", style: TextStyle(fontSize: 12)),
                  ],
                ),
                
                // أيقونة الإحصائيات
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.analytics, size: 30, color: Colors.purple),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OwnerStatisticsPage(ownerId: widget.ownerId),
                          ),
                        );
                      },
                    ),
                    const Text("الإحصائيات", style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          
          // قائمة الخيارات
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text("إدارة كارتات التعبئة"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CreateCardsPage(ownerId: widget.ownerId)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restaurant),
                  title: const Text("طلبات أصحاب المطاعم"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => RestaurantsPage(ownerId: widget.ownerId)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CreateSolarOfferPage(ownerId: widget.ownerId)),
          );
        },
      ),
    );
  }
}

/// ------------------------- إدارة الكارتات -------------------------
class CreateCardsPage extends StatefulWidget {
  final String ownerId;
  const CreateCardsPage({super.key, required this.ownerId});

  @override
  State<CreateCardsPage> createState() => _CreateCardsPageState();
}

class _CreateCardsPageState extends State<CreateCardsPage> {
  final TextEditingController countController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String _generateCardNumber() {
    Random random = Random();
    String number = "";
    for (int i = 0; i < 10; i++) {
      number += random.nextInt(10).toString();
    }
    return number;
  }

  Future<void> _createCards() async {
    int count = int.tryParse(countController.text) ?? 0;
    if (count > 0) {
      for (int i = 0; i < count; i++) {
        String card = _generateCardNumber();

        // خصم من رصيد المالك (كل كارت يساوي 10,000 دينار)
        await firestore.collection("users").doc(widget.ownerId).update({
          "balance": FieldValue.increment(-10000),
        });

        await firestore.collection("cards").add({
          "cardNumber": card,
          "isUsed": false,
          "ownerId": widget.ownerId, // ✅ ربط الكارت بالمالك
          "createdAt": FieldValue.serverTimestamp(),
        });
      }
      countController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إنشاء الكروت بنجاح ✅")),
      );
    }
  }

  Future<void> _useCard(String docId, String cardNumber) async {
    await firestore.collection("cards").doc(docId).update({"isUsed": true});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم استخدام الكارت: $cardNumber ✅")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة كارتات التعبئة")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "عدد الكارتات",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _createCards,
              child: const Text("إنشاء"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: firestore
                    .collection("cards")
                    .where("ownerId",
                        isEqualTo: widget.ownerId) // ✅ فقط كروت هذا المالك
                    .orderBy("createdAt", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const Text("لا توجد كارتات متاحة حالياً");
                  }

                  final cards = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      var doc = cards[index];
                      var cardNumber = doc["cardNumber"];
                      bool isUsed = doc["isUsed"];

                      return ListTile(
                        leading: Text("${index + 1}"),
                        title: Text(cardNumber),
                        subtitle: Text(isUsed ? "مستخدم" : "متاح"),
                        trailing: !isUsed
                            ? ElevatedButton(
                                onPressed: () => _useCard(doc.id, cardNumber),
                                child: const Text("استخدم"),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------- أصحاب المطاعم -------------------------
class RestaurantsPage extends StatelessWidget {
  final String ownerId;
  const RestaurantsPage({super.key, required this.ownerId});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    Future<void> transferToRestaurant(
        String restaurantId, int totalPrice, double commissionRate) async {
      final ownerRef = firestore.collection("users").doc(ownerId);

      int commission = (totalPrice * commissionRate).toInt();
      int priceToPay = totalPrice - commission;

      // العمولة تضاف لرصيد المالك
      await ownerRef.update({"balance": FieldValue.increment(commission)});

      // حذف جميع الطلبات بعد الدفع
      final orders = await firestore
          .collection('restaurants')
          .doc(restaurantId)
          .collection("orders")
          .get();

      for (var doc in orders.docs) {
        await doc.reference.delete();
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم تحويل $priceToPay د.ع لصاحب المطعم ✅")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("طلبات أصحاب المطاعم")),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection("restaurants").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("لا توجد مطاعم مسجلة حالياً"));
          }

          final restaurants = snapshot.data!.docs;

          return ListView.builder(
            itemCount: restaurants.length,
            itemBuilder: (context, index) {
              var doc = restaurants[index];
              String restaurantId = doc.id;
              String name = doc["name"];
              String phone = doc["phone"];

              return Card(
                child: ExpansionTile(
                  title: Text(name),
                  subtitle: Text("📞 $phone"),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: firestore
                          .collection("restaurants")
                          .doc(restaurantId)
                          .collection("orders")
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          );
                        }

                        final orders = snapshot.data!.docs;
                        if (orders.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text("لا توجد طلبات لهذا المطعم"),
                          );
                        }

                        int totalPrice = 0;
                        for (var o in orders) {
                          final data = o.data() as Map<String, dynamic>;
                          totalPrice +=
                              (data["price"] is int) ? data["price"] as int : 0;
                        }

                        int commission = (totalPrice * 0.1).toInt();
                        int finalPrice = totalPrice - commission;

                        return Column(
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: orders.length,
                              itemBuilder: (context, i) {
                                final data =
                                    orders[i].data() as Map<String, dynamic>;
                                return ListTile(
                                  title: Text("طلب ${i + 1}"),
                                  subtitle:
                                      Text("المبلغ: ${data["price"] ?? 0} د.ع"),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Text("المجموع: $totalPrice د.ع"),
                                  Text("العمولة (10%): $commission د.ع"),
                                  Text("المبلغ بعد الخصم: $finalPrice د.ع"),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => transferToRestaurant(
                                        restaurantId, totalPrice, 0.1),
                                    child: const Text("تم تحويل النقود"),
                                  ),
                                ],
                              ),
                            )
                          ],
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

/// ------------------------- واجهة إنشاء عرض طاقة شمسية -------------------------
class CreateSolarOfferPage extends StatefulWidget {
  final String ownerId;
  const CreateSolarOfferPage({super.key, required this.ownerId});

  @override
  State<CreateSolarOfferPage> createState() => _CreateSolarOfferPageState();
}

class _CreateSolarOfferPageState extends State<CreateSolarOfferPage> {
  final titleController = TextEditingController();
  final detailsController = TextEditingController();
  final priceController = TextEditingController();
  File? imageFile;
  final ImagePicker picker = ImagePicker();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<void> _createOffer() async {
    if (titleController.text.isEmpty ||
        detailsController.text.isEmpty ||
        priceController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى ملء جميع الحقول")),
      );
      return;
    }

    await firestore.collection("solar_offers").add({
      "title": titleController.text,
      "details": detailsController.text,
      "price": int.parse(priceController.text),
      "ownerId": widget.ownerId, // ✅ ربط العرض بالمالك
      "createdAt": FieldValue.serverTimestamp(),
      "imagePath": imageFile?.path ?? "",
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم إنشاء العرض ✅")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إنشاء عرض طاقة شمسية")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "العنوان",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "التفاصيل",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "السعر",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            imageFile == null
                ? const Text("لم يتم اختيار صورة")
                : Image.file(imageFile!, height: 150),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text("اختر صورة"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _createOffer,
              child: const Text("إنشاء العرض"),
            ),
          ],
        ),
      ),
    );
  }
}
