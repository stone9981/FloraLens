import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../models/app_settings.dart';
import '../models/plant.dart';
import '../models/plant_profile.dart';

/// OpenAI 兼容协议的大模型客户端。
///
/// 之所以只实现这一个协议：市面上 95% 的服务商与本地推理框架
/// （DeepSeek / 通义 / 智谱 / Kimi / 豆包 / OpenAI / Ollama / llama.cpp / vLLM）
/// 都兼容 `/chat/completions`，一套代码即可通吃云端与本地。
class LlmClient {
  LlmClient(this.config);

  final LlmConfig config;

  static const String _chatPath = '/chat/completions';

  String get _normalizedBase {
    var base = config.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  Dio _buildDio() {
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    // 本地推理服务通常不需要鉴权，但仍允许留空。
    if (config.apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey.trim()}';
    }
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: Duration(seconds: config.timeoutSeconds),
        sendTimeout: const Duration(seconds: 30),
        headers: headers,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status >= 200 && status < 500,
      ),
    );
  }

  /// 发送一轮纯文本对话，返回模型文本。
  Future<Result<String>> chat({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int maxTokens = 1600,
  }) async {
    if (config.baseUrl.trim().isEmpty || config.model.trim().isEmpty) {
      return const Result.err(AppException('尚未配置大模型服务', code: 'not_configured'));
    }

    return _post(<String, dynamic>{
      'model': config.model.trim(),
      'messages': <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature ?? config.temperature,
      'max_tokens': maxTokens,
      'stream': false,
    });
  }

  /// 发送一轮带图片的对话（视觉大模型识别用）。
  ///
  /// 走 OpenAI 兼容的多模态 content block 格式：
  /// user.content = [{"type":"text",...}, {"type":"image_url","image_url":{"url":"data:...","detail":"high"}}]
  /// 通义 / 智谱 / 豆包 / Kimi / OpenAI / Ollama / vLLM / llama.cpp 的兼容端点都认这套。
  Future<Result<String>> chatWithImage({
    required String systemPrompt,
    required String userPrompt,
    required Uint8List imageBytes,
    double? temperature,
    int maxTokens = 1500,
  }) async {
    if (config.baseUrl.trim().isEmpty || config.model.trim().isEmpty) {
      return const Result.err(AppException('尚未配置视觉模型服务', code: 'not_configured'));
    }

    final content = <Map<String, dynamic>>[
      {'type': 'text', 'text': userPrompt},
      {
        'type': 'image_url',
        'image_url': <String, dynamic>{
          'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
          // 细节设 high，花瓣与纹理是识别的关键依据。
          'detail': 'high',
        },
      },
    ];

    return _post(<String, dynamic>{
      'model': config.model.trim(),
      'messages': <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': content},
      ],
      // 识别类任务要的是稳定复现，不要发挥，所以固定低温。
      'temperature': temperature ?? 0.15,
      'max_tokens': maxTokens,
      'stream': false,
    });
  }

  /// 所有请求的公共部分：POST 到 /chat/completions 并抽取文本。
  Future<Result<String>> _post(Map<String, dynamic> body) async {
    final dio = _buildDio();
    try {
      final res = await dio.post(
        '$_normalizedBase$_chatPath',
        data: body,
      );
      final code = res.statusCode ?? 0;
      final data = res.data;

      if (code == 401 || code == 403) {
        return const Result.err(
            AppException('API Key 无效或没有该模型的权限', code: 'unauthorized'));
      }
      if (code == 429) {
        return Result.err(AppException.quota());
      }
      if (code >= 400) {
        final m = _asMap(data);
        final msg = _extractError(m) ?? '服务端返回 $code';
        return Result.err(AppException(_decorateError(msg, code, m),
            code: 'http_$code'));
      }

      final mapData = _asMap(data);

      // 部分网关（如 Agnes AI）遇到无效 Key 时返回 200 + {"error": {...}}，
      // 而非标准 401。这里必须兜底，否则会被误判成「无法解析」。
      if (mapData != null) {
        final apiErr = _extractError(mapData);
        if (apiErr != null) {
          return Result.err(
              AppException(_decorateApiError(apiErr), code: 'api_error'));
        }
      }

      // 兼容多种返回结构：OpenAI Chat / Agnes Responses / Anthropic Messages。
      final text = _extractContent(mapData);
      if (text != null && text.trim().isNotEmpty) {
        return Result.ok(text.trim());
      }

      // 结构无法识别：把原始返回透出来便于排查。
      final raw = _rawText(res);
      debugPrint('[LlmClient] 无法解析的响应: $raw');
      return Result.err(AppException(
        '服务端返回结构无法解析（未找到文本内容字段）'
        '${raw.isNotEmpty ? '；原始返回：${_clip(raw, 200)}' : ''}',
        code: 'parse',
      ));
    } on DioException catch (e, s) {
      return Result.err(_mapDioError(e), s);
    } catch (e, s) {
      return Result.err(AppException.unknown(e), s);
    }
  }

  /// 把常见的 404 / 模型名错误翻译成人能看懂的提示。
  String _decorateError(String message, int code, Map<String, dynamic>? data) {
    if (code != 404) return message;
    final raw = data == null ? '' : jsonEncode(data).toLowerCase();
    final isModelIssue = raw.contains('model') &&
        (raw.contains('not_found') ||
            raw.contains('does not exist') ||
            raw.contains('unknown') ||
            raw.contains('not found'));
    if (isModelIssue) {
      return '模型名不可用（404）。请确认「识别模型」填的是支持读图'
          '的视觉模型，例如 qwen-vl-plus / glm-4v-flash / gpt-4o-mini';
    }
    return '$message（404）';
  }

  /// 测试连通性：用最小 token 请求探活。
  /// 注意：agnes-2.5-flash 等推理模型会把 token 优先用于「思考」，
  /// 预算太小会导致正文为空。这里给足预算，让正文有机会产出。
  Future<Result<String>> testConnection() async {
    return chat(
      systemPrompt: '你是一个连接测试助手。',
      userPrompt: '请只回复两个字：正常',
      temperature: 0,
      maxTokens: 256,
    );
  }

  AppException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return AppException.timeout();
      case DioExceptionType.receiveTimeout:
        return const AppException('模型响应超时，可尝试更小的模型或提高超时时间',
            code: 'timeout');
      case DioExceptionType.connectionError:
        return AppException.network(
          _isLocal ? '无法连接到本地服务，请确认电脑端推理服务已启动、手机与电脑在同一局域网' : null,
        );
      case DioExceptionType.badResponse:
        return AppException('服务返回异常：${e.response?.statusCode}',
            code: 'bad_response');
      case DioExceptionType.cancel:
        return const AppException('请求已取消', code: 'cancel');
      case DioExceptionType.badCertificate:
        return const AppException('证书校验失败，请检查服务端证书', code: 'cert');
      case DioExceptionType.unknown:
      default:
        return AppException.network();
    }
  }

  bool get _isLocal {
    final b = config.baseUrl.toLowerCase();
    return b.startsWith('http://') ||
        b.contains('localhost') ||
        b.contains('127.0.0.1') ||
        b.contains('192.168.');
  }

  String? _extractError(Map<String, dynamic>? data) {
    if (data == null) return null;
    final err = data['error'];
    if (err is Map) {
      final msg = err['message'] ?? err['msg'];
      if (msg != null) return msg.toString();
    }
    if (err is String) return err;
    return null;
  }

  /// 把网关层业务错误（如 Agnes 的 Invalid token）翻译成人话。
  String _decorateApiError(String message) {
    final m = message.toLowerCase();
    if (m.contains('token') ||
        m.contains('unauthor') ||
        m.contains('auth') ||
        m.contains('api key') ||
        m.contains('permission') ||
        m.contains('expired')) {
      return 'API Key 无效或已失效（服务端原话：$message）。请在 Agnes 控制台重新复制 '
          'Key，点「粘贴 Key」填入后重试；注意别混用其他项目的 Key。';
    }
    return '服务端返回错误：$message';
  }

  /// 把响应体转成可读文本，用于解析失败时透出原始内容。
  String _rawText(Response<dynamic> res) {
    final d = res.data;
    if (d == null) return '';
    if (d is String) return d;
    try {
      return jsonEncode(d);
    } catch (_) {
      return d.toString();
    }
  }

  /// 截断过长的原始返回，避免提示文案爆框。
  String _clip(String s, int max) => s.length > max ? '${s.substring(0, max)}…' : s;

  /// 把响应体规整成 Map：处理 Dio 已解析的 Map，以及被误判为 String 的 JSON。
  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return null;
  }

  /// 从多种可能的响应结构里抽取模型文本。
  /// 兼容 OpenAI Chat / Agnes Responses API / Anthropic Messages 以及若干兜底字段。
  String? _extractContent(Map<String, dynamic>? data) {
    if (data == null) return null;

    // 1) OpenAI Chat Completions：choices[0].message.content
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final c0 = choices[0];
      if (c0 is Map) {
        final msg = (c0 as Map<String, dynamic>)['message'];
        if (msg is Map) {
          // 正文内容（推理模型真正的回答）
          final content = msg['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
          // 推理模型（如 Agnes 2.5 Flash）可能把全部 token 用于思考（reasoning_content），
          // 导致正文 content 为空。此时退回思考内容，至少能证明连通/出 token。
          final reasoning = msg['reasoning_content'];
          if (reasoning is String && reasoning.trim().isNotEmpty) {
            return reasoning.trim();
          }
          // 个别实现把文本直接挂在 choices[0].text
          if (c0['text'] is String) return (c0['text'] as String).trim();
        }
      }
    }

    // 2) Agnes / OpenAI Responses API：output[].content[].output_text|.text
    final output = data['output'];
    if (output is List) {
      final sb = StringBuffer();
      for (final item in output) {
        if (item is! Map) continue;
        final content = (item as Map<String, dynamic>)['content'];
        if (content is List) {
          for (final b in content) {
            if (b is Map &&
                (b['type'] == 'output_text' || b['type'] == 'text') &&
                b['text'] is String) {
              sb.write(b['text']);
            }
          }
        }
        if (item['text'] is String) sb.write(item['text']);
      }
      if (sb.isNotEmpty) return sb.toString().trim();
      // 顶层 output_text
      if (data['output_text'] is String) {
        return (data['output_text'] as String).trim();
      }
    }

    // 3) Anthropic Messages：content[].text
    final content = data['content'];
    if (content is List) {
      final sb = StringBuffer();
      for (final b in content) {
        if (b is Map && b['type'] == 'text' && b['text'] is String) {
          sb.write(b['text']);
        }
      }
      if (sb.isNotEmpty) return sb.toString().trim();
    }

    // 4) 兜底顶层字段
    for (final key in const [
      'content',
      'text',
      'output_text',
      'generated_text',
      'response',
      'answer',
      'completion',
    ]) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}

