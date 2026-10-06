import 'plant.dart';
import 'plant_profile.dart';

/// 这张照片是怎么进来的。
///
/// 拍照与相册选图走的是两条不同的系统通道，相册那一路拿到的是外部路径，
/// 更容易遇到「文件被系统回收、缩略图变黑」的问题，所以要区分开记录。
enum IdentifySource {
  camera('camera', '拍照'),
  gallery('gallery', '相册');

  const IdentifySource(this.id, this.label);

  final String id;
  final String label;

  static IdentifySource fromId(String? id) => IdentifySource.values.firstWhere(
        (s) => s.id == id,
        orElse: () => IdentifySource.camera,
      );
}

/// 历史记录条目：一次识别的完整快照。
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.createdAt,
    required this.imagePath,
    required this.candidate,
    this.profile,
    this.cardPath,
    this.engineId,
    this.source = IdentifySource.camera,
  });

  final String id;

  /// 识别时间。
  final DateTime createdAt;

  /// 受管目录中的原图路径。
  final String imagePath;

  /// 最终采用的品种（可能被用户手动纠正过）。
  final PlantCandidate candidate;

  /// 大模型/词典生成的档案。
  final PlantProfile? profile;

  /// 最近一次导出的分享卡片路径。
  final String? cardPath;

  final String? engineId;

  /// 这张照片的来源：拍照还是相册选图。
  final IdentifySource source;

  HistoryItem copyWith({
    PlantProfile? profile,
    String? cardPath,
  }) {
    return HistoryItem(
      id: id,
      createdAt: createdAt,
      imagePath: imagePath,
      candidate: candidate,
      profile: profile ?? this.profile,
      cardPath: cardPath ?? this.cardPath,
      engineId: engineId,
      source: source,
    );
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: (json['id'] as String?) ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        imagePath: (json['imagePath'] as String?) ?? '',
        candidate: PlantCandidate.fromJson(
          (json['candidate'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
        ),
        profile: json['profile'] != null
            ? PlantProfile.fromJson(json['profile'] as Map<String, dynamic>)
            : null,
        cardPath: json['cardPath'] as String?,
        engineId: json['engineId'] as String?,
        source: IdentifySource.fromId(json['source'] as String?),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'imagePath': imagePath,
        'candidate': candidate.toJson(),
        'profile': profile?.toJson(),
        'cardPath': cardPath,
        'engineId': engineId,
        'source': source.id,
      };
}
