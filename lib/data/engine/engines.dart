import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../models/plant.dart';
import '../llm/llm_client.dart';
import 'identification_engine.dart';

/// Plant.id v3 —— 商业级识别服务，种类覆盖与准确率最好。
class PlantIdEngine extends IdentificationEngine with EngineParsing {
  PlantIdEngine({required this.apiKey});

  static const String _url = 'https://api.plant.id/v3/identification';

  final String apiKey;

  @override
  EngineType get type => EngineType.plantId;

  @override
  Future<Result<IdentificationResult>> identify(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    if (apiKey.trim().isEmpty) {
      return Result.err(AppException.notConfigured('Plant.id 的 API Key'));
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 40),
        sendTimeout: const Duration(seconds: 40),
        headers: <String, dynamic>{
          'Api-Key': apiKey.trim(),
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s >= 200 && s < 500,
      ),
    );

    final sw = Stopwatch()..start();
    try {
      final res = await dio.post<Map<String, dynamic>>(
        _url,
        data: <String, dynamic>{
          'images': <String>[toDataUri(imageBytes)],
          'similar_images': true,
          'classification_level': 'all',
          // 重点器官优先给花，提高花卉识别准确率。
          'plant_details': <String>[
            'common_names',
            'taxonomy',
            'url',
            'wiki_description',
            'synonyms',
          ],
        },
      );
      sw.stop();

      final code = res.statusCode ?? 0;
      final data = res.data;
      if (code == 401 || code == 403) {
        return Result.err(AppException.unauthorized('Plant.id'));
      }
      if (code == 429) {
        return Result.err(AppException.quota());
      }
      if (code >= 400 || data == null) {
        final msg = data?['error']?.toString() ?? 'Plant.id 返回 $code';
        return Result.err(AppException(msg, code: 'http_$code'));
      }

      final suggestions =
          ((data['result']?['classification']?['suggestions']) as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              const <Map<String, dynamic>>[];

      final candidates = suggestions.take(6).map((s) {
        final details = (s['details'] as Map<String, dynamic>?) ?? const {};
        final taxonomy = (details['taxonomy'] as Map<String, dynamic>?) ?? const {};
        final similar = (s['similar_images'] as List<dynamic>?) ?? const [];
        final imageUrl = similar.isNotEmpty
            ? ((similar.first as Map<String, dynamic>?)?['url'] as String?)
            : null;
        final desc = (details['wiki_description'] as Map<String, dynamic>?)?['value']
            as String?;

        return PlantCandidate(
          scientificName: (s['name'] as String? ?? '').trim(),
          commonName: firstString(details['common_names']) ??
              (s['name'] as String? ?? ''),
          aliases: toStringList(details['common_names'])
              .skip(1)
              .take(4)
              .toList(),
          family: firstString(taxonomy['family']),
          genus: firstString(taxonomy['genus']),
          confidence: normalizeConfidence(s['probability'] as num?),
          wikiUrl: details['url'] as String?,
          imageUrl: imageUrl,
          description: desc,
          rawScore: s['probability'] as num?,
        );
      }).where((c) => c.scientificName.isNotEmpty).toList();

      return Result.ok(
        IdentificationResult(
          candidates: candidates,
          engine: type,
          identifiedAt: DateTime.now(),
          elapsed: sw.elapsed,
          rawResponseHash: 'plantid:${suggestions.length}:$code',
        ),
      );
    } on DioException catch (e, s) {
      sw.stop();
      return Result.err(_mapError(e), s);
    } catch (e, s) {
      sw.stop();
      return Result.err(AppException.unknown(e), s);
    }
  }

  AppException _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException.timeout();
      case DioExceptionType.connectionError:
        return AppException.network();
      case DioExceptionType.badResponse:
        return AppException('Plant.id 返回 ${e.response?.statusCode}',
            code: 'bad_response');
      default:
        return AppException.network();
    }
  }
}

/// Pl@ntNet —— 由法国科研机构维护，免费额度友好。
class PlantNetEngine extends IdentificationEngine with EngineParsing {
  PlantNetEngine({required this.apiKey});

  static const String _url =
      'https://my-api.plantnet.org/v2/identify/weurope';

  final String apiKey;

  @override
  EngineType get type => EngineType.plantNet;

