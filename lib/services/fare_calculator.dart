// lib/services/fare_calculator.dart
class FareCalculator {
  static int taxi(int meters, {bool specialRoute = false}) {
    if (specialRoute) {
      return 0; // handled outside for fixed routes like cities
    }
    int price = 2000; // ثابت
    final km = meters / 1000.0;
    double add = 0;

    if (km <= 0.5) {
      add = 0;
    } else if (km <= 2) {
      add = 500;
    } else if (km <= 3) {
      add = 1000;
    } else if (km <= 4) {
      add = 1500;
    } else if (km <= 5) {
      add = 2000;
    } else if (km <= 6) {
      add = 2500;
    } else if (km <= 7) {
      add = 3000;
    } else if (km <= 9) {
      add = 4000;
    } else if (km <= 15) {
      add = 6000;
    }

    return price + add.toInt();
  }

  static int tukTuk(int meters) {
    int price = 1000; // ثابت
    final km = meters / 1000.0;
    double add = 0;

    if (km <= 0.5) {
      add = 0;
    } else if (km <= 2) {
      add = 500;
    } else if (km <= 3) {
      add = 1000;
    } else if (km <= 4) {
      add = 1500;
    } else if (km <= 5) {
      add = 2000;
    } else if (km <= 6) {
      add = 2500;
    } else if (km <= 7) {
      add = 3000;
    } else if (km <= 9) {
      add = 4000;
    } else if (km <= 15) {
      add = 6000;
    }

    return price + add.toInt();
  }

  static int stuta(double km) {
    if (km <= 1) {
      return 5000;
    }
    if (km <= 5) {
      return 5000;
    }
    if (km <= 10) {
      return 8000;
    }
    if (km <= 15) {
      return 10000;
    }
    if (km <= 20) {
      return 12000;
    }
    if (km <= 25) {
      return 15000;
    }
    return 15000 + ((km - 25).ceil() * 500); // تقدير
  }

  static int kiaCargo(double km) {
    if (km <= 10) {
      return 5000;
    }
    if (km <= 15) {
      return 10000;
    }
    if (km <= 20) {
      return 15000;
    }
    if (km <= 30) {
      return 25000;
    }
    return 25000 + ((km - 30).ceil() * 1000); // تقدير
  }

  static int craftsmanBase(int workers) {
    if (workers == 0) {
      return 50000;
    }
    if (workers == 1) {
      return 75000;
    }
    if (workers >= 2) {
      return 100000;
    }
    return 50000;
  }
}

/// 🔹 كلاس منفصل لحساب أجور الركاب
class PassengerFareCalculator {
  /// حساب أجرة طلاب المدارس (شهريًا للفرد)
  static int schoolFare(double km) {
    if (km < 1) {
      return 0; // أقل من 1 كم -> غير محدد أو مجاني
    } else if (km <= 2) {
      return 10000;
    } else if (km <= 4) {
      return 15000;
    } else if (km <= 8) {
      return 25000; // خارج القضاء
    } else if (km <= 12) {
      return 30000;
    } else {
      return 0; // المسافة أكبر من 12 كم -> غير محدد
    }
  }

  /// حساب أجرة طلاب الجامعات (يوميًا للفرد)
  static int universityDailyFare(double km) {
    if (km >= 10 && km <= 15) {
      return 3000; // داخل المحافظة
    }
    if (km >= 16 && km <= 35) {
      return 5000;
    }
    if (km >= 36 && km <= 50) {
      return 6000; // خارج المحافظة
    }
    if (km >= 51 && km <= 70) {
      return 8000;
    }
    if (km >= 71 && km <= 100) {
      return 10000;
    }
    return 0; // غير محدد
  }

  /// حساب أجرة طلاب الجامعات (شهريًا = يومي × 30)
  static int universityMonthlyFare(double km) {
    return universityDailyFare(km) * 30;
  }
}
