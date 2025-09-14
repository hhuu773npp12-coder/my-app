import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/craftsman_selection_service.dart';

class CraftsmanOrderSharingScreen extends StatefulWidget {
  final Map<String, dynamic> jobData;
  final String adminId;
  
  const CraftsmanOrderSharingScreen({
    super.key,
    required this.jobData,
    required this.adminId,
  });

  @override
  State<CraftsmanOrderSharingScreen> createState() => _CraftsmanOrderSharingScreenState();
}

class _CraftsmanOrderSharingScreenState extends State<CraftsmanOrderSharingScreen> {
  List<Map<String, dynamic>> availableCraftsmen = [];
  List<Map<String, dynamic>> selectedCraftsmen = [];
  bool isLoading = true;
  String selectedRegion = '';
  String selectedSpecialty = '';
  double maxDistance = 15.0;
  double minRating = 0.0;
  int maxCraftsmen = 3;
  bool requiresTools = false;
  bool requiresTransport = false;
  String priceRange = '';
  
  final List<String> regions = [
    'الكرخ', 'الرصافة', 'الكاظمية', 'الأعظمية', 
    'المنصور', 'الدورة', 'الشعلة', 'الحرية'
  ];
  
  final List<String> priceRanges = ['اقتصادي', 'متوسط', 'مرتفع'];

  @override
  void initState() {
    super.initState();
    _loadAvailableCraftsmen();
  }

