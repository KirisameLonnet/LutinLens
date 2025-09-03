import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'simple_lut_preview.dart';

/// LUT实时预览管理器
class LutPreviewManager extends ChangeNotifier {
  static LutPreviewManager? _instance;
  static LutPreviewManager get instance => _instance ??= LutPreviewManager._();
  
  LutPreviewManager._();

  String? _currentLutPath;
  double _mixStrength = 1.0;
  bool _isEnabled = true;

  String? get currentLutPath => _currentLutPath;
  double get mixStrength => _mixStrength;
  bool get isEnabled => _isEnabled;

  /// 设置当前使用的LUT
  Future<void> setCurrentLut(String lutPath) async {
    _currentLutPath = lutPath;
    notifyListeners();
  }

  /// 设置LUT混合强度
  void setMixStrength(double strength) {
    _mixStrength = strength.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 启用/禁用LUT预览
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  /// 获取默认LUT路径
  Future<String> getDefaultLutPath() async {
    return 'assets/Luts/CINEMATIC_FILM/CINEMATIC_FILM.cube';
  }

  /// 创建LUT预览Widget
  Widget createPreviewWidget(
    CameraController cameraController, {
    Widget? child,
  }) {
    if (!_isEnabled || _currentLutPath == null) {
      return CameraPreview(cameraController, child: child);
    }

    return SimpleLutPreview(
      cameraController: cameraController,
      lutPath: _currentLutPath!,
      mixStrength: _mixStrength,
      child: child,
    );
  }

  /// 准备相机控制器以支持YUV420格式
  static Future<CameraController> createLutCompatibleCamera(
    CameraDescription description,
    ResolutionPreset resolution, {
    bool enableAudio = false,
  }) async {
    final controller = CameraController(
      description,
      resolution,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    return controller;
  }
}
