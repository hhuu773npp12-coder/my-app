// lib/features/citizen/campaigns/campaign_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../citizen_home.dart';

class CampaignBookingScreen extends StatefulWidget {
  final String campaignId;
  final String title;
  final int price;
  final String userId;

  const CampaignBookingScreen({
    super.key,
    required this.campaignId,
    required this.title,
    required this.price,
    required this.userId,
  });

  @override
  State<CampaignBookingScreen> createState() => _CampaignBookingScreenState();
}

class _CampaignBookingScreenState extends State<CampaignBookingScreen> {
  final TextEditingController seatCountController = TextEditingController();
  double? latitude;
  double? longitude;
  bool submitting = false;

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("خدمة الموقع غير مفعلة")));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    if (!mounted) return;
    setState(() {
      latitude = pos.latitude;
      longitude = pos.longitude;
    });
  }

  Future<void> _submitBooking() async {
    final seats = int.tryParse(seatCountController.text) ?? 1;

    if (latitude == null || longitude == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("يرجى تحديد موقعك أولاً")));
      return;
    }

    setState(() => submitting = true);

    try {
      final doc = FirebaseFirestore.instance.collection("admin_orders").doc();
      await doc.set({
        "userId": widget.userId,
        "campaignId": widget.campaignId,
        "campaignTitle": widget.title,
        "latitude": latitude,
        "longitude": longitude,
        "seats": seats,
        "price": widget.price,
        "status": "pending",
        "type": "campaign",
        "createdAt": FieldValue.serverTimestamp(),
      });

      // إنشاء إشعار للمشرف
      final notificationRef =
          FirebaseFirestore.instance.collection("admin_notifications").doc();
      await notificationRef.set({
        "title": "حجز جديد",
        "body": "تم حجز $seats مقعد في حملة ${widget.title}",
        "timestamp": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => CampaignSubmittedScreen(userId: widget.userId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ حدث خطأ: $e")));
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("حجز ${widget.title}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("حدد موقعك:"),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text("تحديد الموقع"),
              onPressed: _getCurrentLocation,
            ),
            if (latitude != null && longitude != null)
              Text("📍 خط العرض: $latitude، خط الطول: $longitude"),
            const SizedBox(height: 16),
            TextField(
              controller: seatCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "عدد المقاعد",
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: submitting ? null : _submitBooking,
                child: const Text("تأكيد الحجز"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CampaignSubmittedScreen extends StatelessWidget {
  final String userId;
  const CampaignSubmittedScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تم إرسال الطلب"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (!Navigator.canPop(context)) return;
            Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => CitizenHomeScreen(userId: userId)),
                (route) => false);
          },
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "✅ تم إرسال طلبك إلى المشرفين.\nسوف يتم الاتصال بك لتأكيد الحجز.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
