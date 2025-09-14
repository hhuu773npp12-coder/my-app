import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/payment_service.dart';
import '../../utils/ui_improvements.dart';

class WalletPage extends StatefulWidget {
  final String userId; // ربط المحفظة بالمستخدم الموحد
  const WalletPage({super.key, required this.userId});

  @override
  WalletPageState createState() => WalletPageState();
}

class WalletPageState extends State<WalletPage> {
  final TextEditingController cardController = TextEditingController();
  bool isLoading = false;
  double currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await PaymentService.getWalletBalance(widget.userId);
    if (mounted) {
      setState(() {
        currentBalance = balance;
      });
    }
  }

  // شحن المحفظة برمز الشحن
  Future<void> _chargeWithCode() async {
    final code = cardController.text.trim();
    if (code.isEmpty) {
      UIImprovements.showErrorSnackBar(context, 'يرجى إدخال رمز الشحن');
      return;
    }

    setState(() => isLoading = true);

    try {
      final success = await PaymentService.useChargeCode(
        userId: widget.userId,
        code: code,
      );

      if (success) {
        UIImprovements.showSuccessSnackBar(context, 'تم شحن المحفظة بنجاح');
        cardController.clear();
        _loadBalance();
      } else {
        UIImprovements.showErrorSnackBar(context, 'رمز الشحن غير صحيح أو مستخدم');
      }
    } catch (e) {
      UIImprovements.showErrorSnackBar(context, 'خطأ في شحن المحفظة: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شحن المحفظة'),
        backgroundColor: UIImprovements.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة الرصيد
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [UIImprovements.primaryColor, UIImprovements.primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: UIImprovements.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الرصيد الحالي',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currentBalance.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // قسم شحن المحفظة
            const Text(
              'شحن المحفظة برمز الشحن',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: cardController,
              decoration: InputDecoration(
                labelText: 'رمز الشحن',
                hintText: 'أدخل رمز الشحن هنا',
                prefixIcon: const Icon(Icons.confirmation_number),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: UIImprovements.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: isLoading ? null : _chargeWithCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: UIImprovements.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'شحن المحفظة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            
            const SizedBox(height: 30),
            
            // معلومات مهمة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'معلومات مهمة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• يمكنك الحصول على رموز الشحن من المتاجر المعتمدة\n'
                    '• كل رمز شحن يستخدم مرة واحدة فقط\n'
                    '• يتم إضافة المبلغ فوراً بعد التأكد من صحة الرمز\n'
                    '• تأكد من إدخال الرمز بشكل صحيح',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    cardController.dispose();
    super.dispose();
  }
}