  @override
  Future<Result<IdentificationResult>> identify(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    if (apiKey.trim().isEmpty) {
      return Result.err(AppException.notConfigured('Pl@ntNet 的 API Key'));
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 45),
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s >= 200 && s < 500,
      ),
    );

    final form = FormData.fromMap(<String, dynamic>{
      'organs': 'flower',
      'images': <MultipartFile>[
        MultipartFile.fromBytes(
          imageBytes,
          filename: fileName ?? 'flower.jpg',
        ),
      ],
    });

    final sw = Stopwatch()..start();
    try {
      final res = await dio.post<Map<String, dynamic>>(
        _url,
        data: form,
        queryParameters: <String, dynamic>{'api-key': apiKey.trim()},
      );
      sw.stop();

      final code = res.statusCode ?? 0;
      final data = res.data;
      if (code == 401 || code == 403) {
        return Result.err(AppException.unauthorized('Pl@ntNet'));
      }
      if (code == 429) {
        return Result.err(AppException.quota());
      }
      if (code >= 400 || data == null) {
        return Result.err(AppException('Pl@ntNet 返回 $code', code: 'http_$code'));
      }

      final results =
          (data['results'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              const <Map<String, dynamic>>[];

      final candidates = results.take(6).map((r) {
        final species = (r['species'] as Map<String, dynamic>?) ?? const {};
        final family = (species['family'] as Map<String, dynamic>?) ?? const {};
        final genus = (species['genus'] as Map<String, dynamic>?) ?? const {};
        final images = (r['images'] as List<dynamic>?) ?? const [];
        String? imageUrl;
        if (images.isNotEmpty) {
          final first = images.first;
          if (first is Map) {
            imageUrl = (first['url'] as Map<String, dynamic>?)?['o'] as String? ??
                first['url'] as String?;
          }
        }

        return PlantCandidate(
          scientificName:
              (species['scientificNameWithoutAuthor'] as String? ??
                      species['scientificName'] as String? ??
                      '')
                  .trim(),
          commonName: firstString(species['commonNames']) ?? '',
          aliases: toStringList(species['commonNames']).skip(1).take(4).toList(),
          family: firstString(family['scientificName']),
          genus: firstString(genus['scientificName']),
          confidence: normalizeConfidence(r['score'] as num?),
          imageUrl: imageUrl,
          rawScore: r['score'] as num?,
        );
      }).where((c) => c.scientificName.isNotEmpty).toList();

      return Result.ok(
        IdentificationResult(
          candidates: candidates,
          engine: type,
          identifiedAt: DateTime.now(),
          elapsed: sw.elapsed,
          rawResponseHash: 'plantnet:${results.length}:$code',
        ),
      );
    } on DioException catch (e, s) {
      sw.stop();
      return Result.err(_mapError(e), s);
    } catch (e, s) {
      sw.stop();
      return Result.err(AppException.unknown(e), s);
    }
  }

  AppException _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException.timeout();
      case DioExceptionType.connectionError:
        return AppException.network();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 404) {
          return const AppException('Pl@ntNet 未能识别，可换一张更清晰的花朵照片',
              code: 'not_found');
        }
        return AppException('Pl@ntNet 返回 $code', code: 'bad_response');
      default:
        return AppException.network();
    }
  }
}

/// Kindwise —— Plant.id 同协议的企业版接口，独立 Key 与额度。
class KindwiseEngine extends IdentificationEngine with EngineParsing {
  KindwiseEngine({required this.apiKey, this.endpoint});

  static const String _defaultUrl = 'https://plant.id/api/v3/identification';

  final String apiKey;
  final String? endpoint;

  @override
  EngineType get type => EngineType.kindwise;

  String get _url {
    final e = (endpoint ?? '').trim();
    return e.isEmpty ? _defaultUrl : e;
  }

  @override
  Future<Result<IdentificationResult>> identify(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    if (apiKey.trim().isEmpty) {
      return Result.err(AppException.notConfigured('Kindwise 的 API Key'));
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 40),
        headers: <String, dynamic>{
          'Api-Key': apiKey.trim(),
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s >= 200 && s < 500,
      ),
    );

    final sw = Stopwatch()..start();
    try {
      final res = await dio.post<Map<String, dynamic>>(
        _url,
        data: <String, dynamic>{
          'images': <String>[toDataUri(imageBytes)],
          'similar_images': true,
          'plant_details': <String>['common_names', 'taxonomy', 'url'],
        },
      );
      sw.stop();

      if ((res.statusCode ?? 500) >= 400) {
        final code = res.statusCode!;
        if (code == 401 || code == 403) {
          return Result.err(AppException.unauthorized('Kindwise'));
        }
        if (code == 429) return Result.err(AppException.quota());
        return Result.err(AppException('Kindwise 返回 $code', code: 'http_$code'));
      }

      final data = res.data;
      final suggestions =
          ((data?['result']?['classification']?['suggestions']) as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              const <Map<String, dynamic>>[];

      final candidates = suggestions.take(6).map((s) {
        final details = (s['details'] as Map<String, dynamic>?) ?? const {};
        final taxonomy = (details['taxonomy'] as Map<String, dynamic>?) ?? const {};
        return PlantCandidate(
          scientificName: (s['name'] as String? ?? '').trim(),
          commonName: firstString(details['common_names']) ?? '',
          aliases: toStringList(details['common_names']).skip(1).take(4).toList(),
          family: firstString(taxonomy['family']),
          genus: firstString(taxonomy['genus']),
          confidence: normalizeConfidence(s['probability'] as num?),
          wikiUrl: details['url'] as String?,
          rawScore: s['probability'] as num?,
        );
      }).where((c) => c.scientificName.isNotEmpty).toList();

      return Result.ok(
        IdentificationResult(
          candidates: candidates,
          engine: type,
          identifiedAt: DateTime.now(),
          elapsed: sw.elapsed,
        ),
      );
    } on DioException catch (e, s) {
      sw.stop();
      return Result.err(
        e.type == DioExceptionType.connectionError
            ? AppException.network()
            : AppException.timeout(),
        s,
      );
    } catch (e, s) {
      sw.stop();
      return Result.err(AppException.unknown(e), s);
    }
  }
}

