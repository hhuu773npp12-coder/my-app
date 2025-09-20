import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sorting/first_sort_screen.dart';

class WaitingApprovalScreen extends StatelessWidget {
  final String userId;
  final String userType;
  final String collection;
  
  const WaitingApprovalScreen({
    super.key,
    required this.userId,
    required this.userType,
    required this.collection,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('في انتظار الموافقة'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(collection)
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final isApproved = data?['isApproved'] ?? false;

          if (isApproved) {
            // إذا تمت الموافقة، انتقل لشاشة تسجيل الدخول
            Future.microtask(() {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const UserSortScreen()),
              );
            });
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // أيقونة الانتظار
                const Icon(
                  Icons.hourglass_top,
                  size: 100,
                  color: Colors.orange,
                ),
                
                const SizedBox(height: 30),
                
                const Text(
                  'طلبك قيد المراجعة',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  'تم إرسال طلب التسجيل الخاص بك كـ $userType إلى المشرفين',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 30),
                        SizedBox(height: 10),
                        Text(
                          'معلومات مهمة:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '• سيتم مراجعة طلبك من قبل المشرفين\n'
                          '• قد يستغرق الأمر بعض الوقت\n'
                          '• سيتم الاتصال بك عند الموافقة\n'
                          '• لا تغلق التطبيق، ستحصل على إشعار',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // زر العودة للفرز
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const UserSortScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('العودة للفرز'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // معلومات الحالة
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pending, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'الحالة: في انتظار الموافقة',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
