import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' show pi, sin, cos, sqrt, atan2;

import '../../../services/fare_calculator.dart';

class RequestTaxi extends StatefulWidget {
  final String userId;
  const RequestTaxi({super.key, required this.userId});

  @override
  State<RequestTaxi> createState() => _RequestTaxiState();
}

class _RequestTaxiState extends State<RequestTaxi> {
  final name = TextEditingController();
  final phone = TextEditingController();
  GoogleMapController? mapController;
  LatLng? origin;
  LatLng? destination;
  int? fare;

  Set<Marker> markers = {};
  bool selectingOrigin = true;
  bool submitting = false;

  void _onMapTapped(LatLng position) {
    setState(() {
      if (selectingOrigin) {
        origin = position;
        markers.add(Marker(
            markerId: const MarkerId("origin"),
            position: position,
            infoWindow: const InfoWindow(title: "نقطة الانطلاق")));
        selectingOrigin = false;
      } else {
        destination = position;
        markers.add(Marker(
            markerId: const MarkerId("destination"),
            position: position,
            infoWindow: const InfoWindow(title: "الوجهة")));
      }
    });

    if (origin != null && destination != null) {
      _calculateFare();
    }
  }

  void _calculateFare() {
    final meters = _calculateDistance(origin!, destination!) * 1000;
    final price = FareCalculator.taxi(meters.toInt());
    setState(() => fare = price);
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const R = 6371; // km
    final dLat = (p2.latitude - p1.latitude) * (pi / 180);
    final dLon = (p2.longitude - p1.longitude) * (pi / 180);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(p1.latitude * (pi / 180)) *
            cos(p2.latitude * (pi / 180)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> _submitOrder() async {
    if (name.text.isEmpty ||
        phone.text.isEmpty ||
        origin == null ||
        destination == null ||
        fare == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ يرجى ملء جميع البيانات")));
      return;
    }

    setState(() => submitting = true);

    try {
      final doc = FirebaseFirestore.instance.collection("admin_orders").doc();
      await doc.set({
        "userId": widget.userId,
        "name": name.text.trim(),
        "phone": phone.text.trim(),
        "origin": {"lat": origin!.latitude, "lng": origin!.longitude},
        "destination": {
          "lat": destination!.latitude,
          "lng": destination!.longitude
        },
        "price": fare,
        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("✅ تم إرسال الطلب")));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(
            orderId: doc.id,
            userId: widget.userId,
          ),
        ),
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
      appBar: AppBar(title: const Text('طلب تكسي')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition:
                  const CameraPosition(target: LatLng(32.788, 44.3), zoom: 13),
              onMapCreated: (controller) => mapController = controller,
              markers: markers,
              onTap: _onMapTapped,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: "الاسم")),
                  TextField(
                      controller: phone,
                      decoration:
                          const InputDecoration(labelText: "رقم الهاتف"),
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),
                  if (fare != null)
                    Text("السعر: $fare د.ع",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (origin != null && destination != null && fare != null)
                    ElevatedButton(
                      onPressed: _submitOrder,
                      child: const Text("تأكيد الطلب"),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String userId;
  const OrderTrackingScreen(
      {super.key, required this.orderId, required this.userId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  String status = "pending";
  LatLng? driverLocation;

  @override
  void initState() {
    super.initState();
    _listenToOrder();
  }

  void _listenToOrder() {
    FirebaseFirestore.instance
        .collection("admin_orders")
        .doc(widget.orderId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          status = data['status'] ?? 'pending';
          if (data['driver'] != null) {
            driverLocation =
                LatLng(data['driver']['lat'], data['driver']['lng']);
          }
        });
      }
    });
  }

  Future<void> _cancelOrder() async {
    await FirebaseFirestore.instance
        .collection("admin_orders")
        .doc(widget.orderId)
        .update({"status": "canceled_by_user"});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم إلغاء الرحلة بنجاح")),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("admin_orders")
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final origin = LatLng(data['origin']['lat'], data['origin']['lng']);
          final destination =
              LatLng(data['destination']['lat'], data['destination']['lng']);

          return Scaffold(
            appBar: AppBar(title: const Text("متابعة الطلب")),
            body: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: origin, zoom: 14),
                    markers: {
                      Marker(
                          markerId: const MarkerId("origin"), position: origin),
                      Marker(
                          markerId: const MarkerId("destination"),
                          position: destination),
                      if (driverLocation != null)
                        Marker(
                            markerId: const MarkerId("driver"),
                            position: driverLocation!),
                    },
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("الحالة: $status",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("السعر: ${data['price']} د.ع",
                            style: const TextStyle(fontSize: 16)),
                        if (status != "completed" &&
                            status != "canceled_by_user")
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: _cancelOrder,
                            child: const Text("إلغاء الرحلة"),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }
}
