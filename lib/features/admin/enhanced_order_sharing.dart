import 'package:flutter/material.dart';
import '../../services/driver_selection_service.dart';

class EnhancedOrderSharingScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String adminId;

  const EnhancedOrderSharingScreen({
    super.key,
    required this.orderData,
    required this.adminId,
  });

  @override
  State<EnhancedOrderSharingScreen> createState() =>
      _EnhancedOrderSharingScreenState();
}

class _EnhancedOrderSharingScreenState
    extends State<EnhancedOrderSharingScreen> {
  List<Map<String, dynamic>> availableDrivers = [];
  List<Map<String, dynamic>> selectedDrivers = [];
  bool isLoading = true;
  String selectedRegion = '';
  double maxDistance = 10.0;
  int maxDrivers = 5;

  final List<String> regions = [
    'الكرخ',
    'الرصافة',
    'الكاظمية',
    'الأعظمية',
    'المنصور',
    'الدورة',
    'الشعلة',
    'الحرية'
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableDrivers();
  }

  Future<void> _loadAvailableDrivers() async {
    setState(() => isLoading = true);

    try {
      List<Map<String, dynamic>> drivers =
          await DriverSelectionService.getAvailableDrivers(
        widget.orderData['serviceType'] ?? 'delivery',
        region: selectedRegion.isEmpty ? null : selectedRegion,
      );

      for (var driver in drivers) {
        Map<String, dynamic> stats =
            await DriverSelectionService.getDriverStats(driver['id']);
        driver.addAll(stats);
      }

      if (widget.orderData['customerLat'] != null &&
          widget.orderData['customerLon'] != null) {
        drivers = DriverSelectionService.sortDriversByPriority(
          drivers,
          widget.orderData['customerLat'],
          widget.orderData['customerLon'],
          maxDistance: maxDistance,
          serviceType: widget.orderData['serviceType'],
        );
      } else {
        drivers.sort((a, b) {
          String targetService = widget.orderData['serviceType'] ?? '';
          bool aMatchesService = a['serviceType'] == targetService;
          bool bMatchesService = b['serviceType'] == targetService;

          if (aMatchesService != bMatchesService) {
            return aMatchesService ? -1 : 1;
          }

          bool aActive = a['active'] == true && a['available'] == true;
          bool bActive = b['active'] == true && b['available'] == true;

          if (aActive != bActive) {
            return aActive ? -1 : 1;
          }

          double scoreA =
              (a['balance'] ?? 0) * 0.7 + (a['averageRating'] ?? 0) * 30;
          double scoreB =
              (b['balance'] ?? 0) * 0.7 + (b['averageRating'] ?? 0) * 30;
          return scoreB.compareTo(scoreA);
        });
      }

      setState(() {
        availableDrivers = drivers;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل السائقين: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاركة الطلب مع السائقين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableDrivers,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOrderSummary(),
          _buildFilters(),
          _buildDriversList(),
          _buildSelectedDrivers(),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل الطلب',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'العميل: ${widget.orderData['customerName'] ?? 'غير محدد'}'),
                      Text(
                          'الهاتف: ${widget.orderData['customerPhone'] ?? 'غير محدد'}'),
                      Text(
                          'نوع الخدمة: ${widget.orderData['serviceType'] ?? 'غير محدد'}'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'من: ${widget.orderData['fromLocation'] ?? 'غير محدد'}'),
                      Text(
                          'إلى: ${widget.orderData['toLocation'] ?? 'غير محدد'}'),
                      Text(
                          'المبلغ: ${widget.orderData['totalAmount'] ?? 0} د.ع',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedRegion.isEmpty ? null : selectedRegion,
                    decoration: const InputDecoration(
                      labelText: 'المنطقة',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('جميع المناطق')),
                      ...regions.map((region) =>
                          DropdownMenuItem(value: region, child: Text(region))),
                    ],
                    onChanged: (value) {
                      setState(() => selectedRegion = value ?? '');
                      _loadAvailableDrivers();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: maxDrivers.toString(),
                    decoration: const InputDecoration(
                      labelText: 'عدد السائقين',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() => maxDrivers = int.tryParse(value) ?? 5);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('المسافة القصوى: '),
                Expanded(
                  child: Slider(
                    value: maxDistance,
                    min: 1.0,
                    max: 50.0,
                    divisions: 49,
                    label: '${maxDistance.toInt()} كم',
                    onChanged: (value) {
                      setState(() => maxDistance = value);
                      _loadAvailableDrivers();
                    },
                  ),
                ),
                Text('${maxDistance.toInt()} كم'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriversList() {
    if (isLoading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (availableDrivers.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('لا يوجد سائقين متاحين حالياً'),
        ),
      );
    }

    return Expanded(
      flex: 2,
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'السائقين المتاحين (${availableDrivers.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: availableDrivers.length,
                itemBuilder: (context, index) {
                  final driver = availableDrivers[index];
                  final isSelected =
                      selectedDrivers.any((d) => d['id'] == driver['id']);

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: isSelected ? Colors.green.shade50 : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getDriverStatusColor(driver),
                        child: Text(
                          driver['name']?.substring(0, 1) ?? '؟',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(driver['name'] ?? 'غير محدد'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📞 ${driver['phone'] ?? 'غير محدد'}'),
                          Text(
                              '💰 الرصيد: ${driver['balance']?.toInt() ?? 0} د.ع'),
                          Row(
                            children: [
                              Icon(
                                driver['active'] == true &&
                                        driver['available'] == true
                                    ? Icons.circle
                                    : Icons.circle_outlined,
                                color: driver['active'] == true &&
                                        driver['available'] == true
                                    ? Colors.green
                                    : Colors.red,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                driver['active'] == true &&
                                        driver['available'] == true
                                    ? 'نشط ومتاح'
                                    : 'غير متاح',
                                style: TextStyle(
                                  color: driver['active'] == true &&
                                          driver['available'] == true
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                  '⭐ ${(driver['averageRating'] ?? 0).toStringAsFixed(1)}'),
                              const SizedBox(width: 16),
                              Text('📦 ${driver['completedOrders'] ?? 0} طلب'),
                              if (driver['distance'] != null)
                                Text(
                                    ' • 📍 ${driver['distance'].toStringAsFixed(1)} كم'),
                            ],
                          ),
                          if (driver['priorityScore'] != null)
                            Text(
                                '🎯 نقاط الأولوية: ${driver['priorityScore'].toInt()}',
                                style: TextStyle(color: Colors.blue.shade700)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (driver['priorityScore'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    _getPriorityColor(driver['priorityScore']),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getPriorityLabel(driver['priorityScore']),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true &&
                                    selectedDrivers.length < maxDrivers) {
                                  selectedDrivers.add(driver);
                                } else if (value == false) {
                                  selectedDrivers.removeWhere(
                                      (d) => d['id'] == driver['id']);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        if (selectedDrivers
                            .any((d) => d['id'] == driver['id'])) {
                          setState(() {
                            selectedDrivers
                                .removeWhere((d) => d['id'] == driver['id']);
                          });
                        } else if (selectedDrivers.length < maxDrivers) {
                          setState(() {
                            selectedDrivers.add(driver);
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDrivers() {
    if (selectedDrivers.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'السائقين المختارين (${selectedDrivers.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: selectedDrivers
                  .map((driver) => Chip(
                        label: Text(driver['name'] ?? 'غير محدد'),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () {
                          setState(() {
                            selectedDrivers
                                .removeWhere((d) => d['id'] == driver['id']);
                          });
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: selectedDrivers.isEmpty
                  ? null
                  : _selectTopDriversAutomatically,
              child: const Text('اختيار تلقائي'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed:
                  selectedDrivers.isEmpty ? null : _shareWithSelectedDrivers,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('مشاركة مع ${selectedDrivers.length} سائق'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDriverStatusColor(Map<String, dynamic> driver) {
    bool isActive = driver['active'] == true && driver['available'] == true;
    double balance = (driver['balance'] ?? 0).toDouble();
    double rating = driver['averageRating'] ?? 0;

    if (!isActive) return Colors.red;
    if (balance >= 50000 && rating >= 4.0) return Colors.green;
    if (balance >= 20000 && rating >= 3.0) return Colors.orange;
    return Colors.grey;
  }

  Color _getPriorityColor(double score) {
    if (score >= 150) return Colors.green;
    if (score >= 100) return Colors.orange;
    return Colors.red;
  }

  String _getPriorityLabel(double score) {
    if (score >= 150) return 'ممتاز';
    if (score >= 100) return 'جيد';
    return 'مقبول';
  }

  void _selectTopDriversAutomatically() {
    setState(() {
      selectedDrivers.clear();
      selectedDrivers.addAll(availableDrivers.take(maxDrivers).toList());
    });
  }

  Future<void> _shareWithSelectedDrivers() async {
    if (selectedDrivers.isEmpty) return;

    try {
      await DriverSelectionService.assignOrderToDrivers(
        widget.orderData,
        selectedDrivers,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ تم مشاركة الطلب مع ${selectedDrivers.length} سائق'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في مشاركة الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