  Future<void> _loadAvailableCraftsmen() async {
    setState(() => isLoading = true);
    
    try {
      List<Map<String, dynamic>> craftsmen = await CraftsmanSelectionService
          .searchCraftsmenWithFilters(
            craftType: widget.jobData['serviceType'] ?? 'electrician',
            region: selectedRegion.isEmpty ? null : selectedRegion,
            specialty: selectedSpecialty.isEmpty ? null : selectedSpecialty,
            minRating: minRating > 0 ? minRating : null,
            maxDistance: maxDistance.toInt(),
            hasTools: requiresTools ? true : null,
            hasTransport: requiresTransport ? true : null,
            priceRange: priceRange.isEmpty ? null : priceRange,
          );
      
      // إضافة إحصائيات لكل حرفي
      for (var craftsman in craftsmen) {
        Map<String, dynamic> stats = await CraftsmanSelectionService
            .getCraftsmanStats(craftsman['id']);
        craftsman.addAll(stats);
      }
      
      // ترتيب أصحاب الحرف حسب الأولوية
      if (widget.jobData['customerLat'] != null && 
          widget.jobData['customerLon'] != null) {
        craftsmen = CraftsmanSelectionService.sortCraftsmenByPriority(
          craftsmen,
          widget.jobData['customerLat'],
          widget.jobData['customerLon'],
          maxDistance: maxDistance,
        );
      } else {
        // ترتيب بديل حسب الرصيد والتقييم
        craftsmen.sort((a, b) {
          double scoreA = (a['balance'] ?? 0) * 0.4 + 
                         (a['averageRating'] ?? 0) * 30 + 
                         (a['completedJobs'] ?? 0) * 2;
          double scoreB = (b['balance'] ?? 0) * 0.4 + 
                         (b['averageRating'] ?? 0) * 30 + 
                         (b['completedJobs'] ?? 0) * 2;
          return scoreB.compareTo(scoreA);
        });
      }
      
      setState(() {
        availableCraftsmen = craftsmen;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل أصحاب الحرف: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مشاركة العمل - ${CraftsmanSelectionService.craftTypes[widget.jobData['serviceType']] ?? 'حرفي'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableCraftsmen,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildJobSummary(),
          _buildFilters(),
          _buildCraftsmenList(),
          _buildSelectedCraftsmen(),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  Widget _buildJobSummary() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل العمل',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('العميل: ${widget.jobData['customerName'] ?? 'غير محدد'}'),
                      Text('الهاتف: ${widget.jobData['customerPhone'] ?? 'غير محدد'}'),
                      Text('نوع العمل: ${CraftsmanSelectionService.craftTypes[widget.jobData['serviceType']] ?? 'غير محدد'}'),
                      Text('الوصف: ${widget.jobData['jobDescription'] ?? 'غير محدد'}'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('العنوان: ${widget.jobData['customerAddress'] ?? 'غير محدد'}'),
                      Text('الأولوية: ${widget.jobData['urgencyLevel'] ?? 'عادي'}'),
                      Text('المدة المتوقعة: ${widget.jobData['estimatedDuration'] ?? 'غير محدد'}'),
                      Text('الميزانية: ${widget.jobData['budgetRange'] ?? 'غير محدد'} د.ع',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
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
    List<String> specialties = CraftsmanSelectionService
        .getSpecialtiesByType(widget.jobData['serviceType'] ?? 'electrician');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ExpansionTile(
        title: const Text('فلاتر البحث'),
        children: [
          Padding(
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
                          const DropdownMenuItem(value: '', child: Text('جميع المناطق')),
                          ...regions.map((region) => 
                            DropdownMenuItem(value: region, child: Text(region))),
                        ],
                        onChanged: (value) {
                          setState(() => selectedRegion = value ?? '');
                          _loadAvailableCraftsmen();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedSpecialty.isEmpty ? null : selectedSpecialty,
                        decoration: const InputDecoration(
                          labelText: 'التخصص',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('جميع التخصصات')),
                          ...specialties.map((specialty) => 
                            DropdownMenuItem(value: specialty, child: Text(specialty))),
                        ],
                        onChanged: (value) {
                          setState(() => selectedSpecialty = value ?? '');
                          _loadAvailableCraftsmen();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: priceRange.isEmpty ? null : priceRange,
                        decoration: const InputDecoration(
                          labelText: 'نطاق السعر',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('جميع الأسعار')),
                          ...priceRanges.map((range) => 
                            DropdownMenuItem(value: range, child: Text(range))),
                        ],
                        onChanged: (value) {
                          setState(() => priceRange = value ?? '');
                          _loadAvailableCraftsmen();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: maxCraftsmen.toString(),
                        decoration: const InputDecoration(
                          labelText: 'عدد الحرفيين',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() => maxCraftsmen = int.tryParse(value) ?? 3);
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
                          _loadAvailableCraftsmen();
                        },
                      ),
                    ),
                    Text('${maxDistance.toInt()} كم'),
                  ],
                ),
                Row(
                  children: [
                    const Text('التقييم الأدنى: '),
                    Expanded(
                      child: Slider(
                        value: minRating,
                        min: 0.0,
                        max: 5.0,
                        divisions: 10,
                        label: minRating.toStringAsFixed(1),
                        onChanged: (value) {
                          setState(() => minRating = value);
                          _loadAvailableCraftsmen();
                        },
                      ),
                    ),
                    Text(minRating.toStringAsFixed(1)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('يملك أدوات'),
                        value: requiresTools,
                        onChanged: (value) {
                          setState(() => requiresTools = value ?? false);
                          _loadAvailableCraftsmen();
                        },
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('يملك نقل'),
                        value: requiresTransport,
                        onChanged: (value) {
                          setState(() => requiresTransport = value ?? false);
                          _loadAvailableCraftsmen();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCraftsmenList() {
    if (isLoading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (availableCraftsmen.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text('لا يوجد حرفيين متاحين حالياً'),
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
                'الحرفيين المتاحين (${availableCraftsmen.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: availableCraftsmen.length,
                itemBuilder: (context, index) {
                  final craftsman = availableCraftsmen[index];
                  final isSelected = selectedCraftsmen.any((c) => c['id'] == craftsman['id']);
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: isSelected ? Colors.blue.shade50 : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getCraftsmanStatusColor(craftsman),
                        child: Text(
                          craftsman['name']?.substring(0, 1) ?? '؟',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(craftsman['name'] ?? 'غير محدد'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📞 ${craftsman['phone'] ?? 'غير محدد'}'),
                          Text('🔧 ${craftsman['specialty'] ?? 'عام'}'),
                          Text('💰 الرصيد: ${craftsman['balance']?.toInt() ?? 0} د.ع'),
                          Row(
                            children: [
                              Text('⭐ ${(craftsman['averageRating'] ?? 0).toStringAsFixed(1)}'),
                              const SizedBox(width: 16),
                              Text('🔨 ${craftsman['completedJobs'] ?? 0} عمل'),
                              if (craftsman['distance'] != null)
                                Text(' • 📍 ${craftsman['distance'].toStringAsFixed(1)} كم'),
                            ],
                          ),
                          Row(
                            children: [
                              if (craftsman['hasTools'] == true)
                                const Icon(Icons.build, size: 16, color: Colors.green),
                              if (craftsman['hasTransport'] == true)
                                const Icon(Icons.directions_car, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text('💵 ${craftsman['monthlyEarnings']?.toInt() ?? 0} د.ع/شهر'),
                            ],
                          ),
                          if (craftsman['priorityScore'] != null)
                            Text('🎯 نقاط الأولوية: ${craftsman['priorityScore'].toInt()}',
                                style: TextStyle(color: Colors.blue.shade700)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (craftsman['priorityScore'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(craftsman['priorityScore']),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getPriorityLabel(craftsman['priorityScore']),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true && selectedCraftsmen.length < maxCraftsmen) {
                                  selectedCraftsmen.add(craftsman);
                                } else if (value == false) {
                                  selectedCraftsmen.removeWhere((c) => c['id'] == craftsman['id']);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        if (selectedCraftsmen.any((c) => c['id'] == craftsman['id'])) {
                          setState(() {
                            selectedCraftsmen.removeWhere((c) => c['id'] == craftsman['id']);
                          });
                        } else if (selectedCraftsmen.length < maxCraftsmen) {
                          setState(() {
                            selectedCraftsmen.add(craftsman);
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

  Widget _buildSelectedCraftsmen() {
    if (selectedCraftsmen.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الحرفيين المختارين (${selectedCraftsmen.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: selectedCraftsmen.map((craftsman) => Chip(
                label: Text(craftsman['name'] ?? 'غير محدد'),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () {
                  setState(() {
                    selectedCraftsmen.removeWhere((c) => c['id'] == craftsman['id']);
                  });
                },
              )).toList(),
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
              onPressed: selectedCraftsmen.isEmpty ? null : _selectTopCraftsmenAutomatically,
              child: const Text('اختيار تلقائي'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: selectedCraftsmen.isEmpty ? null : _shareWithSelectedCraftsmen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('مشاركة مع ${selectedCraftsmen.length} حرفي'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCraftsmanStatusColor(Map<String, dynamic> craftsman) {
    double balance = (craftsman['balance'] ?? 0).toDouble();
    double rating = craftsman['averageRating'] ?? 0;
    
    if (balance >= 30000 && rating >= 4.0) return Colors.green;
    if (balance >= 15000 && rating >= 3.0) return Colors.orange;
    return Colors.red;
  }

  Color _getPriorityColor(double score) {
    if (score >= 180) return Colors.green;
    if (score >= 120) return Colors.orange;
    return Colors.red;
  }

  String _getPriorityLabel(double score) {
    if (score >= 180) return 'ممتاز';
    if (score >= 120) return 'جيد';
    return 'مقبول';
  }

  void _selectTopCraftsmenAutomatically() {
    setState(() {
      selectedCraftsmen.clear();
      selectedCraftsmen.addAll(
        availableCraftsmen.take(maxCraftsmen).toList()
      );
    });
  }

  Future<void> _shareWithSelectedCraftsmen() async {
    if (selectedCraftsmen.isEmpty) return;

    try {
      await CraftsmanSelectionService.assignJobToCraftsmen(
        widget.jobData,
        selectedCraftsmen,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم مشاركة العمل مع ${selectedCraftsmen.length} حرفي'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في مشاركة العمل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
