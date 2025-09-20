// lib/features/support/support_center.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// مركز الدعم الفني والمساعدة
class SupportCenter extends StatefulWidget {
  final String userId;

  const SupportCenter({super.key, required this.userId});

  @override
  State<SupportCenter> createState() => _SupportCenterState();
}

class _SupportCenterState extends State<SupportCenter> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedCategory = 'عام';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'عام',
    'مشكلة تقنية',
    'مشكلة في الدفع',
    'شكوى على الخدمة',
    'اقتراح تحسين',
    'مشكلة في التطبيق',
  ];

  final List<Map<String, dynamic>> _faqItems = [
    {
      'question': 'كيف يمكنني طلب خدمة؟',
      'answer':
          'يمكنك طلب أي خدمة من الشاشة الرئيسية بالضغط على الأيقونة المناسبة وملء البيانات المطلوبة.',
    },
    {
      'question': 'كيف يتم الدفع؟',
      'answer':
          'يمكنك الدفع نقداً عند تلقي الخدمة أو من خلال المحفظة الإلكترونية في التطبيق.',
    },
    {
      'question': 'ماذا لو لم يصل مقدم الخدمة؟',
      'answer': 'يمكنك إلغاء الطلب من خلال التطبيق أو التواصل مع الدعم الفني.',
    },
    {
      'question': 'كيف يمكنني تقييم الخدمة؟',
      'answer': 'بعد انتهاء الخدمة، ستظهر لك شاشة التقييم لتقييم مقدم الخدمة.',
    },
    {
      'question': 'كيف يمكنني شحن المحفظة؟',
      'answer': 'يمكنك شحن المحفظة من خلال بطاقات الشحن أو التحويل البنكي.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الدعم'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: Colors.blue.shade600,
              child: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(icon: Icon(Icons.help), text: 'الأسئلة الشائعة'),
                  Tab(icon: Icon(Icons.chat), text: 'تواصل معنا'),
                  Tab(icon: Icon(Icons.phone), text: 'معلومات التواصل'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildFAQTab(),
                  _buildContactTab(),
                  _buildContactInfoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _faqItems.length,
      itemBuilder: (context, index) {
        final item = _faqItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              item['question'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  item['answer'],
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أرسل رسالة للدعم الفني',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // اختيار الفئة
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'فئة المشكلة',
              border: OutlineInputBorder(),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // نص الرسالة
          TextField(
            controller: _messageController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'اكتب رسالتك هنا',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          // زر الإرسال
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSupportRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('إرسال الرسالة'),
            ),
          ),

          const SizedBox(height: 20),

          // معلومات إضافية
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'معلومات مهمة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• سيتم الرد على رسالتك خلال 24 ساعة\n'
                  '• للمشاكل العاجلة، يرجى الاتصال المباشر\n'
                  '• تأكد من كتابة تفاصيل المشكلة بوضوح',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildContactCard(
            icon: Icons.phone,
            title: 'الهاتف',
            subtitle: '+964 770 123 4567',
            onTap: () => _makePhoneCall('+9647701234567'),
          ),
          _buildContactCard(
            icon: Icons.chat,
            title: 'واتساب',
            subtitle: '+964 770 123 4567',
            onTap: () => _openWhatsApp('+9647701234567'),
          ),
          _buildContactCard(
            icon: Icons.email,
            title: 'البريد الإلكتروني',
            subtitle: 'support@mesibawy.com',
            onTap: () => _sendEmail('support@mesibawy.com'),
          ),
          _buildContactCard(
            icon: Icons.facebook,
            title: 'فيسبوك',
            subtitle: 'Mesibawy Official',
            onTap: () => _openFacebook('mesibawy'),
          ),
          _buildContactCard(
            icon: Icons.schedule,
            title: 'ساعات العمل',
            subtitle: 'يومياً من 8 صباحاً إلى 10 مساءً',
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(icon, color: Colors.blue.shade600),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: onTap != null ? const Icon(Icons.arrow_forward_ios) : null,
        onTap: onTap,
      ),
    );
  }

  Future<void> _submitSupportRequest() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة رسالتك'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('support_requests').add({
        'userId': widget.userId,
        'category': _selectedCategory,
        'message': _messageController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رسالتك بنجاح. سيتم الرد عليك قريباً'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال الرسالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final Uri launchUri = Uri.parse('https://wa.me/$phoneNumber');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=استفسار من تطبيق مسيباوي',
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openFacebook(String username) async {
    final Uri launchUri = Uri.parse('https://facebook.com/$username');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
