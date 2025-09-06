import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// 应用内嵌的AI测试服务器
/// 
/// ⚠️ 这是纯测试功能：
/// - 不分析任何图像内容
/// - 不进行真实的AI处理
/// - 仅返回固定的测试响应序列
/// - 用于测试AI建议UI和网络请求流程
/// 
/// 测试序列：向左移动 → 绿色对勾 → 向右移动 (循环)
class EmbeddedAiServer {
  static const int port = 1234;
  static const String host = '127.0.0.1';
  
  HttpServer? _server;
  int _requestCount = 0;
  bool _isRunning = false;
  
  // 预定义的建议响应序列 - 严格按照测试要求：向左移动 → 绿色对勾 → 向右移动
  final List<Map<String, dynamic>> _responses = [
    {
      'suggestion': '向左移动相机以获得更好的构图',
      'ready_to_shoot': 0,
    },
    {
      'suggestion': '完美！现在可以拍摄了',
      'ready_to_shoot': 1,
    },
    {
      'suggestion': '向右移动相机调整拍摄角度',
      'ready_to_shoot': 0,
    },
  ];

  bool get isRunning => _isRunning;
  String get serverUrl => 'http://$host:$port';

  /// 启动内嵌服务器
  Future<bool> start() async {
    if (_isRunning) {
      debugPrint('[内嵌服务器] 服务器已在运行中');
      return true;
    }

    try {
      _server = await HttpServer.bind(host, port);
      _isRunning = true;
      _requestCount = 0;
      
      debugPrint('[内嵌服务器] ✅ 启动成功');
      debugPrint('[内嵌服务器] 📍 地址: $serverUrl');
      debugPrint('[内嵌服务器] 📡 API端点: POST /ai/suggestion');

      // 监听请求
      _server!.listen(_handleRequest);
      
      return true;
    } catch (e) {
      _isRunning = false;
      debugPrint('[内嵌服务器] ❌ 启动失败: $e');
      
      if (e.toString().contains('Address already in use')) {
        debugPrint('[内嵌服务器] 💡 端口 $port 已被占用');
      }
      
      return false;
    }
  }

  /// 停止服务器
  Future<void> stop() async {
    if (!_isRunning) {
      debugPrint('[内嵌服务器] 服务器未运行');
      return;
    }

    try {
      await _server?.close();
      _server = null;
      _isRunning = false;
      debugPrint('[内嵌服务器] 🛑 服务器已停止');
    } catch (e) {
      debugPrint('[内嵌服务器] ❌ 停止服务器失败: $e');
    }
  }

  /// 处理HTTP请求
  void _handleRequest(HttpRequest request) async {
    // 设置CORS头
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type');

    debugPrint('[内嵌服务器] 📨 ${request.method} ${request.uri.path} (请求 #${++_requestCount})');

    try {
      if (request.method == 'OPTIONS') {
        // 处理预检请求
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/ai/suggestion') {
        await _handleAiSuggestion(request);
      } else {
        // 404 Not Found
        await _sendErrorResponse(request, HttpStatus.notFound, 'Not Found', '端点不存在');
      }
    } catch (e) {
      debugPrint('[内嵌服务器] ❌ 处理请求失败: $e');
      await _sendErrorResponse(request, HttpStatus.internalServerError, 'Internal Server Error', '服务器内部错误');
    }
  }

  /// 处理AI建议请求
  Future<void> _handleAiSuggestion(HttpRequest request) async {
    try {
      // 读取请求体
      final String content = await utf8.decoder.bind(request).join();
      
      Map<String, dynamic> requestData = {};
      if (content.isNotEmpty) {
        try {
          requestData = jsonDecode(content);
        } catch (e) {
          debugPrint('[内嵌服务器] ⚠️ JSON解析失败: $e');
        }
      }

      final String sessionId = requestData['session_id'] ?? 'unknown';
      final String imageData = requestData['img'] ?? '';
      
      debugPrint('[内嵌服务器] 🔑 Session: $sessionId');
      debugPrint('[内嵌服务器] 📷 图片数据: ${imageData.isNotEmpty ? "已接收 (${imageData.length}字符)" : "未收到图片"}');
      
      // 检查是否收到图片数据
      if (imageData.isEmpty) {
        debugPrint('[内嵌服务器] ❌ 错误：未收到图片数据');
        await _sendNoImageResponse(request, sessionId);
        return;
      }
      
      debugPrint('[内嵌服务器] ⚠️ 注意：这是测试模式，不分析图像内容');

      // 根据请求次数循环返回固定的测试序列（不处理图像）
      final responseIndex = (_requestCount - 1) % _responses.length;
      final responseData = Map<String, dynamic>.from(_responses[responseIndex]);

      // 添加响应元数据
      responseData['server_time'] = DateTime.now().toIso8601String();
      responseData['request_id'] = _requestCount;
      responseData['session_id'] = sessionId;
      responseData['server_type'] = 'embedded';

      // 发送响应
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(responseData));
      await request.response.close();

      debugPrint('[内嵌服务器] ✅ 响应: ${responseData['suggestion']}');
      debugPrint('[内嵌服务器] 🎯 Ready to shoot: ${responseData['ready_to_shoot']}');

    } catch (e) {
      debugPrint('[内嵌服务器] ❌ AI建议处理失败: $e');
      await _sendErrorResponse(request, HttpStatus.badRequest, 'Bad Request', '请求处理失败');
    }
  }

  /// 发送错误响应
  Future<void> _sendErrorResponse(HttpRequest request, int statusCode, String error, String message) async {
    try {
      request.response.statusCode = statusCode;
      request.response.headers.contentType = ContentType.json;
      
      final errorResponse = {
        'error': error,
        'message': message,
        'server_type': 'embedded',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 对于AI建议端点的错误，也提供默认建议
      if (request.uri.path == '/ai/suggestion') {
        errorResponse['suggestion'] = '请检查网络连接';
        errorResponse['ready_to_shoot'] = 0 as dynamic;
      }
      
      request.response.write(jsonEncode(errorResponse));
      await request.response.close();
    } catch (e) {
      debugPrint('[内嵌服务器] ❌ 发送错误响应失败: $e');
    }
  }

  /// 发送无图片数据的响应
  Future<void> _sendNoImageResponse(HttpRequest request, String sessionId) async {
    try {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      
      final noImageResponse = {
        'error': 'No Image Data',
        'message': '未收到图片数据',
        'suggestion': '请确保正确发送图片数据到服务器',
        'ready_to_shoot': 0 as dynamic,
        'server_type': 'embedded',
        'session_id': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
        'request_id': _requestCount,
      };
      
      request.response.write(jsonEncode(noImageResponse));
      await request.response.close();
      
      debugPrint('[内嵌服务器] 📤 已发送无图片响应');
    } catch (e) {
      debugPrint('[内嵌服务器] ❌ 发送无图片响应失败: $e');
    }
  }

  /// 获取服务器状态信息
  Map<String, dynamic> getStatus() {
    return {
      'running': _isRunning,
      'url': serverUrl,
      'port': port,
      'requests_handled': _requestCount,
      'responses_available': _responses.length,
    };
  }
}
