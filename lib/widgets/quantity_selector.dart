import 'package:flutter/material.dart';

class QuantitySelector extends StatefulWidget {
  final int initialQuantity;
  final int minQuantity;
  final int maxQuantity;
  final double basePrice;
  final Function(int quantity, double totalPrice) onQuantityChanged;
  final String itemName;
  final List<ServiceFee>? additionalServices;

  const QuantitySelector({
    super.key,
    this.initialQuantity = 1,
    this.minQuantity = 1,
    this.maxQuantity = 99,
    required this.basePrice,
    required this.onQuantityChanged,
    required this.itemName,
    this.additionalServices,
  });

  @override
  State<QuantitySelector> createState() => _QuantitySelectorState();
}

class _QuantitySelectorState extends State<QuantitySelector> {
  late int _quantity;
  late double _totalPrice;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
    _calculateTotalPrice();
  }

  void _calculateTotalPrice() {
    // حساب السعر الأساسي مضروب في الكمية
    double itemsPrice = widget.basePrice * _quantity;
    
    // إضافة الخدمات الإضافية
    double servicesPrice = 0;
    if (widget.additionalServices != null) {
      for (var service in widget.additionalServices!) {
        if (service.isPercentage) {
          servicesPrice += itemsPrice * (service.amount / 100);
        } else {
          servicesPrice += service.amount;
        }
      }
    }
    
    _totalPrice = itemsPrice + servicesPrice;
    widget.onQuantityChanged(_quantity, _totalPrice);
  }

  void _incrementQuantity() {
    if (_quantity < widget.maxQuantity) {
      setState(() {
        _quantity++;
        _calculateTotalPrice();
      });
    }
  }

  void _decrementQuantity() {
    if (_quantity > widget.minQuantity) {
      setState(() {
        _quantity--;
        _calculateTotalPrice();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم المنتج
            Text(
              widget.itemName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // السعر الأساسي
            Text(
              'السعر الأساسي: ${widget.basePrice.toStringAsFixed(0)} د.ع',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            
            // محدد الكمية
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الكمية:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    // زر النقص
                    Container(
                      decoration: BoxDecoration(
                        color: _quantity > widget.minQuantity 
                            ? Colors.red.shade100 
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: _quantity > widget.minQuantity 
                            ? _decrementQuantity 
                            : null,
                        icon: Icon(
                          Icons.remove,
                          color: _quantity > widget.minQuantity 
                              ? Colors.red 
                              : Colors.grey,
                        ),
                      ),
                    ),
                    
                    // عرض الكمية
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20, 
                        vertical: 12
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    
                    // زر الزيادة
                    Container(
                      decoration: BoxDecoration(
                        color: _quantity < widget.maxQuantity 
                            ? Colors.green.shade100 
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: _quantity < widget.maxQuantity 
                            ? _incrementQuantity 
                            : null,
                        icon: Icon(
                          Icons.add,
                          color: _quantity < widget.maxQuantity 
                              ? Colors.green 
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // تفاصيل السعر
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // سعر المنتجات
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('سعر المنتجات ($_quantity × ${widget.basePrice.toStringAsFixed(0)}):'),
                      Text(
                        '${(widget.basePrice * _quantity).toStringAsFixed(0)} د.ع',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  
                  // الخدمات الإضافية
                  if (widget.additionalServices != null && widget.additionalServices!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const Text(
                      'الخدمات الإضافية:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    ...widget.additionalServices!.map((service) {
                      double serviceAmount = service.isPercentage
                          ? (widget.basePrice * _quantity) * (service.amount / 100)
                          : service.amount;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${service.name} ${service.isPercentage ? "(${service.amount}%)" : ""}:',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${serviceAmount.toStringAsFixed(0)} د.ع',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                  
                  const SizedBox(height: 8),
                  const Divider(thickness: 2),
                  
                  // السعر الإجمالي
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'السعر الإجمالي:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_totalPrice.toStringAsFixed(0)} د.ع',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// فئة لتمثيل الخدمات الإضافية
class ServiceFee {
  final String name;
  final double amount;
  final bool isPercentage;

  const ServiceFee({
    required this.name,
    required this.amount,
    this.isPercentage = false,
  });
}
