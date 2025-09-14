import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../widgets/ui.dart';
import '../../../services/fare_calculator.dart';

class RequestElectrician extends StatefulWidget {
  final String userId; // ربط الطلب باليوزر الموحد
  const RequestElectrician({super.key, required this.userId});

  @override
  State<RequestElectrician> createState() => _RequestElectricianState();
}

class _RequestElectricianState extends State<RequestElectrician> {
  final name = TextEditingController();
  final details = TextEditingController();
  final phone = TextEditingController();

  int workers = 0;
  int price = 50000;
  double? lat;
  double? lng;
  bool loading = false;

  void _calc() {
    setState(() => price = FareCalculator.craftsmanBase(workers));
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ يجب تفعيل خدمات الموقع")));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ تم رفض صلاحية الموقع")));
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (!mounted) return;
    setState(() {
      lat = pos.latitude;
      lng = pos.longitude;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ تم تحديد الموقع بنجاح.")),
    );
  }

  Future<void> _submit() async {
    if (name.text.isEmpty || phone.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ يرجى ملء الاسم ورقم الهاتف")));
      return;
    }

    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ يرجى تحديد موقعك أولاً")));
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance.collection('serviceRequests').add({
        'type': 'electrician',
        'name': name.text,
        'details': details.text,
        'phone': phone.text,
        'workers': workers,
        'price': price,
        'lat': lat,
        'lng': lng,
        'userId': widget.userId,
        'status': 'pending',
        'assignedUsers': [],
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: const Text('✅ تم إرسال طلب الكهربائي، سنتواصل معك قريباً.'),
          actions: [
            TextButton(
                onPressed: () {
                  if (!mounted) return;
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('حسناً'))
          ],
        ),
      );

      // إعادة تعيين الحقول
      if (!mounted) return;
      name.clear();
      phone.clear();
      details.clear();
      setState(() {
        workers = 0;
        price = FareCalculator.craftsmanBase(0);
        lat = null;
        lng = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ حدث خطأ: $e")));
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _calc();
    return Scaffold(
      appBar: AppBar(title: const Text('طلب كهربائي')),
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
                label: const Text('كهربائي فقط'),
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
