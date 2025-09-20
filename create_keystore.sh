#!/bin/bash

# سكريبت لإنشاء keystore جديد متوافق مع Android
echo "🔑 إنشاء keystore جديد..."

# إنشاء مجلد android/app إذا لم يكن موجوداً
mkdir -p android/app

# حذف الـ keystore القديم إذا كان موجوداً
if [ -f "android/app/mesibawy-release-key.keystore" ]; then
    echo "🗑️ حذف keystore القديم..."
    rm android/app/mesibawy-release-key.keystore
fi

# إنشاء keystore جديد
echo "🔨 إنشاء keystore جديد..."
keytool -genkey -v \
    -keystore android/app/mesibawy-release-key.keystore \
    -alias mesibawy \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass mesibawy123 \
    -keypass mesibawy123 \
    -dname "CN=Mesibawy, OU=Development, O=Mesibawy, L=City, S=State, C=EG"

# التحقق من إنشاء الملف
if [ -f "android/app/mesibawy-release-key.keystore" ]; then
    echo "✅ تم إنشاء keystore بنجاح!"
    
    # عرض معلومات الـ keystore
    echo "📋 معلومات keystore:"
    keytool -list -v -keystore android/app/mesibawy-release-key.keystore -storepass mesibawy123
    
    # تحويل إلى base64 للاستخدام في Codemagic
    echo ""
    echo "🔄 تحويل keystore إلى base64 للاستخدام في Codemagic:"
    echo "قم بنسخ النص التالي وإضافته كمتغير KEYSTORE_BASE64 في Codemagic:"
    echo "----------------------------------------"
    base64 -i android/app/mesibawy-release-key.keystore
    echo "----------------------------------------"
    
else
    echo "❌ فشل في إنشاء keystore!"
    exit 1
fi
