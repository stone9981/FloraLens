pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 国内镜像优先，缺失时自动回落到官方源
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
        maven("https://maven.aliyun.com/repository/gradle-plugin")
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

// 注意：这里不要声明 dependencyResolutionManagement + RepositoriesMode.PREFER_SETTINGS。
// Flutter Gradle 插件是通过 `rootProject.allprojects { repositories.maven { url = ".../download.flutter.io" } }`
// 在**项目级**注册 Flutter 引擎仓库（io.flutter:arm64_v8a_release 等）的。
// 一旦使用 PREFER_SETTINGS，项目级仓库会被整体忽略，导致
// "Could not find io.flutter:arm64_v8a_release:1.0.0-<engineHash>"。
// 依赖仓库统一交给 android/build.gradle.kts 的 allprojects 块。

include(":app")
