plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.apipppx.cyclingcoach"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Application ID final untuk Play Store (dulu com.example.*).
        applicationId = "com.apipppx.cyclingcoach"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing dari android/key.properties (file lokal, TIDAK di-commit
    // — lihat android/.gitignore). Fresh clone tanpa file itu fallback ke
    // debug agar `flutter run` / build tetap jalan.
    // (Parsing manual key=value agar script tetap kompatibel dengan AGP 9.)
    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasReleaseKey = keystorePropertiesFile.exists()
    val keystoreProps: Map<String, String> = if (hasReleaseKey) {
        keystorePropertiesFile.readLines().mapNotNull { line ->
            val t = line.trim()
            if (t.isEmpty() || t.startsWith("#") || !t.contains("=")) {
                null
            } else {
                val i = t.indexOf("=")
                t.substring(0, i).trim() to t.substring(i + 1).trim()
            }
        }.toMap()
    } else {
        emptyMap()
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                keyAlias = keystoreProps.getValue("keyAlias")
                keyPassword = keystoreProps.getValue("keyPassword")
                storeFile = file(keystoreProps.getValue("storeFile"))
                storePassword = keystoreProps.getValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
