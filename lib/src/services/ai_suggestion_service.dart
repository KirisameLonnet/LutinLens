import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../utils/preferences.dart';
import 'embedded_ai_server.dart';

class AiSuggestionService extends ChangeNotifier {
  static final AiSuggestionService _instance = AiSuggestionService._internal();
  factory AiSuggestionService() => _instance;
  AiSuggestionService._internal();

  Timer? _uploadTimer;
  Timer? _hideTimer;
  Timer? _testModeTimer;
  String _sessionId = '';
  String _currentSuggestion = '正在分析场景...';
  bool _isUploading = false;
  int _readyToShoot = 0;
  int _testModeStep = 0; // 测试模式步骤：0=向左移动, 1=绿色对勾, 2=向右移动
  CameraController? _cameraController;
  
  // 内嵌AI服务器
  final EmbeddedAiServer _embeddedServer = EmbeddedAiServer();

  String get sessionId => _sessionId;
  String get currentSuggestion => _currentSuggestion;
  bool get isUploading => _isUploading;
  int get readyToShoot => _readyToShoot;

  void startService(CameraController? controller) async {
    if (!Preferences.getAiSuggestionEnabled()) {
      return;
    }

    _cameraController = controller;
    _sessionId = const Uuid().v4();
    _currentSuggestion = '正在分析场景...';
    _testModeStep = 0;
    
    // 检查是否为测试模式
    if (Preferences.getAiTestMode()) {
      debugPrint('[AI] 启动测试模式');
      
      // 启动内嵌服务器
      final serverStarted = await _embeddedServer.start();
      if (serverStarted) {
        // 使用内嵌服务器地址
        await Preferences.setAiServerUrl(_embeddedServer.serverUrl);
        debugPrint('[AI] 内嵌服务器已启动: ${_embeddedServer.serverUrl}');
        
        // 每3秒向内嵌服务器发送请求
        _uploadTimer?.cancel();
        _uploadTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          _uploadCurrentFrame();
        });
      } else {
        // 内嵌服务器启动失败，使用本地模拟
        debugPrint('[AI] 内嵌服务器启动失败，使用本地模拟');
        _startTestMode();
      }
    } else {
      // 普通模式
      final serverUrl = Preferences.getAiServerUrl();
      if (serverUrl.isNotEmpty) {
        // 停止内嵌服务器（如果正在运行）
        await _embeddedServer.stop();
        
        // 每3秒上传一次
        _uploadTimer?.cancel();
        _uploadTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          _uploadCurrentFrame();
        });
      }
    }
    
    debugPrint('[AI] AI建议服务已启动，Session ID: $_sessionId, 测试模式: ${Preferences.getAiTestMode()}');
  }

  void stopService() async {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
    _testModeTimer?.cancel();
    _testModeTimer = null;
    _cameraController = null;
    _currentSuggestion = '服务已停止';
    
    // 停止内嵌服务器
    await _embeddedServer.stop();
    
    notifyListeners();
    debugPrint('[AI] AI建议服务已停止');
  }

  void updateCameraController(CameraController? controller) {
    _cameraController = controller;
  }

  Future<void> _uploadCurrentFrame() async {
    if (_isUploading || 
        _cameraController == null || 
        !_cameraController!.value.isInitialized ||
        Preferences.getAiServerUrl().isEmpty) {
      return;
    }

    try {
      _isUploading = true;
      notifyListeners();

      // 使用预览帧而不是拍照来避免与正常拍照功能冲突
      // 这里我们模拟一个低分辨率图像，实际实现中需要从相机预览流中获取
      // TODO: 实现从预览流中捕获帧的功能
      
      // 暂时跳过实际图像捕获，发送测试图片数据
      final Map<String, dynamic> payload = {
        'session_id': _sessionId,
        'img': 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//gA+Q1JFQVRPUjogZ2QtanBlZyB2MS4wICh1c2luZyBJSkcgSlBFRyB2NjIpLCBkZWZhdWx0IHF1YWxpdHkK/9sAQwAIBgYHBgUIBwcHCQkICgwUDQwLCwwZEhMPFB0aHx4dGhwcICQuJyAiLCMcHCg3KSwwMTQ0NB8nOT04MjwuMzQy/9sAQwEJCQkMCwwYDQ0YMiEcITIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy/8AAEQgAeAB4AwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIoGRMqGxwRTBUtHhCLHhMkMVovAICcTUctJTNFKBo7LDByY1NzM2R0hJSj8fHy4+MjI2Qk4uHQIiLFk7LSw0PSUqcEhqLFo7LyUqcEgqLFo7QkQuL1RJaSxaO0JELi9USWksWjtCRC4vVElpLFo7QkQuL1RJaSxaO0JELi9USWksWjtCRC4vVElpLFo7QkQuL1RJZzRHaEi', // 测试用的图片base64数据
      };

      // 发送到服务器
      await _sendToServer(payload);
    } catch (e) {
      debugPrint('[AI] 上传图像失败: $e');
      _currentSuggestion = '连接服务器失败';
      notifyListeners();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> _sendToServer(Map<String, dynamic> payload) async {
    final String serverUrl = Preferences.getAiServerUrl();
    
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/ai/suggestion'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String suggestion = responseData['suggestion'] ?? '无建议';
        final int readyToShoot = responseData['ready_to_shoot'] ?? 0;
        
        _currentSuggestion = suggestion;
        _readyToShoot = readyToShoot;
        debugPrint('[AI] 收到建议: $suggestion (ready_to_shoot: $readyToShoot)');
        
        // 如果不是ready_to_shoot状态，1.5秒后隐藏建议
        if (_readyToShoot != 1) {
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(milliseconds: 1500), () {
            if (_readyToShoot != 1) { // 再次检查，避免在这期间状态改变
              _currentSuggestion = '正在分析场景...';
              notifyListeners();
            }
          });
        }
      } else {
        _currentSuggestion = '服务器响应错误 (${response.statusCode})';
        debugPrint('[AI] 服务器错误: ${response.statusCode}');
      }
    } on TimeoutException {
      _currentSuggestion = '服务器响应超时';
      debugPrint('[AI] 请求超时');
    } on SocketException {
      _currentSuggestion = '无法连接到服务器';
      debugPrint('[AI] 网络连接失败');
    } catch (e) {
      _currentSuggestion = '网络错误';
      debugPrint('[AI] 网络错误: $e');
    }
    
    notifyListeners();
  }

  // 测试模式相关方法
  void _startTestMode() {
    _testModeTimer?.cancel();
    _testModeStep = 0;
    
    // 每5秒切换一次测试状态：向左移动 → 绿色对勾 → 向右移动 → 重复
    _testModeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _simulateTestResponse();
    });
    
    // 立即执行第一次模拟响应
    _simulateTestResponse();
    
    debugPrint('[AI] 测试模式已启动');
  }
  
  void _simulateTestResponse() {
    debugPrint('[AI] 执行本地测试步骤: $_testModeStep');
    
    switch (_testModeStep) {
      case 0:
        // 向左移动建议
        _currentSuggestion = '向左移动相机以获得更好的构图';
        _readyToShoot = 0;
        debugPrint('[AI] 测试模式: 向左移动建议');
        break;
      case 1:
        // 绿色对勾状态
        _currentSuggestion = '完美！现在可以拍摄了';
        _readyToShoot = 1;
        debugPrint('[AI] 测试模式: 准备拍摄 (绿色对勾)');
        break;
      case 2:
        // 向右移动建议
        _currentSuggestion = '向右移动相机调整拍摄角度';
        _readyToShoot = 0;
        debugPrint('[AI] 测试模式: 向右移动建议');
        break;
    }
    
    // 循环步骤
    _testModeStep = (_testModeStep + 1) % 3;
    
    // 如果不是ready_to_shoot状态，1.5秒后隐藏建议
    if (_readyToShoot != 1) {
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 1500), () {
        if (_readyToShoot != 1) {
          _currentSuggestion = '正在分析场景...';
          notifyListeners();
        }
      });
    }
    
    notifyListeners();
  }
  
  // 获取内嵌服务器状态
  Map<String, dynamic> getEmbeddedServerStatus() {
    return _embeddedServer.getStatus();
  }
  
  // 检查是否使用内嵌服务器
  bool get isUsingEmbeddedServer => Preferences.getAiTestMode() && _embeddedServer.isRunning;
}
