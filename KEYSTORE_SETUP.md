# إعداد Keystore لتطبيق Android

## المشكلة
```
Failed to read key mesibawy from store: Tag number over 30 is not supported
```

هذا الخطأ يحدث عادة بسبب:
- ملف keystore تالف أو غير متوافق
- مشكلة في تشفير/فك تشفير base64
- إصدار قديم من keytool

## الحلول

### 1. إنشاء keystore جديد محلياً

```bash
# تشغيل السكريبت المرفق
chmod +x create_keystore.sh
./create_keystore.sh
```

### 2. رفع keystore إلى Codemagic

1. انسخ النص المُشفر بـ base64 من السكريبت
2. اذهب إلى إعدادات Codemagic
3. أضف متغير بيئة جديد:
   - الاسم: `KEYSTORE_BASE64`
   - القيمة: النص المُشفر

### 3. التحقق من المتغيرات

تأكد من وجود هذه المتغيرات في Codemagic:
- `KEYSTORE_BASE64`: ملف keystore مُشفر بـ base64
- `KEY_ALIAS`: mesibawy
- `KEY_PASSWORD`: mesibawy123
- `STORE_PASSWORD`: mesibawy123

### 4. إعادة تشغيل البناء

بعد تحديث keystore، قم بإعادة تشغيل workflow في Codemagic.

## ملاحظات مهمة

- احتفظ بنسخة احتياطية من keystore الأصلي
- لا تشارك كلمات المرور في الكود المصدري
- استخدم متغيرات البيئة دائماً للمعلومات الحساسة

## استكشاف الأخطاء

إذا استمر الخطأ:
1. تحقق من صحة base64 encoding
2. تأكد من أن keytool يمكنه قراءة keystore محلياً
3. جرب إنشاء keystore بإعدادات مختلفة
