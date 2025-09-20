// lib/services/offline_service.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';

/// خدمة العمل بدون إنترنت
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final Connectivity _connectivity = Connectivity();
  final List<Map<String, dynamic>> _pendingOperations = [];
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// تهيئة خدمة العمل بدون إنترنت
  Future<void> initialize() async {
    // فحص الاتصال الحالي
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;

    // الاستماع لتغييرات الاتصال
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final wasOnline = _isOnline;
        _isOnline = results.any((result) => result != ConnectivityResult.none);

        if (!wasOnline && _isOnline) {
          // عاد الاتصال - تنفيذ العمليات المعلقة
          _syncPendingOperations();
        }
      },
    );

    // تحميل العمليات المعلقة من التخزين المحلي
    await _loadPendingOperations();
  }

  /// التحقق من حالة الاتصال
  bool get isOnline => _isOnline;

  /// حفظ البيانات محلياً
  Future<void> saveOfflineData(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(data);
    await prefs.setString('offline_$key', jsonString);
  }

  /// استرجاع البيانات المحفوظة محلياً
  Future<Map<String, dynamic>?> getOfflineData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('offline_$key');
    if (jsonString == null) return null;

    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// إضافة عملية للقائمة المعلقة
  Future<void> addPendingOperation({
    required String type,
    required String collection,
    required Map<String, dynamic> data,
    String? documentId,
  }) async {
    final operation = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type, // 'create', 'update', 'delete'
      'collection': collection,
      'documentId': documentId,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _pendingOperations.add(operation);
    await _savePendingOperations();
  }

  /// تنفيذ العمليات المعلقة عند عودة الاتصال
  Future<void> _syncPendingOperations() async {
    if (_pendingOperations.isEmpty) return;

    final operationsToRemove = <Map<String, dynamic>>[];

    for (final operation in _pendingOperations) {
      try {
        await _executeOperation(operation);
        operationsToRemove.add(operation);
      } catch (e) {
        debugPrint('Failed to sync operation: $e');
      }
    }

    // إزالة العمليات المنفذة بنجاح
    for (final operation in operationsToRemove) {
      _pendingOperations.remove(operation);
    }

    await _savePendingOperations();
  }

  /// تنفيذ عملية واحدة
  Future<void> _executeOperation(Map<String, dynamic> operation) async {
    final type = operation['type'];
    final collection = operation['collection'];
    final data = operation['data'] as Map<String, dynamic>;
    final documentId = operation['documentId'];

    switch (type) {
      case 'create':
        if (documentId != null) {
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(documentId)
              .set(data);
        } else {
          await FirebaseFirestore.instance.collection(collection).add(data);
        }
        break;
      case 'update':
        if (documentId != null) {
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(documentId)
              .update(data);
        }
        break;
      case 'delete':
        if (documentId != null) {
          await FirebaseFirestore.instance
              .collection(collection)
              .doc(documentId)
              .delete();
        }
        break;
    }
  }

  /// حفظ العمليات المعلقة في التخزين المحلي
  Future<void> _savePendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_pendingOperations);
    await prefs.setString('pending_operations', jsonString);
  }

  /// تحميل العمليات المعلقة من التخزين المحلي
  Future<void> _loadPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('pending_operations');
    if (jsonString == null) return;

    try {
      final operations = json.decode(jsonString) as List<dynamic>;
      _pendingOperations.clear();
      _pendingOperations.addAll(operations.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('Error loading pending operations: $e');
    }
  }

  /// تنظيف الموارد
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

/// ويدجت لإظهار حالة الاتصال
class ConnectionStatusWidget extends StatefulWidget {
  final Widget child;

  const ConnectionStatusWidget({super.key, required this.child});

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  final OfflineService _offlineService = OfflineService();
  late bool _isOnline;

  @override
  void initState() {
    super.initState();
    _isOnline = _offlineService.isOnline;

    // الاستماع لتغييرات الاتصال
    Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isOnline = results.any((result) => result != ConnectivityResult.none);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange,
            child: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'لا يوجد اتصال بالإنترنت - يتم العمل في الوضع المحلي',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// خدمة التخزين المؤقت للصور
class ImageCacheService {
  static final Map<String, String> _imageCache = {};

  /// حفظ صورة في التخزين المؤقت
  static Future<void> cacheImage(String url, String base64Data) async {
    _imageCache[url] = base64Data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('image_cache_$url', base64Data);
  }

  /// الحصول على صورة من التخزين المؤقت
  static Future<String?> getCachedImage(String url) async {
    if (_imageCache.containsKey(url)) {
      return _imageCache[url];
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('image_cache_$url');
    if (cachedData != null) {
      _imageCache[url] = cachedData;
    }
    return cachedData;
  }

  /// تنظيف التخزين المؤقت للصور
  static Future<void> clearImageCache() async {
    _imageCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('image_cache_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
