// lib/features/citizen/requests/request_kiahaml.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../../widgets/ui.dart';
import '../../../services/fare_calculator.dart';
import '../citizen_home.dart';
import '../../../notification_service.dart';

class RequestKiahaml extends StatefulWidget {
  final String userId;
  const RequestKiahaml({super.key, required this.userId});

  @override
  State<RequestKiahaml> createState() => _RequestKiahamlState();
}

class _RequestKiahamlState extends State<RequestKiahaml> {
  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();

  GoogleMapController? mapController;
  LatLng? origin;
  LatLng? destination;
  int? fare;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  bool submitting = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    mapController = null;
    super.dispose();
  }

  void _addMarker(String id, LatLng pos,
      {BitmapDescriptor? icon, String? title}) {
    markers.removeWhere((m) => m.markerId.value == id);
    markers.add(Marker(
      markerId: MarkerId(id),
      position: pos,
      icon: icon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(title: title),
    ));
  }

  void _onMapTap(LatLng pos) {
    setState(() {
      if (origin == null) {
        origin = pos;
        _addMarker("origin", pos, title: "نقطة الانطلاق");
      } else {
        destination = pos;
        _addMarker("destination", pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            title: "الوجهة");
        _calculateFare();
        _drawSimplePolyline();
      }
    });
  }

  void _drawSimplePolyline() {
    if (origin == null || destination == null) return;
    polylines = {
      Polyline(
        polylineId: const PolylineId("route"),
        points: [origin!, destination!],
        color: Colors.blue,
        width: 4,
      ),
    };
  }

  void _calculateFare() {
    if (origin == null || destination == null) return;
    final meters = Geolocator.distanceBetween(
      origin!.latitude,
      origin!.longitude,
      destination!.latitude,
      destination!.longitude,
    );
    final km = meters / 1000.0;
    final price = FareCalculator.kiaCargo(km);
    setState(() => fare = price);
  }

  Future<void> _sendRequest() async {
    if (!mounted) return;

    if (origin == null || destination == null || fare == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ الرجاء تحديد نقطة الانطلاق والوجهة")),
      );
      return;
    }
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ الرجاء إدخال الاسم ورقم الهاتف")),
      );
      return;
    }

    setState(() => submitting = true);
    try {
      final docRef =
          await FirebaseFirestore.instance.collection("taxi_requests").add({
        "name": name.text.trim(),
        "phone": phone.text.trim(),
        "origin": {"lat": origin!.latitude, "lng": origin!.longitude},
        "destination": {
          "lat": destination!.latitude,
          "lng": destination!.longitude
        },
        "price": fare,
        "status": "pending",
        "userId": widget.userId,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KiaOrderTrackingScreen(
            origin: origin!,
            destination: destination!,
            driverId: "",
            price: fare!,
            commission: (fare! * 0.1).round(),
            orderId: docRef.id,
            userId: widget.userId,
          ),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم إرسال طلب الكيا إلى الإدارة")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ فشل إرسال الطلب: $e")),
      );
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب كيا حمل')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition:
                  const CameraPosition(target: LatLng(32.788, 44.3), zoom: 13),
              onMapCreated: (c) => mapController = c,
              myLocationEnabled: true,
              zoomControlsEnabled: true,
              markers: markers,
              polylines: polylines,
              onTap: _onMapTap,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                LabeledField(label: "الاسم", controller: name),
                const SizedBox(height: 8),
                LabeledField(
                    label: "رقم الهاتف",
                    controller: phone,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 8),
                if (fare != null)
                  Text("السعر التقديري: $fare د.ع",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                submitting
                    ? const CircularProgressIndicator()
                    : primaryButton("تأكيد الطلب", _sendRequest),
                const SizedBox(height: 8),
                const Text("ملاحظة: السعر محسوب بواسطة دالة kiaCargo (كم)."),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// شاشة متابعة الطلب
class KiaOrderTrackingScreen extends StatefulWidget {
  final LatLng origin;
  final LatLng destination;
  final String driverId;
  final int price;
  final int commission;
  final String orderId;
  final String userId;

  const KiaOrderTrackingScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.driverId,
    required this.price,
    required this.commission,
    required this.orderId,
    required this.userId,
  });

  @override
  State<KiaOrderTrackingScreen> createState() => _KiaOrderTrackingScreenState();
}

class _KiaOrderTrackingScreenState extends State<KiaOrderTrackingScreen> {
  GoogleMapController? mapController;
  LatLng? driverLocation;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;
  String? _currentDriverId;

