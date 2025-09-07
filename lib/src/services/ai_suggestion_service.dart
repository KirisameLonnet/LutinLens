import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../utils/preferences.dart';

class AiSuggestionService extends ChangeNotifier {
  static final AiSuggestionService _instance = AiSuggestionService._internal();
  factory AiSuggestionService() => _instance;
  AiSuggestionService._internal();

  Timer? _uploadTimer;
  Timer? _hideTimer;
  String _sessionId = '';
  String _currentLutSuggestion = '正在分析场景...';
  String _currentFramingSuggestion = '正在分析场景...';
  bool _isUploading = false;
  int _readyToShoot = 0;
  CameraController? _cameraController;

  String get sessionId => _sessionId;
  String get currentLutSuggestion => _currentLutSuggestion;
  String get currentFramingSuggestion => _currentFramingSuggestion;
  bool get isUploading => _isUploading;
  int get readyToShoot => _readyToShoot;

  // 兼容旧代码的getter
  String get currentSuggestion => _currentFramingSuggestion;

  void startService(CameraController? controller) async {
    if (!Preferences.getAiSuggestionEnabled()) {
      return;
    }

    _cameraController = controller;
    _sessionId = const Uuid().v4();
    _currentLutSuggestion = '正在分析场景...';
    _currentFramingSuggestion = '正在分析场景...';
    
    // 检查所有必要的API配置
    final imageUploadUrl = Preferences.getAiImageUploadUrl();
    final lutSuggestionUrl = Preferences.getAiLutSuggestionUrl();
    final framingSuggestionUrl = Preferences.getAiFramingSuggestionUrl();
    
    if (imageUploadUrl.isNotEmpty && lutSuggestionUrl.isNotEmpty && framingSuggestionUrl.isNotEmpty) {
      // 每3秒执行完整的业务流程
      _uploadTimer?.cancel();
      _uploadTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _uploadCurrentFrame();
      });
      
