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
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);
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
        if (widget.mixStrength <= 0.0 && _streaming && widget.cameraController.value.isInitialized) {
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
      print('加载LUT失败: $e');
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
        final now = DateTime.now();
        // Process at ~6 fps to reduce load
        if (_isProcessing || now.difference(_lastFrameTime).inMilliseconds < 160) return;
        _lastFrameTime = now;

        if (_currentLut == null) return;
        _isProcessing = true;
        try {
          await _processFrame(image);
        } catch (_) {
          // swallow frame errors
        } finally {
          _isProcessing = false;
        }
      });
      _streaming = true;
    } catch (e) {
      print('启动图像流失败: $e');
    }
  }

  /// 外部调用：停止图像流
  Future<void> stopImageStream() async {
    if (!_streaming) return;
    
    try {
      if (widget.cameraController.value.isInitialized) {
        await widget.cameraController.stopImageStream();
      }
    } catch (e) {
      // 忽略停止时的错误，可能已经停止
      print('停止图像流时出错（可能已停止）: $e');
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
      } catch (e) {
        // 忽略停止时的错误
      }
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
    final int targetMax = 360; // keep small for performance
    final double scale = (srcW > srcH)
        ? (targetMax / srcW)
        : (targetMax / srcH);
    final int dstW = (srcW * scale).round().clamp(80, targetMax);
    final int dstH = (srcH * scale).round().clamp(80, targetMax);

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

    // 基础相机预览
    Widget preview = CameraPreview(widget.cameraController);
    
    // 创建LUT信息覆盖层 + 图像覆盖效果
    Widget lutOverlay = Stack(
      children: [
        if (_processedFrame != null)
          Positioned.fill(
            child: _ProcessedPreviewImage(
              image: _processedFrame!,
              imageWidth: _frameW,
              imageHeight: _frameH,
              cameraController: widget.cameraController,
              isRearCamera: widget.isRearCamera,
            ),
          ),
        _buildLutOverlayInfo(),
      ],
    );
    
    // 组合预览和覆盖层
    preview = Stack(
      children: [
        preview,
        lutOverlay,
      ],
    );
    
    // 如果有子组件（用于手势检测等），则包装它
    if (widget.child != null) {
      return Stack(
        children: [
          preview,
          widget.child!,
        ],
      );
    }
    
    return preview;
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
              Icon(
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

/// Paint the processed low-res frame scaled to fill while preserving aspect.
class _ProcessedPreviewImage extends StatelessWidget {
  final ui.Image image;
  final int imageWidth;
  final int imageHeight;
  final CameraController cameraController;
  final bool isRearCamera;

  const _ProcessedPreviewImage({
    Key? key,
    required this.image,
    required this.imageWidth,
    required this.imageHeight,
    required this.cameraController,
    required this.isRearCamera,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ProcessedFramePainter(
        image, 
        cameraController, 
        isRearCamera
      ),
      isComplex: true,
      willChange: true,
    );
  }
}

class _ProcessedFramePainter extends CustomPainter {
  final ui.Image image;
  final CameraController cameraController;
  final bool isRearCamera;
  
  _ProcessedFramePainter(this.image, this.cameraController, this.isRearCamera);

  @override
  void paint(Canvas canvas, Size size) {
    final srcW = image.width.toDouble();
    final srcH = image.height.toDouble();
    final dstW = size.width;
    final dstH = size.height;

    // 保存画布状态
    canvas.save();

    // 获取设备方向
    final deviceOrientation = cameraController.value.deviceOrientation;
    
    // 计算旋转角度和镜像
    double rotationAngle = 0.0;
    bool needsHorizontalFlip = false;
    bool needsVerticalFlip = false;

    // 根据设备方向确定旋转角度
    switch (deviceOrientation) {
      case DeviceOrientation.portraitUp:
        rotationAngle = 0.0;
        break;
      case DeviceOrientation.landscapeLeft:
        rotationAngle = -90.0;
        break;
      case DeviceOrientation.portraitDown:
        rotationAngle = 180.0;
        break;
      case DeviceOrientation.landscapeRight:
        rotationAngle = 90.0;
        break;
    }

    // 前置摄像头需要水平镜像
    if (!isRearCamera) {
      needsHorizontalFlip = true;
    }

    // 应用变换
    final centerX = dstW / 2;
    final centerY = dstH / 2;

    // 移动到中心点
    canvas.translate(centerX, centerY);

    // 应用旋转
    if (rotationAngle != 0.0) {
      canvas.rotate(rotationAngle * 3.14159 / 180.0);
    }

    // 应用镜像
    if (needsHorizontalFlip || needsVerticalFlip) {
      canvas.scale(
        needsHorizontalFlip ? -1.0 : 1.0,
        needsVerticalFlip ? -1.0 : 1.0,
      );
    }

    // 移回原点
    canvas.translate(-centerX, -centerY);

    // Cover fit with aspect ratio preserved
    final srcAspect = srcW / srcH;
    final dstAspect = dstW / dstH;
    Rect srcRect;
    if (dstAspect > srcAspect) {
      // crop height
      final drawH = srcW / dstAspect;
      final top = (srcH - drawH) / 2.0;
      srcRect = Rect.fromLTWH(0, top, srcW, drawH);
    } else {
      // crop width
      final drawW = srcH * dstAspect;
      final left = (srcW - drawW) / 2.0;
      srcRect = Rect.fromLTWH(left, 0, drawW, srcH);
    }
    final dstRect = Rect.fromLTWH(0, 0, dstW, dstH);

    final paint = Paint();
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    // 恢复画布状态
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProcessedFramePainter oldDelegate) {
    return oldDelegate.image != image ||
           oldDelegate.cameraController.value.deviceOrientation != 
           cameraController.value.deviceOrientation ||
           oldDelegate.isRearCamera != isRearCamera;
  }
}
