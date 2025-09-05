import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cube_loader.dart';
import 'software_lut_processor.dart';
import 'lut_preview_manager.dart';

/// 增强版的LUT预览组件，包含视觉指示器
class SimpleLutPreview extends StatefulWidget {
  final CameraController cameraController;
  final String lutPath;
  final double mixStrength;
  final Widget? child;
  final bool isRearCamera;

  const SimpleLutPreview({
    super.key,
    required this.cameraController,
    required this.lutPath,
    required this.mixStrength,
    this.child,
    this.isRearCamera = true,
  });

  @override
  State<SimpleLutPreview> createState() => _SimpleLutPreviewState();
}

class _SimpleLutPreviewState extends State<SimpleLutPreview> {
  CubeLut? _currentLut;
  bool _isInitialized = false;
  String? _loadedLutPath;
  String _lutName = '';

  // Realtime preview processing
  bool _streaming = false;
  bool _isProcessing = false;
  ui.Image? _processedFrame;
  int _frameW = 0;
  int _frameH = 0;

  @override
  void initState() {
    super.initState();
    // Register stream control callbacks with LutPreviewManager
    LutPreviewManager.instance.registerStreamCallbacks(
      () async => await stopImageStream(),
      () async => await resumeImageStream(),
    );
    _loadLut();
  }

