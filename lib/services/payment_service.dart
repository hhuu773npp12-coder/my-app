// lib/services/payment_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

/// خدمة الدفع والمحفظة الإلكترونية
enum TransactionType {
  deposit,
  withdrawal,
  transfer,
  payment,
  refund,
  commission,
  chargeCode,
}

/// حالة المعاملة
enum TransactionStatus {
  pending, // معلقة
  completed, // مكتملة
  failed, // فاشلة
  cancelled, // ملغية
}

/// طرق الدفع
enum PaymentMethod {
  wallet,
  chargeCode,
  bankTransfer,
  cash,
  card,
}

class PaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// الحصول على رصيد المحفظة
  static Future<double> getWalletBalance(String userId) async {
    try {
      final doc = await _firestore.collection('wallets').doc(userId).get();
      if (doc.exists) {
        return (doc.data()?['balance'] ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e) {
      print('Error getting wallet balance: $e');
      return 0.0;
    }
  }

  /// إنشاء محفظة جديدة
  static Future<void> createWallet(String userId) async {
    try {
      await _firestore.collection('wallets').doc(userId).set({
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e) {
      print('Error creating wallet: $e');
    }
  }

  /// إضافة أموال للمحفظة
  static Future<bool> addFunds({
    required String userId,
    required double amount,
    required PaymentMethod method,
    String? reference,
    String? description,
  }) async {
    if (amount <= 0) return false;

    try {
      final batch = _firestore.batch();

      // تحديث رصيد المحفظة
      final walletRef = _firestore.collection('wallets').doc(userId);
      batch.update(walletRef, {
        'balance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // إضافة معاملة
      final transactionRef = _firestore.collection('transactions').doc();
      batch.set(transactionRef, {
        'id': transactionRef.id,
        'userId': userId,
        'type': TransactionType.deposit.name,
        'amount': amount,
        'method': method.name,
        'status': TransactionStatus.completed.name,
        'reference': reference,
        'description': description ?? 'إيداع في المحفظة',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('Error adding funds: $e');
      return false;
    }
  }

  /// خصم أموال من المحفظة
  static Future<bool> deductFunds({
    required String userId,
    required double amount,
    String? orderId,
    String? description,
  }) async {
    if (amount <= 0) return false;

    try {
      final walletRef = _firestore.collection('wallets').doc(userId);

      return await _firestore.runTransaction((transaction) async {
        final walletDoc = await transaction.get(walletRef);

        if (!walletDoc.exists) {
          throw Exception('المحفظة غير موجودة');
        }

        final currentBalance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();

        if (currentBalance < amount) {
          throw Exception('الرصيد غير كافي');
        }

        // تحديث رصيد المحفظة
        transaction.update(walletRef, {
          'balance': currentBalance - amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // إضافة معاملة
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'id': transactionRef.id,
          'userId': userId,
          'type': TransactionType.payment.name,
          'amount': -amount,
          'method': PaymentMethod.wallet.name,
          'status': TransactionStatus.completed.name,
          'orderId': orderId,
          'description': description ?? 'دفع من المحفظة',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Error deducting funds: $e');
      return false;
    }
  }

  /// تحويل أموال بين المحافظ
  static Future<bool> transferFunds({
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? description,
  }) async {
    if (amount <= 0) return false;

    try {
      return await _firestore.runTransaction((transaction) async {
        final fromWalletRef = _firestore.collection('wallets').doc(fromUserId);
        final toWalletRef = _firestore.collection('wallets').doc(toUserId);

        final fromWalletDoc = await transaction.get(fromWalletRef);
        final toWalletDoc = await transaction.get(toWalletRef);

        if (!fromWalletDoc.exists || !toWalletDoc.exists) {
          throw Exception('إحدى المحافظ غير موجودة');
        }

        final fromBalance =
            (fromWalletDoc.data()?['balance'] ?? 0.0).toDouble();

        if (fromBalance < amount) {
          throw Exception('الرصيد غير كافي');
        }

        // خصم من المرسل
        transaction.update(fromWalletRef, {
          'balance': fromBalance - amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // إضافة للمستقبل
        final toBalance = (toWalletDoc.data()?['balance'] ?? 0.0).toDouble();
        transaction.update(toWalletRef, {
          'balance': toBalance + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // معاملة المرسل
        final fromTransactionRef = _firestore.collection('transactions').doc();
        transaction.set(fromTransactionRef, {
          'id': fromTransactionRef.id,
          'userId': fromUserId,
          'type': TransactionType.withdrawal.name,
          'amount': -amount,
          'method': PaymentMethod.wallet.name,
          'status': TransactionStatus.completed.name,
          'toUserId': toUserId,
          'description': description ?? 'تحويل إلى مستخدم آخر',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // معاملة المستقبل
        final toTransactionRef = _firestore.collection('transactions').doc();
        transaction.set(toTransactionRef, {
          'id': toTransactionRef.id,
          'userId': toUserId,
          'type': TransactionType.deposit.name,
          'amount': amount,
          'method': PaymentMethod.wallet.name,
          'status': TransactionStatus.completed.name,
          'fromUserId': fromUserId,
          'description': description ?? 'تحويل من مستخدم آخر',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Error transferring funds: $e');
      return false;
    }
  }

  /// الحصول على تاريخ المعاملات
  static Stream<QuerySnapshot> getTransactionHistory(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// إنشاء طلب دفع
  static Future<String?> createPaymentRequest({
    required String userId,
    required double amount,
    required String orderId,
    required PaymentMethod method,
    String? description,
  }) async {
    try {
      final paymentRef = _firestore.collection('payment_requests').doc();

      await paymentRef.set({
        'id': paymentRef.id,
        'userId': userId,
        'orderId': orderId,
        'amount': amount,
        'method': method.name,
        'status': TransactionStatus.pending.name,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 30)),
        ),
      });

      return paymentRef.id;
    } catch (e) {
      print('Error creating payment request: $e');
      return null;
    }
  }

  /// معالجة الدفع
  static Future<bool> processPayment({
    required String paymentRequestId,
    required PaymentMethod method,
    String? reference,
  }) async {
    try {
      final paymentRef =
          _firestore.collection('payment_requests').doc(paymentRequestId);

      return await _firestore.runTransaction((transaction) async {
        final paymentDoc = await transaction.get(paymentRef);

        if (!paymentDoc.exists) {
          throw Exception('طلب الدفع غير موجود');
        }

        final data = paymentDoc.data()!;
        final status = data['status'];

        if (status != TransactionStatus.pending.name) {
          throw Exception('طلب الدفع تم معالجته مسبقاً');
        }

        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        if (DateTime.now().isAfter(expiresAt)) {
          throw Exception('طلب الدفع منتهي الصلاحية');
        }

        // تحديث حالة طلب الدفع
        transaction.update(paymentRef, {
          'status': TransactionStatus.completed.name,
          'method': method.name,
          'reference': reference,
          'processedAt': FieldValue.serverTimestamp(),
        });

        // إضافة معاملة
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'id': transactionRef.id,
          'userId': data['userId'],
          'type': TransactionType.payment.name,
          'amount': -data['amount'],
          'method': method.name,
          'status': TransactionStatus.completed.name,
          'orderId': data['orderId'],
          'paymentRequestId': paymentRequestId,
          'reference': reference,
          'description': data['description'],
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Error processing payment: $e');
      return false;
    }
  }

  /// إنشاء رمز شحن
  static String generateChargeCode() {
    final random = Random();
    final code = List.generate(12, (index) {
      if (index % 4 == 3 && index != 11) return '-';
      return random.nextInt(10).toString();
    }).join();
    return code;
  }

  /// التحقق من رمز الشحن
  static Future<Map<String, dynamic>?> validateChargeCode(String code) async {
    try {
      final querySnapshot = await _firestore
          .collection('charge_codes')
          .where('code', isEqualTo: code)
          .where('used', isEqualTo: false)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return querySnapshot.docs.first.data();
    } catch (e) {
      print('Error validating charge code: $e');
      return null;
    }
  }

  /// استخدام رمز الشحن
  static Future<bool> useChargeCode({
    required String userId,
    required String code,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final querySnapshot = await _firestore
            .collection('charge_codes')
            .where('code', isEqualTo: code)
            .where('used', isEqualTo: false)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw Exception('رمز الشحن غير صحيح أو مستخدم');
        }

        final codeDoc = querySnapshot.docs.first;
        final codeData = codeDoc.data();
        final amount = (codeData['amount'] ?? 0.0).toDouble();

        // تحديد الرمز كمستخدم
        transaction.update(codeDoc.reference, {
          'used': true,
          'usedBy': userId,
          'usedAt': FieldValue.serverTimestamp(),
        });

        // إضافة المبلغ للمحفظة
        final walletRef = _firestore.collection('wallets').doc(userId);
        transaction.update(walletRef, {
          'balance': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // إضافة معاملة
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'id': transactionRef.id,
          'userId': userId,
          'type': TransactionType.deposit.name,
          'amount': amount,
          'method': PaymentMethod.card.name,
          'status': TransactionStatus.completed.name,
          'chargeCode': code,
          'description': 'شحن المحفظة برمز الشحن',
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Error using charge code: $e');
      return false;
    }
  }

  /// حساب العمولة
  static double calculateCommission(double amount, double rate) {
    return amount * (rate / 100);
  }

  /// إضافة عمولة لمقدم الخدمة
  static Future<bool> addCommission({
    required String providerId,
    required double amount,
    required String orderId,
    double commissionRate = 90.0, // 90% للمقدم، 10% للتطبيق
  }) async {
    try {
      final providerAmount = amount * (commissionRate / 100);
      final appAmount = amount - providerAmount;

      final batch = _firestore.batch();

      // إضافة العمولة لمقدم الخدمة
      final providerWalletRef =
          _firestore.collection('wallets').doc(providerId);
      batch.update(providerWalletRef, {
        'balance': FieldValue.increment(providerAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // معاملة مقدم الخدمة
      final providerTransactionRef =
          _firestore.collection('transactions').doc();
      batch.set(providerTransactionRef, {
        'id': providerTransactionRef.id,
        'userId': providerId,
        'type': TransactionType.commission.name,
        'amount': providerAmount,
        'method': PaymentMethod.wallet.name,
        'status': TransactionStatus.completed.name,
        'orderId': orderId,
        'description': 'عمولة تنفيذ الخدمة',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // معاملة التطبيق
      final appTransactionRef = _firestore.collection('transactions').doc();
      batch.set(appTransactionRef, {
        'id': appTransactionRef.id,
        'userId': 'app',
        'type': TransactionType.commission.name,
        'amount': appAmount,
        'method': PaymentMethod.wallet.name,
        'status': TransactionStatus.completed.name,
        'orderId': orderId,
        'description': 'عمولة التطبيق',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error adding commission: $e');
      return false;
    }
  }
}
