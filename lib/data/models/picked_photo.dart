import 'history_item.dart';

/// 拍摄页回传给主页的照片。
///
/// 单独包一层 [IdentifySource]，是因为「在自研拍摄页里从相册选图」这条路径
/// 返回的其实是一张相册照片，如果只回传路径，历史记录会把来源记成「拍照」。
class PickedPhoto {
  const PickedPhoto({
    required this.path,
    this.source = IdentifySource.camera,
  });

  final String path;
  final IdentifySource source;
}
