// lib/widgets/optimized_widgets.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/performance_optimizer.dart';

/// بطاقة محسنة للخدمات
class OptimizedServiceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool isActive;

  const OptimizedServiceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.color,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isActive ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                // ignore: deprecated_member_use
                (color ?? Colors.blue).withOpacity(0.1),
                // ignore: deprecated_member_use
                (color ?? Colors.blue).withOpacity(0.05),
              ],
            ),
            border: Border.all(
              // ignore: deprecated_member_use
              color: (color ?? Colors.blue).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: (color ?? Colors.blue).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isActive ? (color ?? Colors.blue) : Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isActive ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// قائمة محسنة للطلبات
class OptimizedOrdersList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final Widget Function(DocumentSnapshot) itemBuilder;
  final Widget? emptyWidget;
  final String? cacheKey;

  const OptimizedOrdersList({
    super.key,
    required this.stream,
    required this.itemBuilder,
    this.emptyWidget,
    this.cacheKey,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedStreamBuilder<QuerySnapshot>(
      stream: stream,
      cacheKey: cacheKey,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ في تحميل البيانات',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // إعادة تحميل البيانات
                  },
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return emptyWidget ??
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد طلبات',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
        }

        return ListView.builder(
          itemCount: docs.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            return itemBuilder(docs[index]);
          },
        );
      },
    );
  }
}

/// شريط تحميل محسن
class OptimizedLoadingBar extends StatelessWidget {
  final bool isLoading;
  final Color? color;

  const OptimizedLoadingBar({
    super.key,
    required this.isLoading,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

/// زر محسن مع حالة التحميل
class OptimizedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? width;

  const OptimizedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
          foregroundColor: textColor ?? Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isLoading ? 0 : 2,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// بطاقة معلومات محسنة
class OptimizedInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const OptimizedInfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                // ignore: deprecated_member_use
                color.withOpacity(0.1),
                // ignore: deprecated_member_use
                color.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شاشة فارغة محسنة
class OptimizedEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;

  const OptimizedEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              OptimizedButton(
                text: actionText!,
                onPressed: onAction,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
