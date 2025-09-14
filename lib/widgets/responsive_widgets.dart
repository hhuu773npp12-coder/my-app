// lib/widgets/responsive_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/responsive_helper.dart';
import '../utils/ui_improvements.dart';

/// بطاقة خدمة متجاوبة
class ResponsiveServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const ResponsiveServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveHelper.responsiveContainer(
      context: context,
      widthPercentage: ResponsiveHelper.isMobile(context) ? 0.45 : 0.3,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(ResponsiveHelper.getSpacing(context, 16)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(ResponsiveHelper.getSpacing(context, 16)),
          child: Container(
            padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 16)),
            decoration: BoxDecoration(
              gradient: backgroundColor != null
                  ? LinearGradient(
                      colors: [
                        backgroundColor!,
                        backgroundColor!.withAlpha((0.8 * 255).toInt())
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : UIImprovements.primaryGradient,
              borderRadius: BorderRadius.circular(
                  ResponsiveHelper.getSpacing(context, 16)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: ResponsiveHelper.getIconSize(context, 40),
                  color: iconColor ?? Colors.white,
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
                ResponsiveHelper.responsiveText(
                  title,
                  context: context,
                  baseFontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                ResponsiveHelper.responsiveText(
                  subtitle,
                  context: context,
                  baseFontSize: 12,
                  color: Colors.white70,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شبكة خدمات متجاوبة
class ResponsiveServicesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> services;

  const ResponsiveServicesGrid({
    super.key,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveHelper.responsiveGrid(
      context: context,
      childAspectRatio: ResponsiveHelper.isMobile(context) ? 1.0 : 1.2,
      children: services.map((service) {
        return ResponsiveServiceCard(
          title: service['title'] ?? '',
          subtitle: service['subtitle'] ?? '',
          icon: service['icon'] ?? Icons.help,
          onTap: service['onTap'] ?? () {},
          backgroundColor: service['color'],
          iconColor: service['iconColor'],
        );
      }).toList(),
    );
  }
}

/// شريط تطبيق متجاوب
class ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final double toolbarHeight;

  const ResponsiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
  }) : toolbarHeight = 56.0; // ارتفاع افتراضي

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: ResponsiveHelper.responsiveText(
        title,
        context: context,
        baseFontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? UIImprovements.primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      leading: leading,
      actions: actions,
      toolbarHeight: toolbarHeight,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}

/// حاوية معلومات متجاوبة
class ResponsiveInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const ResponsiveInfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(ResponsiveHelper.getSpacing(context, 12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(ResponsiveHelper.getSpacing(context, 12)),
        child: Container(
          padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 16)),
          child: Row(
            children: [
              CircleAvatar(
                radius: ResponsiveHelper.getIconSize(context, 20),
                backgroundColor:
                    (color ?? UIImprovements.primaryColor).withAlpha(25),
                child: Icon(
                  icon,
                  size: ResponsiveHelper.getIconSize(context, 20),
                  color: color ?? UIImprovements.primaryColor,
                ),
              ),
              SizedBox(width: ResponsiveHelper.getSpacing(context, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveHelper.responsiveText(
                      title,
                      context: context,
                      baseFontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                    ResponsiveHelper.responsiveText(
                      value,
                      context: context,
                      baseFontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveHelper.getIconSize(context, 16),
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// قائمة متجاوبة للطلبات
class ResponsiveOrdersList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final Function(Map<String, dynamic>) onOrderTap;

  const ResponsiveOrdersList({
    super.key,
    required this.orders,
    required this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: ResponsiveHelper.getIconSize(context, 64),
              color: Colors.grey.shade400,
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
            ResponsiveHelper.responsiveText(
              'لا توجد طلبات',
              context: context,
              baseFontSize: 18,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 16)),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin:
              EdgeInsets.only(bottom: ResponsiveHelper.getSpacing(context, 12)),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(ResponsiveHelper.getSpacing(context, 12)),
          ),
          child: InkWell(
            onTap: () => onOrderTap(order),
            borderRadius:
                BorderRadius.circular(ResponsiveHelper.getSpacing(context, 12)),
            child: Container(
              padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 16)),
              child: ResponsiveHelper.responsiveLayout(
                context: context,
                mobileLayout: _buildMobileOrderLayout(context, order),
                tabletLayout: _buildTabletOrderLayout(context, order),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileOrderLayout(
      BuildContext context, Map<String, dynamic> order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ResponsiveHelper.responsiveText(
              order['title'] ?? 'طلب جديد',
              context: context,
              baseFontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getSpacing(context, 8),
                vertical: ResponsiveHelper.getSpacing(context, 4),
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(order['status']).withAlpha(25),
                borderRadius: BorderRadius.circular(
                    ResponsiveHelper.getSpacing(context, 8)),
              ),
              child: ResponsiveHelper.responsiveText(
                _getStatusText(order['status']),
                context: context,
                baseFontSize: 12,
                color: _getStatusColor(order['status']),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
        ResponsiveHelper.responsiveText(
          order['description'] ?? 'وصف الطلب',
          context: context,
          baseFontSize: 14,
          color: Colors.grey.shade600,
          maxLines: 2,
        ),
        SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ResponsiveHelper.responsiveText(
              '${order['price'] ?? 0} د.ع',
              context: context,
              baseFontSize: 16,
              fontWeight: FontWeight.bold,
              color: UIImprovements.primaryColor,
            ),
            ResponsiveHelper.responsiveText(
              order['date'] ?? '',
              context: context,
              baseFontSize: 12,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletOrderLayout(
      BuildContext context, Map<String, dynamic> order) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildMobileOrderLayout(context, order),
        ),
        SizedBox(width: ResponsiveHelper.getSpacing(context, 16)),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              ResponsiveHelper.responsiveButton(
                context: context,
                text: 'عرض التفاصيل',
                onPressed: () {},
                baseFontSize: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'معلق';
      case 'accepted':
        return 'مقبول';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير محدد';
    }
  }
}

/// تبويبات متجاوبة
class ResponsiveTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Function(int) onTabSelected;

  const ResponsiveTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 16)),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius:
            BorderRadius.circular(ResponsiveHelper.getSpacing(context, 12)),
      ),
      child: ResponsiveHelper.isMobile(context)
          ? _buildMobileTabs(context)
          : _buildTabletTabs(context),
    );
  }

  Widget _buildMobileTabs(BuildContext context) {
    return Row(
      children: tabs.asMap().entries.map((entry) {
        final index = entry.key;
        final title = entry.value;
        final isSelected = index == selectedIndex;

        return Expanded(
          child: GestureDetector(
            onTap: () => onTabSelected(index),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveHelper.getSpacing(context, 12),
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? UIImprovements.primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(
                    ResponsiveHelper.getSpacing(context, 12)),
              ),
              child: ResponsiveHelper.responsiveText(
                title,
                context: context,
                baseFontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabletTabs(BuildContext context) {
    return Wrap(
      children: tabs.asMap().entries.map((entry) {
        final index = entry.key;
        final title = entry.value;
        final isSelected = index == selectedIndex;

        return GestureDetector(
          onTap: () => onTabSelected(index),
          child: Container(
            margin: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 4)),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.getSpacing(context, 16),
              vertical: ResponsiveHelper.getSpacing(context, 12),
            ),
            decoration: BoxDecoration(
              color:
                  isSelected ? UIImprovements.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(
                  ResponsiveHelper.getSpacing(context, 12)),
            ),
            child: ResponsiveHelper.responsiveText(
              title,
              context: context,
              baseFontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        );
      }).toList(),
    );
  }
}
