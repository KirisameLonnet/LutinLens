import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'simple_lut_preview.dart';
import '../utils/preferences.dart';
import '../utils/lut_manager.dart';

/// LUT实时预览管理器
class LutPreviewManager extends ChangeNotifier {
  static LutPreviewManager? _instance;
  static LutPreviewManager get instance => _instance ??= LutPreviewManager._();
  
  LutPreviewManager._();

  String? _currentLutPath;
  double _mixStrength = 1.0;
  bool _isEnabled = true;
  
  // 使用函数回调而不是直接引用来避免循环依赖
  Function()? _stopStreamCallback;
  Function()? _resumeStreamCallback;

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
    // persist
    Preferences.setLutMixStrength(_mixStrength);
    notifyListeners();
  }

  /// 启用/禁用LUT预览
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    // persist
    Preferences.setLutEnabled(_isEnabled);
    notifyListeners();
  }

  /// 获取默认LUT路径
  Future<String> getDefaultLutPath() async {
    final lutsDir = await LutManager.getUserLutsDirectory();
    return '${lutsDir.path}/CINEMATIC_FILM.cube';
  }

  /// 创建LUT预览Widget
  Widget createPreviewWidget(
    CameraController cameraController, {
    Widget? child,
    bool isRearCamera = true,
  }) {
    if (!_isEnabled || _currentLutPath == null) {
      return CameraPreview(cameraController, child: child);
    }

    return SimpleLutPreview(
      cameraController: cameraController,
      lutPath: _currentLutPath!,
      mixStrength: _mixStrength,
      child: child,
      isRearCamera: isRearCamera,
    );
  }

  /// 注册流控制回调（由SimpleLutPreview调用）
  void registerStreamCallbacks(Function() stopCallback, Function() resumeCallback) {
    _stopStreamCallback = stopCallback;
    _resumeStreamCallback = resumeCallback;
  }

  /// 取消注册流控制回调
  void unregisterStreamCallbacks() {
    _stopStreamCallback = null;
    _resumeStreamCallback = null;
  }

  /// 从偏好中恢复混合强度与启用状态
  Future<void> initializeFromPreferences() async {
    try {
      _mixStrength = Preferences.getLutMixStrength();
      _isEnabled = Preferences.getLutEnabled();
      notifyListeners();
    } catch (_) {
      // ignore preference errors
    }
  }

  /// 停止图像流（在拍照/录制前调用）
  Future<void> stopImageStream() async {
    try {
      _stopStreamCallback?.call();
    } catch (e) {
      print('停止图像流时出错: $e');
    }
  }

  /// 恢复图像流（在拍照/录制后调用）
  Future<void> resumeImageStream() async {
    try {
      _resumeStreamCallback?.call();
    } catch (e) {
      print('恢复图像流时出错: $e');
    }
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
