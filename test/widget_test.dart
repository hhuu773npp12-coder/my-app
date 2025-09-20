// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesaybawi/main.dart';
import 'package:mesaybawi/features/splash/splash_screen.dart';
import 'package:mesaybawi/features/sorting/first_sort_screen.dart';

void main() {
  testWidgets('MesaybawiApp shows SplashScreen first',
      (WidgetTester tester) async {
    // بناء التطبيق بدون تجاوز الشاشة الافتراضية
    await tester.pumpWidget(const MesaybawiApp());

    // إعادة رسم الواجهة بعد Pump
    await tester.pump(); // بداية الرسم

    // تحقق من أن SplashScreen موجودة أولًا
    expect(find.byType(SplashScreen), findsOneWidget);

    // انتظار مدة السبلاش (3 ثواني) + إعادة رسم الواجهة
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // بعد السبلاش، يجب أن تظهر UserSortScreen أو أي واجهة فرز
    expect(find.byType(UserSortScreen), findsOneWidget);
  });
}
