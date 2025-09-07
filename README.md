# LutinLens

<div align="center">

*AI驱动的智能相机应用，重视摄影前期调整，减少后期负担，基于LibreCamera优化开发*

[![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.16.0+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2.0+-blue.svg)](https://dart.dev)

**Sky Hackathon 2025 参赛项目**

</div>

## 📖 项目简介

LutinLens是一款基于开源相机应用LibreCamera深度优化的智能相机应用，专为Sky Hackathon 2025设计开发。该项目结合了先进的计算机视觉技术和人工智能，为用户提供专业级的摄影体验和智能构图建议。

**[预留图片位置：应用主界面截图]**

### 🌟 核心特性

- **🎯 AI智能构图建议**: 基于NVIDIA NeMo框架的多Agent系统实时分析场景并提供构图建议
- **🎨 GPU加速LUT渲染**: 采用GLSL实现的YUV到ARGB转换和三线性插值算法，支持.cube文件格式的LUT滤镜
- **🔄 自AI动LUT切换**: AI图像识别自动选择最适合的LUT预设
- **📱 跨平台兼容**: 基于Flutter开发，主要针对Android平台优化，iOS也可运行

## 🏗️ 技术架构

### 前端架构

- **开发框架**: Flutter 3.16.0+ / Dart 3.2.0+
- **图像处理**: GPU加速GLSL着色器
- **相机引擎**: 基于LibreCamera核心优化
- **UI框架**: Material Design 3 + Dynamic Color

### 后端架构（LutinLens Server）

- **AI框架与技术协议**: NVIDIA NeMo Framework (NVIDIA AIQ) 多Agent架构, Model Context Protocol (MCP)
- **测试算力服务**: 阿里云百炼（百炼算力平台）
- **大语言模型**: 千问Flash (Qwen-Flash)

## 🚀 主要创新点

### 1. GPU加速LUT处理系统

基于GLSL（OpenGL Shading Language）实现的高性能LUT（Look-Up Table）处理系统：

```glsl
// 核心YUV到ARGB转换 + 三线性插值算法
precision highp float;
uniform sampler2D uY;    // Y分量纹理
uniform sampler2D uUV;   // UV分量纹理  
uniform sampler2D uLut2D; // 打包的2D LUT纹理
```

**技术优势**：

- **性能提升**: GPU并行处理，处理速度提升300%+
- **实时渲染**: 支持实时预览LUT效果
- **标准兼容**: 完整支持.cube格式LUT文件
- **内存优化**: 智能内存管理，支持大尺寸LUT

### 2. AI智能构图系统

**[预留图片位置：AI构图建议界面截图]**

基于多Agent架构的智能构图分析系统：

- **场景识别**: 实时分析拍摄场景类型
- **构图建议**: 基于摄影美学原理提供移动建议
- **LUT推荐**: 根据场景自动推荐最适合的滤镜
- **实时反馈**: 绿色对勾指示最佳拍摄时机

### 3. MCP协议集成

采用Model Context Protocol实现前后端通信：

- **标准化接口**: 统一的AI服务调用协议
- **可扩展性**: 支持多种AI服务提供商
- **容错机制**: 网络异常自动重试和降级处理

## 📁 项目结构

```
LutinLens/
├── lib/src/                    # 主要源代码
│   ├── pages/                  # 页面组件
│   │   ├── camera_page.dart   # 相机主页面
│   │   └── settings_page.dart # 设置页面
│   ├── services/               # 服务层
│   │   └── ai_suggestion_service.dart # AI建议服务
│   ├── utils/                  # 工具类
│   └── widgets/                # UI组件
├── shaders/                    # GLSL着色器
│   └── gpu_lut.frag           # GPU LUT处理着色器
├── assets/                     # 资源文件
│   ├── Luts/                  # LUT文件存储
│   └── l10n/                  # 多语言文件
├── android/                    # Android特定代码
└── ai_server.dart             # 内嵌AI服务器（测试用）
```

## 🛠️ 开发环境搭建

### 系统要求

- **Flutter SDK**: 3.16.0或更高版本
- **Dart SDK**: 3.2.0或更高版本
- **Android SDK**: API Level 21+ (Android 5.0+)
- **JDK**: Java Development Kit 17
- **GPU**: 支持OpenGL ES 3.0+的设备

### 快速开始

1. **克隆项目**

```bash
git clone https://github.com/KirisameLonnet/LutinLens.git
cd LutinLens
```

2. **安装依赖**

```bash
flutter pub get
```

3. **运行项目**

```bash
flutter run
```

### 使用Nix(nix-darwin)开发环境

本项目提供Nix Flakes支持，可一键配置完整开发环境：

```bash
# 启用Flakes支持
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 进入开发环境
nix develop
```

**[预留图片位置：开发环境配置截图]**

## 🎮 使用指南

### AI智能构图功能

1. **启用AI建议**：在设置页面开启"AI智能建议"功能
2. **服务器配置**：配置LutinLens AI服务器地址
3. **实时构图**：相机界面右下角显示AI构图建议
4. **最佳时机**：绿色对勾表示当前构图最佳，建议拍摄

### LUT滤镜使用

1. 可以手动切换，也可以使用AI智能建议（需部署LutinLens服务器）
2. **实时预览**：GPU加速实时预览滤镜效果
3. **自动切换**：启用AI模式后自动推荐最适合的滤镜

**[预留图片位置：LUT滤镜效果对比图]**

## 🔬 技术细节

### GLSL着色器实现

核心LUT处理着色器位于 `shaders/gpu_lut.frag`，实现了：

- **YUV420到ARGB转换**: 高效的色彩空间转换
- **三线性插值**: 精确的LUT颜色查找算法
- **色彩标准**: 支持BT.709色彩空间
- **纹理优化**: 智能纹理采样和内存回收机制

### AI服务架构

**[预留图片位置：AI服务架构图]**

后端AI服务基于以下技术栈：

- **NVIDIA NeMo**: 用于构建多Agent问答系统
- **阿里云百炼**: 提供高性能GPU算力支持
- **千问Flash**: 快速响应的大语言模型
- **MCP协议**: 标准化的模型上下文协议

### 性能优化

- **GPU加速**: 利用移动设备GPU进行图像处理
- **内存管理**: 智能LUT缓存和内存回收
- **帧率优化**: 保持30FPS流畅预览体验

## 📊 基于LibreCamera的改进

本项目基于开源项目LibreCamera进行深度优化和功能扩展：

### 新增核心功能

- 🆕 **GPU加速LUT处理**: 全新的GLSL着色器系统
- 🆕 **AI构图建议**: 基于NeMo框架的智能分析
- 🆕 **自动LUT切换**: AI驱动的滤镜推荐
- 🆕 **MCP协议支持**: 标准化AI服务接口
- 🆕 **实时性能优化**: GPU并行处理架构

**[预留图片位置：功能对比图表]**

## 📄 开源协议

本项目遵循 **GNU General Public License v3.0 (GPLv3)** 开源协议。

这意味着：

- ✅ 自由使用、修改和分发
- ✅ 商业用途需要开源
- ✅ 衍生作品必须使用相同协议
- ⚠️ 不提供任何担保或保证

详细协议条款请参阅 [LICENSE](LICENSE) 文件。

## 🏆 Sky Hackathon 2025

本项目为Sky Hackathon 2025参赛项目

### 创新亮点

1. **跨平台AI集成**: Flutter + 基于NVIDIA NeMo框架智能分析 + 移动端GLSL GPU加速图像处理
2. **实时GPU处理**: 移动端高性能图像渲染
3. **智能用户体验**: AI驱动的摄影助手功能
4. **开源生态贡献**: 为LibreCamera社区提供高价值扩展

## 👥 开发团队

- 成员：Ryan(搭建后端NeMo框架服务器，搭建多Agent工具链)，KirisameLonnet(前端Flutter开发，实现GPU加速LUT渲染并优化前端)
- **技术架构**: LibreCamera(Flutter) + NVIDIA NeMo
- **测试算力支持**: 阿里云百炼平台
- **开源协议**: GPLv3

## 📞 关于项目其他

- **App项目仓库**: https://github.com/KirisameLonnet/LutinLens
- 服务端项目仓库：

**[预留图片位置：团队照片或联系方式二维码]**

---

<div align="center">

**LutinLens - AI驱动的智能相机应用**

*Made with ❤️ for Sky Hackathon 2025*

*基于LibreCamera · 开源项目 | 遵循GPLv3协议（APP）以及Apache2.0协议（服务端）*

</div>