/// 视觉大模型引擎 —— 用能「看图」的大模型直接做物种识别。
///
/// 与 [PlantIdEngine] 这类专用分类模型相比：
/// - Pros：一套配置通吃，不用注册植物站点的账号，泛化能力强；
/// - Cons：比专用模型慢（3~8 秒），细碎物种准确率略低，且可能「硬编」一个品种。
///
/// 连接信息与文案模型共用（[LlmConfig]），只有模型名不同，
/// 因此在设置页里叫「识别模型」。
class VlmEngine extends IdentificationEngine with EngineParsing {
  VlmEngine({required this.config, required this.l10n});

  final LlmConfig config;
  final AppLocalizations l10n;

  @override
  EngineType get type => EngineType.vlm;

  static const String _systemPromptZh = '''
你是植物分类学专家，擅长从花卉照片判断物种。你会收到一张植物照片。
要求：
1. 结合花期、花色、花型、叶形、株型综合判断，优先给出最可能是观赏植物的答案；
2. 拉丁学名要完整规范，中文名使用国内通用俗称；
3. 只输出一个 JSON 对象，不要用 markdown 代码块包裹，不要输出任何解释性文字；
4. 分辨不清时给出最接近的类别，并如实调低 confidence；
5. confidence 是 0~1 的小数，代表你的把握程度，不要一律给满分。
''';

  static const String _systemPromptEn = '''
You are a plant taxonomy expert who identifies species from flower photos. You will receive one plant photo.
Requirements:
1. Judge by bloom season, flower color, flower shape, leaf shape and growth form together; prefer the most likely ornamental plant.
2. Give a complete, properly formatted scientific (Latin) name; use the widely used English common name for "commonName".
3. Output only a single JSON object, no markdown code fences, no explanatory text.
4. When unsure, give the closest category and lower confidence honestly.
5. confidence is a 0~1 float representing your certainty; do not always give full marks.
''';

  static const String _userPromptZh = '''
请识别这张照片里的植物，输出如下 JSON：
{
  "candidates": [
    {
      "scientificName": "完整的拉丁学名",
      "commonName": "中文名",
      "family": "科名",
      "genus": "属名",
      "confidence": 0.87
    }
  ]
}
候选最多 6 个，按 confidence 从高到低排列。
''';

  static const String _userPromptEn = '''
Identify the plant in this photo and output the following JSON:
{
  "candidates": [
    {
      "scientificName": "full Latin name",
      "commonName": "English common name",
      "family": "family name",
      "genus": "genus name",
      "confidence": 0.87
    }
  ]
}
Up to 6 candidates, sorted by confidence descending.
''';

  String get _systemPrompt =>
      l10n.locale.languageCode == 'en' ? _systemPromptEn : _systemPromptZh;

  String get _userPrompt =>
      l10n.locale.languageCode == 'en' ? _userPromptEn : _userPromptZh;

  @override
  Future<Result<IdentificationResult>> identify(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    if (!config.isConfigured) {
      return Result.err(AppException.notConfigured('视觉模型的 Base URL 与模型名'));
    }

    final sw = Stopwatch()..start();
    final client = LlmClient(config);
    final r = await client.chatWithImage(
      systemPrompt: _systemPrompt,
      userPrompt: _userPrompt,
      imageBytes: imageBytes,
      temperature: 0.15,
      maxTokens: 700,
    );
    sw.stop();

    final err = r.error;
    if (err != null) {
      return Result.err(err, r.stackTrace);
    }

    final candidates = _parse((r.value as String).trim());
    if (candidates.isEmpty) {
      return Result.err(
        const AppException('模型没有给出可识别的物种，请重试或换一张更清晰的花朵照片',
            code: 'parse'),
      );
    }

    return Result.ok(
      IdentificationResult(
        candidates: candidates,
        engine: type,
        identifiedAt: DateTime.now(),
        elapsed: sw.elapsed,
        rawResponseHash: 'vlm:${config.model.trim()}:${candidates.length}',
      ),
    );
  }

