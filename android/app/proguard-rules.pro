# 混淆规则。当前 release 默认关闭混淆（build.gradle.kts 里 isMinifyEnabled = false），
# 稳定后开启时以下规则可直接生效。

# --- Flutter 引擎 ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- 插件 GeneratedPluginRegistrant 依赖反射 ---
-keep class com.floralens.flora_lens.MainActivity { *; }
-keepclassmembers class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# --- 反射序列化相关的 keep 规则（若后续引入 json_serializable / freezed）---
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
-keep @androidx.annotation.Keep class * { *; }

# --- 调试信息：保留行号便于排查线上崩溃 ---
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# --- 告警收敛 ---
-dontwarn io.flutter.**
-dontwarn androidx.**