/// 从模型返回文本里抠出第一个 JSON 对象，兼容 ```json 围栏与前后废话。
String? extractJsonObject(String text) {
  var src = text.trim();
  final fenceStart = src.indexOf('```');
  if (fenceStart >= 0) {
    final after = src.substring(fenceStart + 3);
    final lineEnd = after.indexOf('\n');
    final body = lineEnd >= 0 ? after.substring(lineEnd) : after;
    final close = body.lastIndexOf('```');
    src = close >= 0 ? body.substring(0, close) : body;
  }
  final start = src.indexOf('{');
  final end = src.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  return src.substring(start, end + 1);
}

/// 把大模型的自然语言输出加工成结构化 [PlantProfile]。
class PlantProfileGenerator {
  PlantProfileGenerator(this._client, {required this.modelLabel});

  final LlmClient _client;
  final String modelLabel;

  static const String _systemPrompt = '''
你是一位资深植物学家兼中文科普作家，正在为一款识花 App 撰写词条。
要求：
1. 内容准确、克制、优雅，避免过度营销口吻；
2. 面向中国读者，使用简体中文与国内通用的植物俗名；
3. 必须只输出一个 JSON 对象，不要使用 markdown 代码块包裹，不要输出任何解释性文字；
4. 所有字段都能填就填，实在没有把握的字段留空字符串，不要编造具体数字；
5. 古诗词必须真实存在且确实描写该植物，找不到就留空。
''';

