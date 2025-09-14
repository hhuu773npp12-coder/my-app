// lib/utils/performance_optimizer.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// مُحسن الأداء للتطبيق
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  // تخزين مؤقت للبيانات
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// تخزين مؤقت للبيانات مع انتهاء صلاحية
  void cacheData(String key, dynamic data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// استرجاع البيانات من التخزين المؤقت
  T? getCachedData<T>(String key) {
    if (!_cache.containsKey(key)) return null;
    
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null || DateTime.now().difference(timestamp) > _cacheExpiry) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    
    return _cache[key] as T?;
  }

  /// تنظيف التخزين المؤقت المنتهي الصلاحية
  void cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > _cacheExpiry) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// تحسين استعلامات Firestore
  static Query optimizeQuery(Query query, {
    int? limit,
    bool useCache = true,
  }) {
    if (limit != null) {
      query = query.limit(limit);
    }
    
    // إضافة المزيد من التحسينات حسب الحاجة
    return query;
  }

  /// تحميل البيانات مع التخزين المؤقت
  Future<List<DocumentSnapshot>> loadDataWithCache(
    String collectionPath,
    String cacheKey, {
    Query Function(CollectionReference)? queryBuilder,
    int? limit,
  }) async {
    // محاولة الحصول على البيانات من التخزين المؤقت
    final cachedData = getCachedData<List<DocumentSnapshot>>(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    // تحميل البيانات من Firestore
    CollectionReference collection = FirebaseFirestore.instance.collection(collectionPath);
    Query query = queryBuilder?.call(collection) ?? collection;
    
    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    // حفظ في التخزين المؤقت
    cacheData(cacheKey, docs);
    
    return docs;
  }

  /// حفظ البيانات محلياً
  static Future<void> saveToLocalStorage(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(data);
    await prefs.setString(key, jsonString);
  }

  /// استرجاع البيانات المحلية
  static Future<T?> getFromLocalStorage<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;
    
    try {
      return json.decode(jsonString) as T;
    } catch (e) {
      return null;
    }
  }
}

/// Widget محسن للصور
class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final String? assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImage({
    super.key,
    this.imageUrl,
    this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? 
            SizedBox(
              width: width,
              height: height,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? 
            Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              child: const Icon(Icons.error, color: Colors.grey),
            );
        },
        cacheWidth: width?.toInt(),
        cacheHeight: height?.toInt(),
      );
    } else if (assetPath != null) {
      return Image.asset(
        assetPath!,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: width?.toInt(),
        cacheHeight: height?.toInt(),
      );
    } else {
      return errorWidget ?? 
        Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Icon(Icons.image, color: Colors.grey),
        );
    }
  }
}

/// StreamBuilder محسن مع تخزين مؤقت
class OptimizedStreamBuilder<T> extends StatefulWidget {
  final Stream<T> stream;
  final T? initialData;
  final Widget Function(BuildContext, AsyncSnapshot<T>) builder;
  final String? cacheKey;

  const OptimizedStreamBuilder({
    super.key,
    required this.stream,
    this.initialData,
    required this.builder,
    this.cacheKey,
  });

  @override
  State<OptimizedStreamBuilder<T>> createState() => _OptimizedStreamBuilderState<T>();
}

class _OptimizedStreamBuilderState<T> extends State<OptimizedStreamBuilder<T>> {
  late Stream<T> _stream;
  T? _lastData;

  @override
  void initState() {
    super.initState();
    _stream = widget.stream;
    
    // محاولة الحصول على البيانات المخزنة مؤقتاً
    if (widget.cacheKey != null) {
      final cachedData = PerformanceOptimizer().getCachedData<T>(widget.cacheKey!);
      if (cachedData != null) {
        _lastData = cachedData;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: _stream,
      initialData: _lastData ?? widget.initialData,
      builder: (context, snapshot) {
        // حفظ البيانات الجديدة في التخزين المؤقت
        if (snapshot.hasData && widget.cacheKey != null) {
          PerformanceOptimizer().cacheData(widget.cacheKey!, snapshot.data);
          _lastData = snapshot.data;
        }
        
        return widget.builder(context, snapshot);
      },
    );
  }
}

/// مُدير الموارد لتنظيف الذاكرة
class ResourceManager {
  static final List<StreamSubscription> _subscriptions = [];
  static final List<AnimationController> _controllers = [];

  /// إضافة اشتراك للإدارة
  static void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// إضافة controller للإدارة
  static void addController(AnimationController controller) {
    _controllers.add(controller);
  }

  /// تنظيف جميع الموارد
  static void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();
  }

  /// تنظيف موارد محددة
  static void disposeSubscription(StreamSubscription subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }

  static void disposeController(AnimationController controller) {
    controller.dispose();
    _controllers.remove(controller);
  }
}
