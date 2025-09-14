import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../widgets/ui.dart';
import '../../../services/fare_calculator.dart';

class RequestBlacksmith extends StatefulWidget {
  final String userId; // معرف المواطن الموحد
  const RequestBlacksmith({super.key, required this.userId});

  @override
  State<RequestBlacksmith> createState() => _RequestBlacksmithState();
}

class _RequestBlacksmithState extends State<RequestBlacksmith> {
  final name = TextEditingController();
  final details = TextEditingController();
  final phone = TextEditingController();

  int workers = 0;
  int price = 60000;
  double? lat;
  double? lng;
  bool loading = false;

  void _calc() {
    setState(() => price = FareCalculator.craftsmanBase(workers));
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return; // حماية
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("خدمة الموقع غير مفعلة.")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return; // حماية
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لم يتم السماح بالوصول إلى الموقع.")),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (!mounted) return; // حماية

    setState(() {
      lat = pos.latitude;
      lng = pos.longitude;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم تحديد الموقع بنجاح.")),
    );
  }

  Future<void> _submit() async {
    if (name.text.isEmpty || phone.text.isEmpty || lat == null) {
      if (!mounted) return; // حماية
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("يرجى تعبئة الاسم، الهاتف وتحديد الموقع.")),
      );
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseFirestore.instance.collection('admin_requests').add({
        'type': 'blacksmith',
        'name': name.text,
        'details': details.text,
        'phone': phone.text,
        'workers': workers,
        'price': price,
        'lat': lat,
        'lng': lng,
        'userId': widget.userId, // ربط الطلب باليوزر الموحد
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return; // حماية
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: const Text('تم إرسال طلب الحداد، سنتواصل معك قريباً.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // العودة للصفحة الرئيسية للمواطن
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return; // حماية
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _calc();
    return Scaffold(
      appBar: AppBar(title: const Text('طلب حداد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: "الاسم"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: "رقم الهاتف العراقي"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: details,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "تفاصيل العمل"),
          ),
          const SizedBox(height: 8),
          const Align(
              alignment: Alignment.centerLeft, child: Text('عدد العمال:')),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('حداد فقط'),
                selected: workers == 0,
                onSelected: (_) {
                  workers = 0;
                  _calc();
                }),
            ChoiceChip(
                label: const Text('مع عامل'),
                selected: workers == 1,
                onSelected: (_) {
                  workers = 1;
                  _calc();
                }),
            ChoiceChip(
                label: const Text('مع عاملان'),
                selected: workers == 2,
                onSelected: (_) {
                  workers = 2;
                  _calc();
                }),
          ]),
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('السعر التقديري: $price د.ع')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _getLocation,
            child: Text(lat == null ? 'تحديد موقعي' : 'تم تحديد الموقع'),
          ),
          const SizedBox(height: 12),
          loading
              ? const CircularProgressIndicator()
              : primaryButton('اطلب الآن', _submit),
        ]),
      ),
    );
  }
}
