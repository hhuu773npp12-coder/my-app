import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// استدعاء كل الشاشات
import 'features/restaurant/restaurant_dashboard.dart';
import 'features/cooling/cooling_home_screen.dart';
import 'features/blacksmith/blacksmith_home_screen.dart';
import 'features/stuta/stuta_home_screen.dart';
import 'features/admin/admin_dashboard.dart';
import 'owner_home_page.dart';
import 'features/citizen/citizen_home_screen.dart';
import 'features/taxi/taxi_home_screen.dart';
import 'tuktuk_home_screen.dart';
import 'features/kia/kia_home_screen.dart';
import 'kia_passenger_home_screen.dart';
import 'features/electrician/electrician_home_screen.dart';
import 'features/plumber/plumber_home_screen.dart';
import 'features/delivery_bike/driver_home_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/sorting/first_sort_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MesaybawiApp());
}

class MesaybawiApp extends StatelessWidget {
  const MesaybawiApp({super.key});

  /// هذه الدالة تحدد الواجهة الأولى
  Future<Widget> _getInitialScreen() async {
    try {
      // عرض Splash لمدة 3 ثواني
      await Future.delayed(const Duration(seconds: 3));

      final prefs = await SharedPreferences.getInstance();

      // أول تشغيل → اعرض شاشة الفرز
      final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
      if (isFirstLaunch) {
        await prefs.setBool('isFirstLaunch', false);
        return const UserSortScreen();
      }

      // فحص تسجيل الدخول لكل المستخدمين
      final userPrefs = {
        'isAdminLoggedIn': 'adminId',
        'isOwnerLoggedIn': 'ownerId',
        'isCitizenLoggedIn': 'userPhone',
        'isTaxiLoggedIn': 'driverId',
        'isTuktukLoggedIn': 'driverId',
        'isStutaLoggedIn': 'stutaDriverKey',
        'isKiaLoggedIn': 'kiaOwnerId',
        'isKiaPassengerLoggedIn': 'kiaPassengerId',
        'isElectricianLoggedIn': 'electricianId',
        'isPlumberLoggedIn': 'plumberId',
        'isCoolingLoggedIn': 'coolingId',
        'isBlacksmithLoggedIn': 'blacksmithId',
        'isRestaurantOwnerLoggedIn': 'restaurantOwnerId',
        'isDriverLoggedIn': 'driverId',
      };

      for (var entry in userPrefs.entries) {
        final isLoggedIn = prefs.getBool(entry.key) ?? false;
        final userId = prefs.getString(entry.value) ?? '';
        if (isLoggedIn && userId.isNotEmpty) {
          switch (entry.key) {
            case 'isAdminLoggedIn':
              return AdminHomePage(adminId: userId);
            case 'isOwnerLoggedIn':
              return OwnerHomePage(ownerId: userId);
            case 'isCitizenLoggedIn':
              return CitizenHomeScreen(citizenId: userId);
            case 'isTaxiLoggedIn':
              return TaxiHomeScreen(userId: userId);
            case 'isTuktukLoggedIn':
              return TuktukHomeScreen(userId: userId);
            case 'isStutaLoggedIn':
              return StutaHomeScreen(userId: userId);
            case 'isKiaLoggedIn':
              return KiaHomeScreen(userId: userId);
            case 'isKiaPassengerLoggedIn':
              return KiaPassengerMain(userId: userId);
            case 'isElectricianLoggedIn':
              return ElectricianHomeScreen(userId: userId);
            case 'isPlumberLoggedIn':
              return PlumberHomeScreen(userId: userId);
            case 'isCoolingLoggedIn':
              return CoolingHomeScreen(userId: userId);
            case 'isBlacksmithLoggedIn':
              return BlacksmithHomeScreen(userId: userId);
            case 'isRestaurantOwnerLoggedIn':
              return RestaurantOwnerApp(restaurantId: userId);
            case 'isDriverLoggedIn':
              return DriverHomeScreen(userId: userId);
          }
        }
      }

      // إذا لم يكن هناك تسجيل دخول → اعرض واجهة الفرز
      return const UserSortScreen();
    } catch (e, st) {
      debugPrint("❌ خطأ عند تحديد الشاشة: $e\n$st");
      return const UserSortScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'مسيباوي',
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
          home: FutureBuilder<Widget>(
            future: _getInitialScreen(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                // طول ما الـ Future ما خلص → اعرض Splash
                return const SplashScreen();
              }
              // لما يجهز → اعرض الشاشة المحددة
              return snapshot.data!;
            },
          ),
        );
      },
    );
  }
}
