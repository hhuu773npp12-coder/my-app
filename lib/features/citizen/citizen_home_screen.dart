import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sorting/first_sort_screen.dart';

class CitizenHomeScreen extends StatefulWidget {
  final String citizenId;
  const CitizenHomeScreen({super.key, required this.citizenId});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? citizenData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCitizenData();
  }

  Future<void> _loadCitizenData() async {
    try {
      final doc =
          await _firestore.collection('citizens').doc(widget.citizenId).get();
      if (doc.exists) {
        setState(() {
          citizenData = doc.data();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isCitizenLoggedIn');
    await prefs.remove('citizenId');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserSortScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showCreateCardDialog() async {
    final cardNameController = TextEditingController();
    final cardAmountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء كارت تعبئة جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cardNameController,
              decoration: const InputDecoration(
                labelText: 'اسم الكارت',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cardAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'قيمة الكارت',
                border: OutlineInputBorder(),
                suffixText: 'دينار',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = cardNameController.text.trim();
              final amountText = cardAmountController.text.trim();

              if (name.isEmpty || amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى ملء جميع الحقول')),
                );
                return;
              }

              final amount = double.tryParse(amountText);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال قيمة صحيحة')),
                );
                return;
              }

              await _createCard(name, amount);
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCard(String cardName, double amount) async {
    try {
      // إنشاء الكارت في قاعدة البيانات
      await _firestore.collection('cards').add({
        'name': cardName,
        'amount': amount,
        'citizenId': widget.citizenId,
        'citizenName': citizenData?['name'] ?? 'غير محدد',
        'isUsed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'cardNumber': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الكارت بنجاح!')),
        );
        setState(() {}); // إعادة تحديث الواجهة
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء الكارت: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('مرحباً ${citizenData?['name'] ?? 'المواطن'}'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // معلومات المواطن
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      citizenData?['name'] ?? 'غير محدد',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'رقم الهاتف: ${citizenData?['phone'] ?? 'غير محدد'}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'الرصيد: ${citizenData?['balance']?.toStringAsFixed(2) ?? '0.00'} دينار',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // زر إنشاء كارت تعبئة
            ElevatedButton.icon(
              onPressed: _showCreateCardDialog,
              icon: const Icon(Icons.add_card),
              label: const Text('إنشاء كارت تعبئة جديد'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            // قائمة الكروت
            const Text(
              'كروت التعبئة الخاصة بي:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('cards')
                    .where('citizenId', isEqualTo: widget.citizenId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('خطأ في تحميل الكروت: ${snapshot.error}'),
                    );
                  }

                  final cards = snapshot.data?.docs ?? [];

                  if (cards.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card_off,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد كروت تعبئة',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index].data() as Map<String, dynamic>;
                      final isUsed = card['isUsed'] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isUsed ? Colors.grey : Colors.green,
                            child: Icon(
                              isUsed ? Icons.check : Icons.credit_card,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(card['name'] ?? 'كارت غير محدد'),
                          subtitle: Text(
                            'القيمة: ${card['amount']?.toStringAsFixed(2) ?? '0.00'} دينار\n'
                            'رقم الكارت: ${card['cardNumber'] ?? 'غير محدد'}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isUsed ? Colors.grey : Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isUsed ? 'مستخدم' : 'متاح',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
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
