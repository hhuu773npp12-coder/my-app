import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/ui.dart';
import '../../../services/fare_calculator.dart';

class RequestTechnician extends StatefulWidget {
  final String userId; // ربط الطلب باليوزر الموحد
  const RequestTechnician({super.key, required this.userId});

  @override
  State<RequestTechnician> createState() => _RequestTechnicianState();
}

class _RequestTechnicianState extends State<RequestTechnician> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final details = TextEditingController();
  final phone = TextEditingController();

  int workers = 0; // 0 = فني فقط
  int price = FareCalculator.craftsmanBase(0);

  String? orderId;
  String status = "draft"; // draft -> pending -> accepted/cancelled

  void _calculatePrice() {
    setState(() {
      price = FareCalculator.craftsmanBase(workers);
    });
  }

  Future<void> _sendRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => status = "pending"); // مؤقت أثناء الإرسال

    try {
      final docRef =
          await FirebaseFirestore.instance.collection('serviceRequests').add({
        'service': 'technician',
        'name': name.text,
        'details': details.text,
        'phone': phone.text,
        'workers': workers,
        'price': price,
        'userId': widget.userId,
        'status': 'pending',
        'assignedUsers': [],
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return; // حماية الـ context بعد await

      setState(() {
        orderId = docRef.id;
        status = "pending";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إرسال الطلب بنجاح')),
      );

      // إعادة تعيين الحقول
      name.clear();
      details.clear();
      phone.clear();
      setState(() {
        workers = 0;
        _calculatePrice();
      });
    } catch (e) {
      if (!mounted) return; // حماية الـ context بعد await
      setState(() => status = "draft");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء إرسال الطلب: $e')),
      );
    }
  }

  Future<void> _cancelRequest() async {
    if (orderId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(orderId)
          .update({'status': 'cancelled'});

      if (!mounted) return; // حماية الـ context بعد await
      setState(() => status = "cancelled");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إلغاء الطلب')),
      );
    } catch (e) {
      if (!mounted) return; // حماية الـ context بعد await
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء إلغاء الطلب: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب فني تبريد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
                validator: (value) =>
                    value!.isEmpty ? 'الرجاء إدخال الاسم' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: details,
                decoration: const InputDecoration(labelText: 'تفاصيل العمل'),
                maxLines: 4,
                validator: (value) =>
                    value!.isEmpty ? 'الرجاء إدخال التفاصيل' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value!.isEmpty ? 'الرجاء إدخال رقم الهاتف' : null,
              ),
              const SizedBox(height: 12),
              const Align(
                  alignment: Alignment.centerLeft, child: Text('عدد العمال:')),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('فني فقط'),
                    selected: workers == 0,
                    onSelected: (_) {
                      setState(() {
                        workers = 0;
                        _calculatePrice();
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('مع عامل'),
                    selected: workers == 1,
                    onSelected: (_) {
                      setState(() {
                        workers = 1;
                        _calculatePrice();
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('مع عاملان'),
                    selected: workers == 2,
                    onSelected: (_) {
                      setState(() {
                        workers = 2;
                        _calculatePrice();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('السعر التقديري: $price د.ع')),
              const SizedBox(height: 12),
              if (status == "draft") primaryButton('اطلب الآن', _sendRequest),
              if (status == "pending")
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _cancelRequest,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('إلغاء الطلب'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'طلبك قيد الانتظار...',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              if (status == "cancelled")
                const Text(
                  'تم إلغاء الطلب',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
