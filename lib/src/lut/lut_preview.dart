import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// TODO: 实现OpenGL ES的实时LUT预览
// import 'package:flutter_gl/flutter_gl.dart';
import 'cube_loader.dart';

/// 基于OpenGL ES的实时LUT预览组件
/// 暂时使用简单的相机预览，稍后实现OpenGL LUT处理
class LutPreview extends StatefulWidget {
  final CameraController cameraController;
  final String lutPath;
  final double mixStrength;
  final Widget? child;

  const LutPreview({
    super.key,
    required this.cameraController,
    required this.lutPath,
    required this.mixStrength,
    this.child,
  });

  @override
  State<LutPreview> createState() => _LutPreviewState();
}

class _LutPreviewState extends State<LutPreview> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    // TODO: 清理OpenGL资源
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // TODO: 初始化OpenGL ES环境
      setState(() => _isInitialized = true);
    } catch (e) {
      print('LUT预览初始化失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // TODO: 实现OpenGL纹理渲染
    // 暂时返回普通的相机预览
    return Stack(
      children: [
        if (widget.cameraController.value.isInitialized)
          CameraPreview(widget.cameraController),
        if (widget.child != null) widget.child!,
        // 显示当前LUT和混合强度信息
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LUT: ${widget.lutPath.split('/').last}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Mix: ${(widget.mixStrength * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
  

  int _buildShaderProgram(String source) {
    // 分离顶点和片段着色器
    final vertexSource = source.split('#ifdef FRAG')[0].replaceAll('#ifdef VERT', '').replaceAll('#endif', '');
    final fragmentSource = source.split('#ifdef VERT')[1].split('#ifdef FRAG')[1].replaceAll('#endif', '');

    final vertexShader = _compileShader(vertexSource, gl.GL_VERTEX_SHADER);
    final fragmentShader = _compileShader(fragmentSource, gl.GL_FRAGMENT_SHADER);

    final program = gl.glCreateProgram();
    gl.glAttachShader(program, vertexShader);
    gl.glAttachShader(program, fragmentShader);
    gl.glLinkProgram(program);

    // 检查链接状态
    final linkStatus = gl.glGetProgramParameter(program, gl.GL_LINK_STATUS);
    if (linkStatus == 0) {
      final log = gl.glGetProgramInfoLog(program);
      print('着色器程序链接失败: $log');
      gl.glDeleteProgram(program);
      throw Exception('着色器程序链接失败');
    }

    return program;
  }

  int _compileShader(String source, int type) {
    final shader = gl.glCreateShader(type);
    gl.glShaderSource(shader, source);
    gl.glCompileShader(shader);

    final compileStatus = gl.glGetShaderParameter(shader, gl.GL_COMPILE_STATUS);
    if (compileStatus == 0) {
      final log = gl.glGetShaderInfoLog(shader);
      print('着色器编译失败: $log');
      gl.glDeleteShader(shader);
      throw Exception('着色器编译失败');
    }

    return shader;
  }

  void _initializeQuad() {
    // 全屏四边形的顶点数据
    final vertices = Float32List.fromList([
      -1.0, -1.0,
       3.0, -1.0,
      -1.0,  3.0,
    ]);

    final buffer = gl.glCreateBuffer();
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, buffer);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, vertices.lengthInBytes, vertices, gl.GL_STATIC_DRAW);
    
    gl.glEnableVertexAttribArray(0);
    gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, false, 0, 0);
  }

  int _createTexture2D() {
    final texture = gl.glCreateTexture();
    gl.glBindTexture(gl.GL_TEXTURE_2D, texture);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    return texture;
  }

  int _uploadLut3D(Float32List data, int size) {
    final texture = gl.glCreateTexture();
    gl.glBindTexture(gl.GL_TEXTURE_3D, texture);
    
    gl.glTexParameteri(gl.GL_TEXTURE_3D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_3D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_3D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_3D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_3D, gl.GL_TEXTURE_WRAP_R, gl.GL_CLAMP_TO_EDGE);

    gl.texImage3D(
      gl.GL_TEXTURE_3D,
      0,
      gl.GL_RGB32F,
      size,
      size,
      size,
      0,
      gl.GL_RGB,
      gl.GL_FLOAT,
      data,
    );

    return texture;
  }

  void _updateYUVTextures(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    _updateTexture2D(textureY!, yPlane.bytes, image.width, image.height);
    _updateTexture2D(textureU!, uPlane.bytes, image.width ~/ 2, image.height ~/ 2);
    _updateTexture2D(textureV!, vPlane.bytes, image.width ~/ 2, image.height ~/ 2);
  }

  void _updateTexture2D(int texture, Uint8List data, int width, int height) {
    gl.glBindTexture(gl.GL_TEXTURE_2D, texture);
    gl.texImage2D(
      gl.GL_TEXTURE_2D,
      0,
      gl.GL_LUMINANCE,
      width,
      height,
      0,
      gl.GL_LUMINANCE,
      gl.GL_UNSIGNED_BYTE,
      data,
    );
  }

  void _render() {
    gl.glViewport(0, 0, width, height);
    gl.useProgram(shaderProgram!);

    // 绑定YUV纹理
    gl.activeTexture(gl.GL_TEXTURE0);
    gl.bindTexture(gl.GL_TEXTURE_2D, textureY!);
    gl.uniform1i(gl.getUniformLocation(shaderProgram!, 'uY'), 0);

    gl.activeTexture(gl.GL_TEXTURE1);
    gl.bindTexture(gl.GL_TEXTURE_2D, textureU!);
    gl.uniform1i(gl.getUniformLocation(shaderProgram!, 'uU'), 1);

    gl.activeTexture(gl.GL_TEXTURE2);
    gl.bindTexture(gl.GL_TEXTURE_2D, textureV!);
    gl.uniform1i(gl.getUniformLocation(shaderProgram!, 'uV'), 2);

    // 绑定LUT纹理
    gl.activeTexture(gl.GL_TEXTURE3);
    gl.bindTexture(gl.GL_TEXTURE_3D, textureLut!);
    gl.uniform1i(gl.getUniformLocation(shaderProgram!, 'uLut'), 3);

    // 设置混合强度
    gl.uniform1f(gl.getUniformLocation(shaderProgram!, 'uMix'), mixStrength);

    // 渲染
    gl.drawArrays(gl.GL_TRIANGLES, 0, 3);
    gl.glFlush();
    gl.updateTexture(gl.framebuffer!);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget lutTexture = Texture(textureId: gl.textureId!);
    
    // 如果有子组件（用于手势检测等），则包装它
    if (widget.child != null) {
      return Stack(
        children: [
          lutTexture,
          widget.child!,
        ],
      );
    }
    
    return lutTexture;
  }
}
