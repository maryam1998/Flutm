plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// شماره‌ی نسخه از VERSION_CODE (ورک‌فلو: شماره‌ی اجرا)؛ اگه نبود، از pubspec
val envVersionCode: Int? = System.getenv("VERSION_CODE")?.toIntOrNull()
// ✅ versionCode همیشه صعودی (دقیقه از 1970) تا آپدیت روی نسخه‌ی نصب‌شده هیچ‌وقت به‌خاطر «versionCode پایین‌تر» رد نشود.
//    (قبلاً فقط شماره‌ی اجرای ورک‌فلو بود؛ اگر ریپو/ورک‌فلو عوض می‌شد شماره کوچک‌تر می‌شد و نصبِ آپدیت شکست می‌خورد.)
val timeVersionCode: Int = (System.currentTimeMillis() / 60000L).toInt()
val appVersionCode: Int = maxOf(envVersionCode ?: 0, timeVersionCode)

android {
    namespace = "com.linglearn.app"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.linglearn.app"
        minSdk = 29
        targetSdk = 36
        versionCode = appVersionCode
        versionName = "1.0.$appVersionCode"

        // معماری‌ها: دستیِ abiFilters نداریم؛ از روشِ استانداردِ Flutter استفاده می‌شه:
        //   flutter build ... --target-platform android-arm64   (ورک‌فلو: build-apk.yml)
    }

    // فقط یک نسخه: store (گوگل‌پلی / کافه‌بازار / مایکت)
    flavorDimensions += "dist"
    productFlavors {
        create("store") { dimension = "dist" }
    }

    // امضا با کلید اختصاصی؛ اگه فایل کلید نبود (بیلد لوکال) با debug امضا می‌شه
    val keystoreFile = file("release-key.jks")
    signingConfigs {
        if (keystoreFile.exists()) {
            create("release") {
                storeFile = keystoreFile
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // ✅ در CI اگر کلید نبود، بیلد شکست بخورد؛ نه اینکه با کلیدِ debugِ تصادفی امضا شود
            //    (کلیدِ debug در هر اجرا فرق می‌کند و باعث می‌شد «آپدیت» نصب نشود و مجبور شوی حذف کنی).
            if (!keystoreFile.exists() && System.getenv("CI") != null) {
                throw GradleException("release-key.jks پیدا نشد؛ KEYSTORE_BASE64 را در Secrets بررسی کن.")
            }
            signingConfig = if (keystoreFile.exists()) signingConfigs.getByName("release")
                            else signingConfigs.getByName("debug")
            // R8: حذفِ کدِ بلااستفاده + حذفِ منابعِ بلااستفاده
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        // فقط وقتی با فلگِ استانداردِ Flutter «--target-platform android-arm64» بیلد می‌شه:
        // .so های ۳۲بیتی/x86 که کتابخانه‌های دیگر (Sherpa AAR، ML Kit) با خودشون میارن هم حذف می‌شن.
        // (بیلدِ دیباگ/امولاتور بدونِ این فلگ دست‌نخورده می‌مونه.)
        val targetPlatform = (project.findProperty("target-platform") as String?) ?: ""
        if (targetPlatform == "android-arm64") {
            jniLibs {
                excludes += listOf(
                    "lib/armeabi-v7a/**", "lib/x86/**", "lib/x86_64/**"
                )
            }
        }
        resources {
            excludes += listOf(
                "META-INF/DEPENDENCIES", "META-INF/LICENSE", "META-INF/LICENSE.txt",
                "META-INF/NOTICE", "META-INF/NOTICE.txt"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Sherpa-ONNX (فایل AAR توسط ورک‌فلو داخل android/app/libs دانلود می‌شه)
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))

    implementation("androidx.core:core:1.13.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.mlkit:translate:17.0.3")
    implementation("com.google.mlkit:text-recognition:16.0.1")             // OCR لاتین
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")  // OCR هندی
}