      debugPrint('[AI] AI建议服务已启动，Session ID: $_sessionId');
    } else {
      debugPrint('[AI] API配置不完整，请在设置中配置所有API地址');
      _currentLutSuggestion = 'API配置不完整';
      _currentFramingSuggestion = 'API配置不完整';
      notifyListeners();
    }
  }

  void stopService() async {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
    _cameraController = null;
    _currentLutSuggestion = '服务已停止';
    _currentFramingSuggestion = '服务已停止';
    
    notifyListeners();
    debugPrint('[AI] AI建议服务已停止');
  }

  void updateCameraController(CameraController? controller) {
    _cameraController = controller;
  }

  Future<void> _uploadCurrentFrame() async {
    if (_isUploading || 
        _cameraController == null || 
        !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      _isUploading = true;
      notifyListeners();

      // 执行完整的业务流程
      await _executeFullWorkflow();
      
    } catch (e) {
      debugPrint('[AI] 上传图像失败: $e');
      _currentLutSuggestion = '连接服务器失败';
      _currentFramingSuggestion = '连接服务器失败';
      notifyListeners();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// 执行完整的AI业务流程
  Future<void> _executeFullWorkflow() async {
    try {
      // 第一步：捕获当前帧
      final XFile imageFile = await _cameraController!.takePicture();
      final Uint8List originalImageBytes = await imageFile.readAsBytes();
      
      // 第二步：生成新的UUID文件名（每次都生成新的）
      final String uuid = const Uuid().v4();
      final String fileName = '$uuid.jpg';
      
      // 第三步：压缩图片到540p分辨率和100KB以下
      final Uint8List compressedImageBytes = await _compressImage(originalImageBytes);
      debugPrint('[AI] 图片压缩完成，原始大小: ${originalImageBytes.length}字节, 压缩后: ${compressedImageBytes.length}字节');
      
      // 第四步：上传图片到图床服务
      final String imageUrl = await _uploadImageToServer(compressedImageBytes, fileName);
      debugPrint('[AI] 图片上传成功: $imageUrl');
      
      // 第五步：并行请求LUT建议和取景建议
      final Future<String> lutFuture = _requestLutSuggestion(imageUrl);
      final Future<Map<String, dynamic>> framingFuture = _requestFramingSuggestion(imageUrl);
      
      final List<dynamic> results = await Future.wait([lutFuture, framingFuture]);
      
      final String lutSuggestion = results[0] as String;
      final Map<String, dynamic> framingResult = results[1] as Map<String, dynamic>;
      
      // 更新UI
      _currentLutSuggestion = 'LUT建议: $lutSuggestion';
      _currentFramingSuggestion = framingResult['suggestion'] ?? '无建议';
      _readyToShoot = framingResult['ready_to_shot'] ?? 0;
      
      debugPrint('[AI] LUT建议: $lutSuggestion, 取景建议: ${_currentFramingSuggestion}, ready_to_shot: $_readyToShoot');
      
      // 如果不是ready_to_shoot状态，1.5秒后隐藏建议
      if (_readyToShoot != 1) {
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(milliseconds: 1500), () {
          if (_readyToShoot != 1) {
            _currentLutSuggestion = '正在分析场景...';
            _currentFramingSuggestion = '正在分析场景...';
            notifyListeners();
          }
        });
      }
      
    } catch (e) {
      debugPrint('[AI] 执行完整流程失败: $e');
      _currentLutSuggestion = '处理失败: $e';
      _currentFramingSuggestion = '处理失败: $e';
    }
    
    notifyListeners();
  }

  /// 压缩图片到540p分辨率和100KB以下
  Future<Uint8List> _compressImage(Uint8List originalBytes) async {
    try {
      // 设置目标参数
      const int targetWidth = 960;  // 540p通常指的是960x540
      const int targetHeight = 540;
      const int maxSizeKB = 100;
      const int maxSizeBytes = maxSizeKB * 1024;
      
      // 初始质量设置
      int quality = 85;
      Uint8List compressedBytes = originalBytes;
      
      // 第一步：先压缩分辨率
      compressedBytes = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      
      // 第二步：如果文件仍然太大，循环降低质量
      while (compressedBytes.length > maxSizeBytes && quality > 10) {
        quality -= 10; // 降低质量
        
        compressedBytes = await FlutterImageCompress.compressWithList(
          originalBytes,
          minWidth: targetWidth,
          minHeight: targetHeight,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        
        debugPrint('[AI] 压缩质量调整: $quality, 当前大小: ${compressedBytes.length}字节');
      }
      
      debugPrint('[AI] 图片压缩完成: 质量=$quality, 大小=${compressedBytes.length}字节 (${(compressedBytes.length/1024).toStringAsFixed(1)}KB)');
      return compressedBytes;
      
    } catch (e) {
      debugPrint('[AI] 图片压缩失败: $e');
      // 压缩失败时返回原始图片
      return originalBytes;
    }
  }

  /// 上传图片到8003端口的图床服务
  Future<String> _uploadImageToServer(Uint8List imageBytes, String fileName) async {
    final String uploadUrl = Preferences.getAiImageUploadUrl();
    final Uri uri = Uri.parse('$uploadUrl/$fileName');
    
    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/octet-stream',
      },
      body: imageBytes,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return '$uploadUrl/$fileName';
    } else {
      throw Exception('图片上传失败: ${response.statusCode}');
    }
  }

  /// 请求LUT建议（8000端口）
  Future<String> _requestLutSuggestion(String imageUrl) async {
    final String apiUrl = Preferences.getAiLutSuggestionUrl();
    
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'input_message': imageUrl,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      return responseData['value']?.toString() ?? '无建议';
    } else {
      throw Exception('LUT建议请求失败: ${response.statusCode}');
    }
  }

  /// 请求取景建议（8001端口）
  Future<Map<String, dynamic>> _requestFramingSuggestion(String imageUrl) async {
    final String apiUrl = Preferences.getAiFramingSuggestionUrl();
    
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'img': imageUrl,
        'session_id': _sessionId,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final responseBody = response.body;
      
      // 尝试解析JSON，如果失败则作为纯文本处理
      try {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (e) {
        // 如果响应是纯文本，包装成标准格式
        return {
          'suggestion': responseBody,
          'ready_to_shot': 0,
        };
      }
    } else {
      throw Exception('取景建议请求失败: ${response.statusCode}');
    }
  }
}