  List<PlantCandidate> _parse(String text) {
    debugPrint('[VlmEngine] 模型返回：${text.length > 300 ? '${text.substring(0, 300)}…' : text}');

    final json = extractJsonObject(text);
    if (json == null) return const <PlantCandidate>[];

    try {
      final map = jsonDecode(json);
      if (map is! Map<String, dynamic>) return const <PlantCandidate>[];

      final raw = map['candidates'] ??
          map['results'] ??
          map['identification'] ??
          map['plants'];
      if (raw is! List) return const <PlantCandidate>[];

      final list = raw
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => PlantCandidate(
              scientificName: (m['scientificName'] as String? ??
                      m['name'] as String? ??
                      m['latinName'] as String? ??
                      '')
                  .trim(),
              commonName: (m['commonName'] as String? ??
                      m['cnName'] as String? ??
                      m['name'] as String? ??
                      '')
                  .trim(),
              aliases: toStringList(m['aliases'] ?? m['commonNames']),
              family: firstString(m['family']),
              genus: firstString(m['genus']),
              confidence: normalizeConfidence(
                m['confidence'] as num? ?? m['score'] as num?,
              ),
              rawScore: m['confidence'] as num? ?? m['score'] as num?,
            ),
          )
          .where((c) => c.scientificName.isNotEmpty)
          .toList();

      list.sort((a, b) => b.confidence.compareTo(a.confidence));
      return list.take(6).toList();
    } catch (e) {
      debugPrint('[VlmEngine] 解析失败: $e');
      return const <PlantCandidate>[];
    }
  }
}

/// 自建服务引擎。
///
/// 面向两类用户：
/// 1. 自己部署了识别模型（FastAPI / Triton / 阿里百炼等），对外暴露 HTTP 接口；
/// 2. 想在局域网内走自建网关，图片不上传公网。
///
/// 约定协议（POST JSON）：
/// 请求：{"image": "<base64>", "topk": 6}
/// 响应：{"results":[{"scientificName":"","commonName":"","family":"",
///                    "genus":"","confidence":0.93,"aliases":[]}]}
class CustomHttpEngine extends IdentificationEngine with EngineParsing {
  CustomHttpEngine({required this.endpoint, this.apiKey = ''});

  final String endpoint;
  final String apiKey;

  @override
  EngineType get type => EngineType.customHttp;

  @override
  Future<Result<IdentificationResult>> identify(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    final url = endpoint.trim();
    if (url.isEmpty) {
      return Result.err(AppException.notConfigured('自建服务地址'));
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
        },
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s >= 200 && s < 500,
      ),
    );

    final sw = Stopwatch()..start();
    try {
      final res = await dio.post<dynamic>(
        url,
        data: <String, dynamic>{
          'image': base64Encode(imageBytes),
          'topk': 6,
          'mime': 'image/jpeg',
        },
      );
      sw.stop();

      final code = res.statusCode ?? 500;
      if (code >= 400) {
        return Result.err(AppException('自建服务返回 $code', code: 'http_$code'));
      }

      final data = res.data;
      final list = <dynamic>[];
      if (data is Map && data['results'] is List) {
        list.addAll(data['results'] as List<dynamic>);
      } else if (data is Map && data['candidates'] is List) {
        list.addAll(data['candidates'] as List<dynamic>);
      } else if (data is List) {
        list.addAll(data);
      }
      debugPrint('[CustomHttpEngine] 收到 ${list.length} 个候选');

      final candidates = list
          .whereType<Map<String, dynamic>>()
          .map((m) => PlantCandidate(
                scientificName: (m['scientificName'] as String? ??
                        m['name'] as String? ??
                        '')
                    .trim(),
                commonName: (m['commonName'] as String? ?? m['cnName'] as String? ?? '')
                    .trim(),
                aliases: toStringList(m['aliases']),
                family: firstString(m['family']),
                genus: firstString(m['genus']),
                confidence: normalizeConfidence(m['confidence'] as num?),
                rawScore: m['confidence'] as num?,
              ))
          .where((c) => c.scientificName.isNotEmpty)
          .toList();

      return Result.ok(
        IdentificationResult(
          candidates: candidates,
          engine: type,
          identifiedAt: DateTime.now(),
          elapsed: sw.elapsed,
        ),
      );
    } on DioException catch (e, s) {
      sw.stop();
      final isLocal = url.contains('192.168.') ||
          url.contains('localhost') ||
          url.contains('127.0.0.1');
      return Result.err(
        AppException.network(
          isLocal
              ? '连不上本地服务，请确认服务已启动、手机与电脑在同一局域网，且地址不是 localhost'
              : null,
        ),
        s,
      );
    } catch (e, s) {
      sw.stop();
      return Result.err(AppException.unknown(e), s);
    }
  }
}
