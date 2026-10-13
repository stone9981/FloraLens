import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme.dart';
import '../../data/models/history_item.dart';
import '../../data/models/picked_photo.dart';
import '../../l10n/app_localizations.dart';

/// 自研拍摄页。
///
/// 不直接调系统相机，是为了给一个构图引导框 —— 花朵占满画面时识别率最高。
class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key});

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _cameraIndex = 0;
  bool _initializing = true;
  bool _taking = false;
  bool _flashOn = false;
  String? _error;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // 离开 app（如跳到系统设置页）时释放相机，避免长期占用。
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // 回到 app（含从系统设置开启相机权限后返回）必须重新检查权限并初始化。
      // 不能因 controller 已被 dispose 就跳过，否则会永远停在「永久拒绝」界面、
      // 相机预览无法恢复。
      _init();
    }
  }

  Future<void> _init() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _permanentlyDenied = status.isPermanentlyDenied;
        _error = status.isPermanentlyDenied
            ? context.l10n.tr('permissionPermanentlyDenied')
            : context.l10n.tr('permissionDenied');
      });
      return;
    }
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _error = context.l10n.tr('noCamera');
        });
        return;
      }
      await _attach(_cameraIndex.clamp(0, cams.length - 1), cams);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = context.l10n.tr('cameraStartFailed', <String>[e.toString()]);
      });
    }
  }

  Future<void> _attach(int index, List<CameraDescription> cams) async {
    final old = _controller;
    if (old != null) {
      await old.dispose();
    }
    final controller = CameraController(
      cams[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _cameras = cams;
      _cameraIndex = index;
      _initializing = false;
      _error = null;
    });
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _taking)
      return;
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context)
          .pop(PickedPhoto(path: file.path, source: IdentifySource.camera));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.tr('captureFailed'))));
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2600,
      );
      if (picked == null || !mounted) return;
      // 同样是相册照片，只是从自研拍摄页里选的，来源得如实记成「相册」。
      Navigator.of(context)
          .pop(PickedPhoto(path: picked.path, source: IdentifySource.gallery));
    } catch (_) {}
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFlashMode(_flashOn ? FlashMode.off : FlashMode.torch);
      if (!mounted) return;
      setState(() => _flashOn = !_flashOn);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    setState(() => _initializing = true);
    await _attach(next, _cameras);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildPreview(),
          _buildTopBar(),
          _buildFrame(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final controller = _controller;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.no_photography_outlined,
                size: 52,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              if (_permanentlyDenied)
                OutlinedButton.icon(
                  onPressed: () {
                    // 同步先弹手动路径弹窗：保证「点了必有可见反馈」，绝不静默无响应。
                    // 弹窗内的「打开系统设置」按钮再走最可靠的原生通道尝试自动跳转。
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.l10n.tr('openSettingsManualTitle')),
                        content: Text(context.l10n.tr('openSettingsManualBody')),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              print('[dart] openSystemSettings tapped '
                                  '(permanentlyDenied=$_permanentlyDenied)');
                              // 1) 原生 MethodChannel（真机最可靠）：UIApplication.openSettingsURLString
                              try {
                                await const MethodChannel('com.floralens/native')
                                    .invokeMethod<void>('openAppSettings');
                                print('[dart] native openAppSettings invoked');
                              } catch (e) {
                                print('[dart] native openAppSettings FAILED: $e');
                              }
                              // 2) 退一步：permission_handler 官方跳转
                              try {
                                await openAppSettings();
                                print('[dart] openAppSettings(ph) invoked');
                              } catch (e) {
                                print('[dart] openAppSettings(ph) FAILED: $e');
                              }
                            },
                            child: Text(context.l10n.tr('openSystemSettings')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(context.l10n.tr('ok')),
                          ),
                        ],
                      ),
                    );
                    // 从系统设置返回后会由 AppLifecycleState.resumed 触发 _init 重新检查权限。
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(context.l10n.tr('openSystemSettings')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _init,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.tr('retry')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (_initializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
              const Spacer(),
              if (_cameras.length > 1)
                IconButton(
                  onPressed: _switchCamera,
                  icon: const Icon(
                    Icons.flip_camera_ios_outlined,
                    color: Colors.white,
                  ),
                ),
              // iOS 没有独立的「手电筒」权限：手电筒 = 相机预览的闪光灯模式，
              // 必须相机权限已允许且预览正在运行才能用。相机未就绪时置灰，
              // 避免用户误以为在申请一个不存在的权限。
              IconButton(
                onPressed:
                    (_controller != null && _controller!.value.isInitialized)
                        ? _toggleFlash
                        : null,
                icon: Icon(
                  _flashOn
                      ? Icons.flashlight_on
                      : Icons.flashlight_off_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构图引导：中间一个圆角方形，提示把花放进来。
  Widget _buildFrame() {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.78,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: <Widget>[
                for (final corner in _Corner.values)
                  Align(
                    alignment: corner.alignment,
                    child: _CornerMark(corner: corner),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                context.l10n.tr('frameHint'),
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    onPressed: _pickFromGallery,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  GestureDetector(
                    onTap: _shoot,
                    child: Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 2,
                        ),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _taking
                            ? const Padding(
                                padding: EdgeInsets.all(22),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: AppTheme.brandGreen,
                                size: 30,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

extension on _Corner {
  Alignment get alignment {
    switch (this) {
      case _Corner.topLeft:
        return Alignment.topLeft;
      case _Corner.topRight:
        return Alignment.topRight;
      case _Corner.bottomLeft:
        return Alignment.bottomLeft;
      case _Corner.bottomRight:
        return Alignment.bottomRight;
    }
  }
}

class _CornerMark extends StatelessWidget {
  const _CornerMark({required this.corner});

  final _Corner corner;

  @override
  Widget build(BuildContext context) {
    const size = 26.0;
    final color = Colors.white.withValues(alpha: 0.95);
    BorderSide side = BorderSide(color: color, width: 3);
    BoxBorder border;
    switch (corner) {
      case _Corner.topLeft:
        border = Border(top: side, left: side);
        break;
      case _Corner.topRight:
        border = Border(top: side, right: side);
        break;
      case _Corner.bottomLeft:
        border = Border(bottom: side, left: side);
        break;
      case _Corner.bottomRight:
        border = Border(bottom: side, right: side);
        break;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: border,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
    );
  }
}