  @override
  void initState() {
    super.initState();
    _setInitialMarkers();
    _listenToOrderDoc();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _driverSub?.cancel();
    mapController = null;
    super.dispose();
  }

  void _setInitialMarkers() {
    markers = {
      Marker(
          markerId: const MarkerId("origin"),
          position: widget.origin,
          infoWindow: const InfoWindow(title: "نقطة الانطلاق")),
      Marker(
          markerId: const MarkerId("destination"),
          position: widget.destination,
          infoWindow: const InfoWindow(title: "الوجهة"),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
    };
    _drawRoutePolyline();
  }

  void _drawRoutePolyline() {
    polylines = {
      Polyline(
          polylineId: const PolylineId("route"),
          points: [widget.origin, widget.destination],
          color: Colors.blue,
          width: 4),
    };
  }

  void _listenToOrderDoc() {
    _orderSub = FirebaseFirestore.instance
        .collection("taxi_requests")
        .doc(widget.orderId)
        .snapshots()
        .listen((orderDoc) {
      if (!mounted) return;
      if (!orderDoc.exists) return;
      final data = orderDoc.data()!;
      final driverId = (data['driverId'] ?? "") as String;
      final status = (data['status'] ?? "") as String;

      if (driverId.isNotEmpty && driverId != _currentDriverId) {
        _currentDriverId = driverId;
        _driverSub?.cancel();
        _driverSub = FirebaseFirestore.instance
            .collection("drivers")
            .doc(driverId)
            .snapshots()
            .listen((driverDoc) {
          if (!mounted) return;
          if (!driverDoc.exists) return;
          final driverData = driverDoc.data()!;
          final latVal = driverData['lat'];
          final lngVal = driverData['lng'];
          if (latVal != null && lngVal != null) {
            final lat = (latVal is num)
                ? latVal.toDouble()
                : double.tryParse(latVal.toString()) ?? widget.origin.latitude;
            final lng = (lngVal is num)
                ? lngVal.toDouble()
                : double.tryParse(lngVal.toString()) ?? widget.origin.longitude;
            driverLocation = LatLng(lat, lng);
            _updateMarkersAndPolyline();
            mapController
                ?.animateCamera(CameraUpdate.newLatLng(driverLocation!));
          }
        });
      }

      if (status == 'completed') {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("تم إكمال الرحلة ✅")));
      }
    });
  }

  void _updateMarkersAndPolyline() {
    final updated = Set<Marker>.from(markers);
    updated.removeWhere((m) => m.markerId.value == "driver");
    if (driverLocation != null) {
      updated.add(Marker(
        markerId: const MarkerId("driver"),
        position: driverLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: "موقع السائق"),
      ));
    }
    setState(() {
      markers = updated;
      if (driverLocation != null) {
        polylines = {
          Polyline(
              polylineId: const PolylineId('route'),
              points: [driverLocation!, widget.origin, widget.destination],
              color: Colors.blue,
              width: 4)
        };
      } else {
        _drawRoutePolyline();
      }
    });
  }

  Future<void> _cancelTrip() async {
    try {
      await FirebaseFirestore.instance
          .collection("taxi_requests")
          .doc(widget.orderId)
          .update({"status": "canceled_by_user"});

      final driverId = _currentDriverId ?? "";
      if (driverId.isNotEmpty) {
        final driverDoc = await FirebaseFirestore.instance
            .collection("drivers")
            .doc(driverId)
            .get();
        if (driverDoc.exists) {
          final token = driverDoc.data()?['token'] as String?;
          if (token != null && token.isNotEmpty) {
            try {
              await NotificationService.sendNotification(
                token: token,
                title: "تم إلغاء الرحلة",
                body: "قام المستخدم بإلغاء الطلب رقم ${widget.orderId}",
                data: {"orderId": widget.orderId, "status": "canceled"},
              );
            } catch (e) {
              debugPrint("خطأ أثناء إرسال إشعار للسائق: $e");
            }
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("تم إلغاء الرحلة بنجاح")));
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => CitizenHomeScreen(userId: widget.userId)),
          (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("خطأ أثناء الإلغاء: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("متابعة الطلب")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: widget.origin, zoom: 13),
        markers: markers,
        polylines: polylines,
        myLocationEnabled: true,
        zoomControlsEnabled: true,
        onMapCreated: (c) => mapController = c,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("السعر: ${widget.price} د.ع"),
            Text("عمولة: ${widget.commission} د.ع"),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _cancelTrip,
              child: const Text("إلغاء الرحلة"),
            ),
          ],
        ),
      ),
    );
  }
}
