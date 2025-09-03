import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'cube_loader.dart';

/// 增强版的LUT预览组件，包含视觉指示器
class SimpleLutPreview extends StatefulWidget {
  final CameraController cameraController;
  final String lutPath;
  final double mixStrength;
  final Widget? child;

  const SimpleLutPreview({
    super.key,
    required this.cameraController,
    required this.lutPath,
    required this.mixStrength,
    this.child,
  });

  @override
  State<SimpleLutPreview> createState() => _SimpleLutPreviewState();
}

class _SimpleLutPreviewState extends State<SimpleLutPreview> {
  CubeLut? _currentLut;
  bool _isInitialized = false;
  String? _loadedLutPath;
  String _lutName = '';

  @override
  void initState() {
    super.initState();
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
      }
    }
  }

  Future<void> _loadLut() async {
    try {
      if (_loadedLutPath == widget.lutPath) return;
      
      final lutData = await DefaultAssetBundle.of(context).load(widget.lutPath);
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
    } catch (e) {
      print('加载LUT失败: $e');
      setState(() {
        _lutName = 'Error';
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // 基础相机预览
    Widget preview = CameraPreview(widget.cameraController);
    
    // 创建LUT信息覆盖层
    Widget lutOverlay = _buildLutOverlay();
    
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

  Widget _buildLutOverlay() {
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
