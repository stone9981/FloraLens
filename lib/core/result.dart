import 'package:flutter/foundation.dart';

/// 轻量 Result 类型，用于替代到处抛异常的写法。
///
/// UI 层统一通过 [when] 收敛成功/失败两条分支，保证错误态一定被处理。
class Result<T> {
  const Result.ok(this.value) : error = null, stackTrace = null;

  const Result.err(this.error, [this.stackTrace]) : value = null;

  final T? value;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isOk => error == null;
  bool get isErr => error != null;

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppException error) err,
  }) {
    final e = error;
    if (e == null) {
      return ok(value as T);
    }
    return err(e is AppException ? e : AppException.unknown(e));
  }

  R? fold<R>({
    R Function(T value)? ok,
    R Function(AppException error)? err,
  }) {
    final e = error;
    if (e == null) return ok?.call(value as T);
    return err?.call(e is AppException ? e : AppException.unknown(e));
  }

  /// 成功则返回原值，失败则返回 [fallback]。
  T getOr(T fallback) => error == null ? value as T : fallback;
}

/// 应用统一异常类型，携带可直接展示给用户的文案。
class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  factory AppException.unknown([Object? cause]) =>
      AppException('发生了未知错误', code: 'unknown', cause: cause);

  factory AppException.network([String? message]) =>
      AppException(message ?? '网络连接失败，请检查网络后重试', code: 'network');

  factory AppException.unauthorized(String engine) =>
      AppException('$engine 的 API Key 无效或额度已用尽', code: 'unauthorized');

  factory AppException.quota() =>
      AppException('当前服务商额度不足，请更换引擎或稍后再试', code: 'quota');

  factory AppException.timeout() =>
      AppException('请求超时，请稍后重试', code: 'timeout');

  factory AppException.notConfigured(String what) =>
      AppException('尚未配置$what，请到设置页完成配置', code: 'not_configured');

  factory AppException.permission() =>
      AppException('缺少必要权限，请在系统设置中开启', code: 'permission');

  factory AppException.parse() =>
      AppException('服务端返回的数据无法解析', code: 'parse');

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() {
    final buf = StringBuffer('AppException(${code ?? 'none'}): $message');
    if (cause != null) buf.write(' <- $cause');
    return buf.toString();
  }

  /// 打印到控制台，便于定位线上问题。
  void report([StackTrace? trace]) {
    debugPrint('[AppException] $this');
    if (trace != null) debugPrint('$trace');
  }
}

/// 让 [Object?] 快速转 [Result]，简化 try/catch 样板代码。
extension ResultGuard<R> on R Function() {
  Result<R> tryRun({AppException Function(Object e, StackTrace s)? onError}) {
    try {
      return Result<R>.ok(this());
    } catch (e, s) {
      return Result<R>.err(onError?.call(e, s) ?? AppException.unknown(e), s);
    }
  }
}