  String _userPrompt(PlantCandidate c) {
    final known = <String>[
      '拉丁学名：${c.scientificName}',
      if (c.commonName.isNotEmpty) '中文名：${c.commonName}',
      if (c.familyGenus.isNotEmpty) '科属：${c.familyGenus}',
      if (c.aliases.isNotEmpty) '别名：${c.aliases.join('、')}',
    ].join('\n');

    return '''
已知植物信息：
$known

请输出如下 JSON 结构：
{
  "latinName": "完整的拉丁学名（含命名人可省略）",
  "title": "最地道的中文名",
  "summary": "不超过 30 字的一句话科普，抓最具辨识度的特征",
  "story": "110~160 字的植物志介绍，讲清形态特征、分布环境或一个有趣的冷知识",
  "language": "花语，不超过 20 字",
  "bloomTime": "花期，如 4-6 月",
  "origin": "原产地与主要分布",
  "careTips": ["养护要点 1", "养护要点 2", "养护要点 3"],
  "tags": ["标签 1", "标签 2", "标签 3"],
  "toxicityNote": "毒性提示，确认无毒则写「无毒」",
  "poemLine": "描写该植物的一句中国古诗词"
}
''';
  }

  Future<Result<PlantProfile>> generate(PlantCandidate candidate) async {
    final r = await _client.chat(
      systemPrompt: _systemPrompt,
      userPrompt: _userPrompt(candidate),
      temperature: 0.65,
      maxTokens: 2048,
    );

    return r.when(
      ok: (text) {
        final json = _extractJson(text);
        if (json == null) {
          return Result.err(
            const AppException('模型没有返回可解析的内容，请重试或换一个模型',
                code: 'parse'),
          );
        }
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          final profile = PlantProfile(
            scientificName: candidate.scientificName.isNotEmpty
                ? candidate.scientificName
                : (map['latinName'] as String? ?? ''),
            title: (map['title'] as String?)?.trim().isNotEmpty == true
                ? (map['title'] as String).trim()
                : candidate.displayName,
            latinName: (map['latinName'] as String?)?.trim(),
            summary: (map['summary'] as String?)?.trim() ?? '',
            story: (map['story'] as String?)?.trim() ?? '',
            language: (map['language'] as String?)?.trim() ?? '',
            bloomTime: (map['bloomTime'] as String?)?.trim() ?? '',
            origin: (map['origin'] as String?)?.trim() ?? '',
            careTips: _stringList(map['careTips']),
            tags: _stringList(map['tags']),
            toxicityNote: (map['toxicityNote'] as String?)?.trim(),
            poemLine: (map['poemLine'] as String?)?.trim(),
            generatedBy: modelLabel,
            generatedAt: DateTime.now(),
          );
          if (profile.summary.isEmpty &&
              profile.story.isEmpty &&
              profile.careTips.isEmpty) {
            return Result.err(
              const AppException('模型返回内容不完整，请重试', code: 'empty'),
            );
          }
          return Result.ok(profile);
        } catch (e, s) {
          debugPrint('[PlantProfileGenerator] 解析失败: $e');
          return Result.err(AppException.parse(), s);
        }
      },
      err: (e) => Result.err(e),
    );
  }

  /// 从可能带 ```json 围栏的文本里抠出真正的 JSON 对象。
  static String? _extractJson(String text) => extractJsonObject(text);

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(6)
          .toList();
    }
    return const <String>[];
  }
}