  @override
  void didUpdateWidget(SimpleLutPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lutPath != widget.lutPath ||
        oldWidget.mixStrength != widget.mixStrength) {
      if (oldWidget.lutPath != widget.lutPath) {
        _loadLut();
      } else {
        setState(() {}); // 触发重绘以更新混合强度显示
        // Stop or start stream based on strength to save CPU
        if (widget.mixStrength <= 0.0 &&
            _streaming &&
            widget.cameraController.value.isInitialized) {
          widget.cameraController.stopImageStream();
          _streaming = false;
        } else if (widget.mixStrength > 0.0) {
          _startImageStreamIfNeeded();
        }
      }
    }
  }

  Future<void> _loadLut() async {
    try {
      if (_loadedLutPath == widget.lutPath) return;

      ByteData lutData;

      // 判断是否为用户目录的文件路径还是assets路径
      if (widget.lutPath.startsWith('assets/')) {
        // assets路径，使用DefaultAssetBundle加载
        lutData = await DefaultAssetBundle.of(context).load(widget.lutPath);
      } else {
        // 用户目录的文件路径，使用File读取
        final file = File(widget.lutPath);
        final bytes = await file.readAsBytes();
        lutData = ByteData.sublistView(bytes);
      }

      final lut = await loadCubeLut(lutData);

      // 提取LUT名称
      final pathParts = widget.lutPath.split('/');
      final fileName = pathParts.last.replaceAll('.cube', '');

      setState(() {
        _currentLut = lut;
        _loadedLutPath = widget.lutPath;
        _lutName = fileName;
        _isInitialized = true;
      });

      _startImageStreamIfNeeded();
    } catch (e) {
      debugPrint('加载LUT失败: $e');
      setState(() {
        _lutName = 'Error';
        _isInitialized = true;
      });
    }
  }

  void _startImageStreamIfNeeded() {
    if (_streaming) return;
    if (!widget.cameraController.value.isInitialized) return;
    if (widget.mixStrength <= 0.0) return;

    try {
      widget.cameraController.startImageStream((image) async {
        // 以尽可能快的速度进行处理（如设备性能不足，将自然降到可承受帧率）
        if (_isProcessing) return;

        if (_currentLut == null) return;
        _isProcessing = true;
        await _processFrame(image);
        _isProcessing = false;
      });
      _streaming = true;
    } catch (e) {
      // 忽略启动时的错误
    }
  }

  /// 外部调用：停止图像流
  Future<void> stopImageStream() async {
    try {
      if (_streaming && widget.cameraController.value.isInitialized) {
        await widget.cameraController.stopImageStream();
      }
    } catch (e) {
      // 忽略停止时的错误，可能已经停止
      debugPrint('停止图像流时出错（可能已停止）: $e');
    } finally {
      _streaming = false;
    }
  }

  /// 外部调用：恢复图像流
  Future<void> resumeImageStream() async {
    if (_streaming) return;
    if (!widget.cameraController.value.isInitialized) return;
    if (widget.mixStrength <= 0.0) return;

    // 延迟一小段时间确保相机操作完成
    await Future.delayed(const Duration(milliseconds: 200));
    _startImageStreamIfNeeded();
  }

  @override
  void dispose() {
    // Unregister stream control callbacks
    LutPreviewManager.instance.unregisterStreamCallbacks();

    if (_streaming && widget.cameraController.value.isInitialized) {
      // Stop image stream; ignore errors if already stopped
      try {
        widget.cameraController.stopImageStream();
      } catch (_) {}
    }
    _streaming = false;
    _processedFrame?.dispose();
    _processedFrame = null;
    super.dispose();
  }

  Future<void> _processFrame(CameraImage image) async {
    // Downscale target for preview overlay
    final int srcW = image.width;
    final int srcH = image.height;
    // 使用相机原始分辨率进行处理（无分辨率限制）
    final int dstW = srcW;
    final int dstH = srcH;

    // Convert YUV420 to RGBA at low resolution by sampling
    final rgba = _yuv420ToRgbaDownsampled(image, dstW, dstH);

    // Apply LUT in software
    final lut = _currentLut!;
    final processor = SoftwareLutProcessor(lut);
    final mixed = processor.processImageData(rgba, dstW, dstH, widget.mixStrength);

    // Create ui.Image for fast drawing
    final uiImg = await _rgbaToUiImage(mixed, dstW, dstH);
    if (!mounted) {
      uiImg.dispose();
      return;
    }

    // Swap current frame
    _processedFrame?.dispose();
    _processedFrame = uiImg;
    _frameW = dstW;
    _frameH = dstH;
    if (mounted) setState(() {});
  }

  // Fast YUV420 -> RGBA downsampled conversion
  Uint8List _yuv420ToRgbaDownsampled(CameraImage image, int outW, int outH) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final int srcW = image.width;
    final int srcH = image.height;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final int yRowStride = yPlane.bytesPerRow;

    final out = Uint8List(outW * outH * 4);

    for (int j = 0; j < outH; j++) {
      final srcY = (j * srcH / outH).floor();
      final yIndexRow = srcY * yRowStride;
      final uvRow = (srcY ~/ 2) * uvRowStride;
      for (int i = 0; i < outW; i++) {
        final srcX = (i * srcW / outW).floor();
        final yVal = yPlane.bytes[yIndexRow + srcX];
        final uvIndex = uvRow + (srcX ~/ 2) * uvPixelStride;

        final uVal = uPlane.bytes[uvIndex];
        final vVal = vPlane.bytes[uvIndex];

        // YUV420 to RGB (BT.601)
        final y = yVal.toDouble();
        final u = uVal.toDouble() - 128.0;
        final v = vVal.toDouble() - 128.0;

        double r = y + 1.402 * v;
        double g = y - 0.344136 * u - 0.714136 * v;
        double b = y + 1.772 * u;

        // Normalize and clamp
        int ri = r.clamp(0.0, 255.0).toInt();
        int gi = g.clamp(0.0, 255.0).toInt();
        int bi = b.clamp(0.0, 255.0).toInt();

        final outIndex = (j * outW + i) * 4;
        out[outIndex] = ri;
        out[outIndex + 1] = gi;
        out[outIndex + 2] = bi;
        out[outIndex + 3] = 255;
      }
    }

    return out;
  }

  Future<ui.Image> _rgbaToUiImage(Uint8List rgba, int w, int h) async {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (img) => c.complete(img),
      rowBytes: w * 4,
    );
    return c.future;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // 创建仅包含 LUT 处理后的图像的覆盖层（不再绘制原始相机预览）
    Widget lutOverlay = Stack(
      children: [
        if (_processedFrame != null)
          Positioned.fill(
            child: _ProcessedPreviewImage(
              image: _processedFrame!,
              imageWidth: _frameW,
              imageHeight: _frameH,
            ),
          ),
        _buildLutOverlayInfo(),
      ],
    );
    // 如果有子组件（用于手势检测等），则包装它
    if (widget.child != null) {
      lutOverlay = Stack(children: [lutOverlay, widget.child!]);
    }

    // 锁定画幅：固定 4:3，不进行旋转或裁切
    const ar = 4 / 3;
    return AspectRatio(
      aspectRatio: ar,
      child: lutOverlay,
    );
  }

  Widget _buildLutOverlayInfo() {
    if (_currentLut == null || widget.mixStrength <= 0.0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 50,
      left: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: widget.mixStrength > 0.0 ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter,
                color: Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _lutName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_currentLut!.size}³',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(widget.mixStrength * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessedPreviewImage extends StatelessWidget {
  final ui.Image image;
  final int imageWidth;
  final int imageHeight;

  const _ProcessedPreviewImage({
    Key? key,
    required this.image,
    required this.imageWidth,
    required this.imageHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ProcessedFramePainter(image: image),
      isComplex: true,
      willChange: true,
    );
  }
}

class _ProcessedFramePainter extends CustomPainter {
  final ui.Image image;
  _ProcessedFramePainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final dw = size.width;
    final dh = size.height;

    // Contain-fit: 不裁切，只缩放以完整显示
    final sx = dw / iw;
    final sy = dh / ih;
    final s = sx < sy ? sx : sy;
    final drawW = iw * s;
    final drawH = ih * s;

    final dx = (dw - drawW) / 2;
    final dy = (dh - drawH) / 2;

    final paint = Paint();
    final srcRect = Rect.fromLTWH(0, 0, iw, ih);
    final dstRect = Rect.fromLTWH(dx, dy, drawW, drawH);
    canvas.drawImageRect(image, srcRect, dstRect, paint);

  }

  @override
  bool shouldRepaint(covariant _ProcessedFramePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
