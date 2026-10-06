import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 从 android/key.properties 读取正式签名配置；文件不存在时自动回落到 debug 签名，
// 保证刚克隆仓库也能直接 build。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.floralens.flora_lens"
    // 部分插件（如 permission_handler_android 14.x）硬编码 compileSdk = 37，
    // 主工程统一跟到 37 可避免跨模块 compileSdk 校验问题。
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.floralens.flora_lens"
        // camera / permission_handler / gal 都要求 21+；取 24 兼顾主流插件与覆盖率
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("zh", "en")
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // 首版先关闭 Java 层混淆，避免个别插件缺少 keep 规则导致运行期崩溃。
            // 确认稳定后把这里改为 true 即可（proguard-rules.pro 已备好）。
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    // 注意：不要在这里手写 splits { abi { ... } }。
    // Flutter Gradle 插件会根据 `flutter build apk --split-per-abi` 传入的
    // -Psplit-per-abi=true 自行设置 splits.abi；同时它又会按 target-platform
    // 写入 ndk.abiFilters。两者同时存在会导致
    // "Conflicting configuration ... ndk abiFilters cannot be present when splits abi filters are set"。
    // 因此拆包交给 Flutter 插件，这里保持干净。
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
