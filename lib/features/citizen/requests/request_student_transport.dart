// lib/features/citizen/requests/request_student_transport.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/fare_calculator.dart';

class RequestStudentTransportScreen extends StatefulWidget {
  final String userId;
  const RequestStudentTransportScreen({super.key, required this.userId});

  @override
  State<RequestStudentTransportScreen> createState() =>
      _RequestStudentTransportScreenState();
}

class _RequestStudentTransportScreenState
    extends State<RequestStudentTransportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _numOfStudentsController =
      TextEditingController(text: "1");

  LatLng? _origin;
  LatLng? _destination;
  String _studentType = 'school';
  double _distanceKm = 0;
  int _calculatedPrice = 0;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  void _updateMarker(LatLng pos, String id) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == id);
      _markers.add(Marker(markerId: MarkerId(id), position: pos));

      if (id == 'origin') {
        _origin = pos;
      } else {
        _destination = pos;
      }

      if (_origin != null && _destination != null) {
        _calculateDistanceAndFare();
        _updatePolyline();
      }
    });
  }

  void _updatePolyline() {
    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: [_origin!, _destination!],
      color: Colors.blue,
      width: 5,
    ));
  }

  void _calculateDistanceAndFare() {
    final meters = Geolocator.distanceBetween(
      _origin!.latitude,
      _origin!.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );
    _distanceKm = meters / 1000.0;

    final numStudents = int.tryParse(_numOfStudentsController.text) ?? 1;
    int price = 0;

    if (_studentType == 'school') {
      price = PassengerFareCalculator.schoolFare(_distanceKm) * numStudents;
    } else {
      price = PassengerFareCalculator.universityDailyFare(_distanceKm) *
          numStudents;
    }

    setState(() {
      _calculatedPrice = price;
    });
  }

  void _resetLocations() {
    setState(() {
      _origin = null;
      _destination = null;
      _markers.clear();
      _polylines.clear();
      _distanceKm = 0;
      _calculatedPrice = 0;
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_origin == null || _destination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('يرجى تحديد موقع المنزل والمدرسة/الجامعة')),
      );
      return;
    }

    final orderData = {
      "userId": widget.userId,
      "name": _nameController.text.trim(),
      "phone": _phoneController.text.trim(),
      "studentType": _studentType,
      "origin": {"lat": _origin!.latitude, "lng": _origin!.longitude},
      "destination": {
        "lat": _destination!.latitude,
        "lng": _destination!.longitude
      },
      "distanceKm": _distanceKm,
      "price": _calculatedPrice,
      "numOfStudents": int.tryParse(_numOfStudentsController.text) ?? 1,
      "status": "pending",
      "assignedUsers": [],
      "createdAt": Timestamp.now(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .add(orderData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم إرسال الطلب بنجاح')),
      );
      _formKey.currentState!.reset();
      _resetLocations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء إرسال الطلب: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب نقل الطلاب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تعيين المواقع',
            onPressed: _resetLocations,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                  target: LatLng(33.3152, 44.3661), zoom: 14),
              markers: _markers,
              polylines: _polylines,
              onTap: (pos) {
                if (_origin == null) {
                  _updateMarker(pos, 'origin');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديد موقع المنزل')),
                  );
                } else if (_destination == null) {
                  _updateMarker(pos, 'destination');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم تحديد موقع المدرسة/الجامعة')),
                  );
                }
              },
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'اسم ولي الأمر'),
                        validator: (value) =>
                            value!.isEmpty ? 'الرجاء إدخال الاسم' : null,
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration:
                            const InputDecoration(labelText: 'رقم الهاتف'),
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value!.isEmpty ? 'الرجاء إدخال رقم الهاتف' : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _studentType, // تم التعديل هنا
                        items: const [
                          DropdownMenuItem(
                              value: 'school', child: Text('مدرسة')),
                          DropdownMenuItem(
                              value: 'university', child: Text('جامعة')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _studentType = value!;
                            if (_origin != null && _destination != null) {
                              _calculateDistanceAndFare();
                            }
                          });
                        },
                        decoration:
                            const InputDecoration(labelText: 'نوع الطالب'),
                      ),
                      TextFormField(
                        controller: _numOfStudentsController,
                        decoration:
                            const InputDecoration(labelText: 'عدد الطلاب'),
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            value!.isEmpty ? 'الرجاء إدخال عدد الطلاب' : null,
                        onChanged: (_) {
                          if (_origin != null && _destination != null) {
                            _calculateDistanceAndFare();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'المسافة: ${_distanceKm.toStringAsFixed(2)} كم',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الأجرة: $_calculatedPrice د.ع',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _calculatedPrice > 0
                                ? Colors.green
                                : Colors.black),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _calculatedPrice > 0 ? _submitRequest : null,
                        child: const Text('تأكيد الطلب '),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
