import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/history_item.dart';
import '../../data/models/picked_photo.dart';

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
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
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
            ? AppStrings.permissionPermanentlyDenied
            : AppStrings.permissionDenied;
      });
      return;
    }
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _error = '这台设备没有可用的摄像头';
        });
        return;
      }
      await _attach(_cameraIndex.clamp(0, cams.length - 1), cams);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = '相机启动失败：$e';
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
    if (controller == null || !controller.value.isInitialized || _taking) return;
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(
        PickedPhoto(path: file.path, source: IdentifySource.camera),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('拍照失败，请重试')),
      );
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
      Navigator.of(context).pop(
        PickedPhoto(path: picked.path, source: IdentifySource.gallery),
      );
    } catch (_) {}
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller
          .setFlashMode(_flashOn ? FlashMode.off : FlashMode.torch);
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
              const Icon(Icons.no_photography_outlined,
                  size: 52, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              if (_permanentlyDenied)
                OutlinedButton.icon(
                  onPressed: () async {
                    await openAppSettings();
                    // 从系统设置返回后会由 AppLifecycleState.resumed 触发 _init 重新检查权限。
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('去系统设置'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _init,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
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
    if (_initializing || controller == null || !controller.value.isInitialized) {
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
                  icon: const Icon(Icons.flip_camera_ios_outlined,
                      color: Colors.white),
                ),
              IconButton(
                onPressed: _toggleFlash,
                icon: Icon(
                  _flashOn ? Icons.flashlight_on : Icons.flashlight_off_outlined,
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
              const Text(
                '把花朵放进框内，尽量充满画面',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined,
                        color: Colors.white, size: 26),
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt_rounded,
                                color: AppTheme.brandGreen, size: 30),
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
