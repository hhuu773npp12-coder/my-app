plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mssyb"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.mssyb"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

   signingConfigs {
    create("release") {
        // قراءة المتغيرات من Codemagic Secrets، أو استخدام القيم الافتراضية
        keyAlias = System.getenv("KEY_ALIAS") ?: "mesibawy"
        keyPassword = System.getenv("KEY_PASSWORD") ?: "كلمة_المرور_الجديدة_لـ_p12"
        storeFile = file("mesibawy-release-key.p12")
        storePassword = System.getenv("STORE_PASSWORD") ?: "كلمة_المرور_الجديدة_لـ_p12"
        
        // التأكد من وجود ملف keystore
        if (!storeFile!!.exists()) {
            logger.warn("⚠️ Keystore file not found: ${storeFile!!.absolutePath}")
        }
    }
}


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.10")
    implementation("com.google.firebase:firebase-analytics-ktx:21.3.0")
    implementation("com.google.firebase:firebase-auth-ktx:22.1.1")
    implementation("com.google.firebase:firebase-firestore-ktx:24.6.0")
    implementation("com.google.firebase:firebase-messaging-ktx:23.3.0")
    implementation("com.google.android.material:material:1.10.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
