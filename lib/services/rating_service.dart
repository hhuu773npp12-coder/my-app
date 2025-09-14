// lib/services/rating_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// خدمة التقييمات والمراجعات
class RatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إضافة تقييم جديد
  static Future<void> addRating({
    required String orderId,
    required String customerId,
    required String serviceProviderId,
    required double rating,
    required String comment,
    required String serviceType,
    List<String>? tags,
  }) async {
    try {
      await _firestore.collection('ratings').add({
        'orderId': orderId,
        'customerId': customerId,
        'serviceProviderId': serviceProviderId,
        'rating': rating,
        'comment': comment,
        'serviceType': serviceType,
        'tags': tags ?? [],
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _updateProviderRating(serviceProviderId);
    } catch (e) {
      throw Exception('فشل في إضافة التقييم: $e');
    }
  }

  /// تحديث متوسط التقييم لمقدم الخدمة
  static Future<void> _updateProviderRating(String providerId) async {
    final ratingsSnapshot = await _firestore
        .collection('ratings')
        .where('serviceProviderId', isEqualTo: providerId)
        .get();

    if (ratingsSnapshot.docs.isEmpty) return;

    double totalRating = 0;
    int count = ratingsSnapshot.docs.length;

    for (final doc in ratingsSnapshot.docs) {
      totalRating += (doc.data()['rating'] as num).toDouble();
    }

    final averageRating = totalRating / count;

    await _firestore.collection('users').doc(providerId).update({
      'averageRating': averageRating,
      'totalRatings': count,
    });
  }

  /// الحصول على تقييمات مقدم خدمة
  static Stream<QuerySnapshot> getProviderRatings(String providerId) {
    return _firestore
        .collection('ratings')
        .where('serviceProviderId', isEqualTo: providerId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// الحصول على متوسط التقييم
  static Future<Map<String, dynamic>> getProviderRatingStats(
      String providerId) async {
    final ratingsSnapshot = await _firestore
        .collection('ratings')
        .where('serviceProviderId', isEqualTo: providerId)
        .get();

    if (ratingsSnapshot.docs.isEmpty) {
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
        'ratingDistribution': {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      };
    }

    double totalRating = 0;
    Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    for (final doc in ratingsSnapshot.docs) {
      final rating = (doc.data()['rating'] as num).toDouble();
      totalRating += rating;
      distribution[rating.round()] = (distribution[rating.round()] ?? 0) + 1;
    }

    return {
      'averageRating': totalRating / ratingsSnapshot.docs.length,
      'totalRatings': ratingsSnapshot.docs.length,
      'ratingDistribution': distribution,
    };
  }

  /// التحقق من إمكانية التقييم
  static Future<bool> canRate(String orderId, String customerId) async {
    final existingRating = await _firestore
        .collection('ratings')
        .where('orderId', isEqualTo: orderId)
        .where('customerId', isEqualTo: customerId)
        .get();

    return existingRating.docs.isEmpty;
  }
}

/// ويدجت النجوم
class StarRating extends StatefulWidget {
  final double initialRating;
  final Function(double) onRatingChanged;
  final bool readOnly;
  final double size;

  const StarRating({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.readOnly = false,
    this.size = 30,
  });

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  late double _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: widget.readOnly
              ? null
              : () {
                  setState(() {
                    _rating = index + 1.0;
                  });
                  widget.onRatingChanged(_rating);
                },
          child: Icon(
            index < _rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: widget.size,
          ),
        );
      }),
    );
  }
}

/// شاشة التقييم
class RatingScreen extends StatefulWidget {
  final String orderId;
  final String serviceProviderId;
  final String serviceType;
  final String customerName;

  const RatingScreen({
    super.key,
    required this.orderId,
    required this.serviceProviderId,
    required this.serviceType,
    required this.customerName,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  final List<String> _selectedTags = [];
  bool _isSubmitting = false;

  final List<String> _availableTags = [
    'سريع',
    'مهذب',
    'نظيف',
    'محترف',
    'دقيق في الموعد',
    'أسعار معقولة',
    'جودة عالية',
    'تعامل ممتاز',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييم الخدمة'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'كيف كانت تجربتك؟',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Center(
              child: StarRating(
                initialRating: _rating,
                onRatingChanged: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'اكتب تعليقك (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'اختر ما يناسب تجربتك:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rating > 0 && !_isSubmitting ? _submitRating : null,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال التقييم'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await RatingService.addRating(
        orderId: widget.orderId,
        customerId: 'current_user_id', // ضع ID المستخدم الحالي هنا
        serviceProviderId: widget.serviceProviderId,
        serviceType: widget.serviceType,
        rating: _rating,
        comment: _commentController.text.trim(),
        tags: _selectedTags,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال التقييم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال التقييم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
