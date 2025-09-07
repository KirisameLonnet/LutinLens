<h1 align="center">LutinLens</h1>
<div align="center">

*AI驱动的智能相机应用，重视摄影前期调整，减少后期负担，基于LibreCamera优化开发*

[![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.16.0+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2.0+-blue.svg)](https://dart.dev)

**Sky Hackathon 2025 参赛项目**

> 本仓库为本次作品的App源码部分，服务端源码也是该项目重要的一环。请见：[LutinServer](https://github.com/m0cal/lutinlens_server)

</div>

## 📖 项目简介

LutinLens 是一款基于 LibreCamera 内核优化的智能相机应用，前端采用 Flutter 构建跨平台 UI，后端基于 NVIDIA NeMo Agent Toolkit + MCP 协议 提供实时 AI 构图与 LUT 推荐能力。
其目标是将传统相机的硬件拍摄体验与 AI 智能服务结合，形成实时构图建议 + GPU 加速风格化渲染的一体化解决方案。

![jietu](https://private-user-images.githubusercontent.com/69973084/486522599-a2724871-8d59-4171-8f79-a6c1259ff3a4.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTcyNTgzNzksIm5iZiI6MTc1NzI1ODA3OSwicGF0aCI6Ii82OTk3MzA4NC80ODY1MjI1OTktYTI3MjQ4NzEtOGQ1OS00MTcxLThmNzktYTZjMTI1OWZmM2E0LmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA5MDclMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwOTA3VDE1MTQzOVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTcxODRmMGYyZDQ0MTc2MGM1NGM4YzAyZjljYjZjOWFkYTc2NTZmMDU3NzE5NDBlM2Y3NTMwM2RmMmRkOGJmODYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.AuPPAezsz1JMyHZsYnDWv0re9qJ7FagKwoAw1pYIl20)
![jietu](https://private-user-images.githubusercontent.com/69973084/486522614-761ff78e-b91e-48ef-aafd-73644aedc6bd.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTcyNTgzNzksIm5iZiI6MTc1NzI1ODA3OSwicGF0aCI6Ii82OTk3MzA4NC80ODY1MjI2MTQtNzYxZmY3OGUtYjkxZS00OGVmLWFhZmQtNzM2NDRhZWRjNmJkLmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA5MDclMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwOTA3VDE1MTQzOVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTFhY2E0NzI1ODllZDIwZmY2M2MzZGZiYzAzOGMzZDgwOTI4YmMyYTIxY2UzYjg5YmMzNDU2NzRmZDUyMWMyNGEmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.GB8Tnktp9GH6IfP4bj2Ym9PBOUWHaALN-ymcdGSeDlo)
### 🌟 核心特性

- **🎯 智能构图与 LUT 建议**: 基于 NVIDIA NeMo 框架的多 Agent 系统实时分析场景并提供构图及 LUT 套用建议
- **🎨 GPU 加速 LUT 渲染**: 采用 GLSL 实现的 YUV 到 ARGB 转换和三线性插值算法，支持 .cube 文件格式的 LUT 滤镜
- **📱 跨平台兼容**: 基于 Flutter 开发，主要针对 Android 平台优化，iOS 也可运行

## 拍摄效果

### 原相机图：
![yuantu](https://private-user-images.githubusercontent.com/69973084/486522175-8975685b-c9f3-4bbb-90af-2421d376d787.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTcyNTgzNzksIm5iZiI6MTc1NzI1ODA3OSwicGF0aCI6Ii82OTk3MzA4NC80ODY1MjIxNzUtODk3NTY4NWItYzlmMy00YmJiLTkwYWYtMjQyMWQzNzZkNzg3LmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA5MDclMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwOTA3VDE1MTQzOVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWE2NzU0Y2NiM2RmZGJiMGRjODY4YmZkYzJjYjVlNmMwNDc4N2QyODU5Mjc2M2U1NTQyMzI2OWM5ODBjZmVmZDImWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.jxfM1mkAx5ctatjlY6mFqAbWuBQP8zHhsOolS4rvVSI)

### LutinLens拍摄效果
![lens](https://private-user-images.githubusercontent.com/69973084/486522201-b0be3dd1-83d7-428d-ba97-2d47fb1295a5.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTcyNTgzNzksIm5iZiI6MTc1NzI1ODA3OSwicGF0aCI6Ii82OTk3MzA4NC80ODY1MjIyMDEtYjBiZTNkZDEtODNkNy00MjhkLWJhOTctMmQ0N2ZiMTI5NWE1LmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA5MDclMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwOTA3VDE1MTQzOVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTE0NzgwYjQ4NDQ5ZjQzZGQ0YjcxNWNlZmE5ZjdkOWExYjZkZjEwM2VhM2EyNDlhMmM2ZjQ4Y2U4ZjNhOTJjMWYmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.7FOPla43k6tH9IPEOvNH-vf7Z8hPnEEM3DQEu0FcC-c)

![lens](https://private-user-images.githubusercontent.com/69973084/486523382-954dd707-ee88-4825-90b4-a3b44721dc4c.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTcyNTg4OTAsIm5iZiI6MTc1NzI1ODU5MCwicGF0aCI6Ii82OTk3MzA4NC80ODY1MjMzODItOTU0ZGQ3MDctZWU4OC00ODI1LTkwYjQtYTNiNDQ3MjFkYzRjLmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA5MDclMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwOTA3VDE1MjMxMFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPThjYjM0NTc1MGRjOWI2Nzk3MmRhNGZlOWMwNWUxOWNjNzEyZTkyZWE3YWI2MDMxMmYwMDMxZmEwYjBhYjIwMWMmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.aotPbLd5XDnHb9yX1xL8izotfDfevw0QoIElfqLG6To)

![lens](https://private-user-images.githubusercontent.com/69973084/486523387-73d24966-8f5c-4f79-bb46-ce9a1db330e5.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTcyNTg4OTAsIm5iZiI6MTc1NzI1ODU5MCwicGF0aCI6Ii82OTk3MzA4NC80ODY1MjMzODctNzNkMjQ5NjYtOGY1Yy00Zjc5LWJiNDYtY2U5YTFkYjMzMGU1LmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA5MDclMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwOTA3VDE1MjMxMFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWEzZjhmOWE1MWNjY2JhYzhkY2I3ZTJlMzg3ZGFhNzcxNjhjMzZjMWYwMTdiOWQ4Mjk5NTg5ZDYzMzc0MDA1MDEmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.G5-bv19u6nxqzr6FRjoCGmZGCgsmbr1KRkI1s71Ot00)

#### 此外 我们还支持更多场景：

![9b7e11a9f9edf8a52de4d43de53318c8](https://github.com/user-attachments/assets/7526583e-0f20-4080-a356-e21e80d90b1b)

#### 支持诸多相机必要的特性

![4f34e60b7f929d509aa8b75dae7b19e4](https://github.com/user-attachments/assets/28412126-97be-44da-91fb-30ed0e04eed5)

![3f17341f743e75605f513b433ccb59f9](https://github.com/user-attachments/assets/1f7595e1-7187-45af-b86a-8cee2dbd700b)

## 🏗️ 技术架构

### 前端架构

- **开发框架**: Flutter 3.16.0+ / Dart 3.2.0+
- **图像处理**: GPU 加速 GLSL 着色器
- **相机引擎**: 基于 LibreCamera 核心优化
- **UI框架**: Material Design 3 + Dynamic Color

### 后端架构（[LutinLens Server](https://github.com/m0cal/lutinlens_server)）

- **AI框架与技术协议**: NVIDIA NeMo Agent Toolkit 多Agent架构, Model Context Protocol (MCP)
- **算力服务**: 阿里云百炼（百炼算力平台）
- **图像分析和大语言模型**：Qwen 系列

## 🚀 主要创新点

### 1. GPU 加速 LUT 处理系统

基于GLSL（OpenGL Shading Language）实现的高性能LUT（Look-Up Table）处理系统：

```glsl
// 核心YUV到ARGB转换 + 三线性插值算法
precision highp float;
uniform sampler2D uY;    // Y分量纹理
uniform sampler2D uUV;   // UV分量纹理  
uniform sampler2D uLut2D; // 打包的2D LUT纹理
```

**技术优势**：

- **高性能实时渲染**: GPU 并行处理，在第二代骁龙8移动平台上约30帧
- **标准兼容**: 完整支持 .cube 格式 LUT 文件
- **内存优化**: 智能内存管理，支持大尺寸LUT

### 2. AI智能摄影前期辅助-构图+安排Lut配置

![setting](https://private-user-images.githubusercontent.com/69973084/486522718-ea9df1ff-66b8-49ae-9c65-ea46f1339d9d.jpg?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NTcyNTgzNzksIm5iZiI6MTc1NzI1ODA3OSwicGF0aCI6Ii82OTk3MzA4NC80ODY1MjI3MTgtZWE5ZGYxZmYtNjZiOC00OWFlLTljNjUtZWE0NmYxMzM5ZDlkLmpwZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNTA5MDclMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjUwOTA3VDE1MTQzOVomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWNlODRiYjI5MmY0ODM4NWQ3YzY2OTYwMTk1OTQ2ZjdkYjk5YmU0NmE1MmY1ZThhNWYxYThmNmUwMTk0MTE0ZTImWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.33hKmtKF7BIR7bwGm6MxvGR_QZ8WkOocETgomeXfPEc)

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

## 🎮 使用指南

### AI智能构图功能

1. **启用AI建议**：在设置页面开启"AI智能建议"功能
2. **服务器配置**：配置LutinLens AI服务器地址
3. **实时构图**：相机界面右下角显示AI构图建议
4. **最佳时机**：绿色对勾表示当前构图最佳，建议拍摄

### LUT滤镜使用

1. 可以手动切换，也可以使用 AI 智能建议（需连接到 LutinLens 服务器）
2. **实时预览**：GPU 加速实时预览滤镜效果
3. **自动切换**：启用 AI 模式后自动推荐最适合的滤镜


## 🔬 技术细节

### GLSL着色器实现

核心LUT处理着色器位于 `shaders/gpu_lut.frag`，实现了：

- **YUV420到ARGB转换**: 高效的色彩空间转换
- **三线性插值**: 精确的LUT颜色查找算法
- **色彩标准**: 支持BT.709色彩空间
- **纹理优化**: 智能纹理采样和内存回收机制

### AI服务架构

后端AI服务基于以下技术栈：

- **NVIDIA NeMo Agent Toolkit**: 用于构建多 Agent 协作系统
- **阿里云百炼**: 提供模型支持
- **MCP协议**: 标准化的模型上下文协议

在 LUT 推荐中，我们使用了 NeMo 框架下的 ReAct Agent 作为工作流，它可以使用我们编写的图像内容提取工具 (content_identifier) 和根据图像内容查找适合 LUT 的工具 (lut_finder) 来推荐一个合适的 LUT。
在构图建议中，得益于 Qwen-VL-Max 模型优秀的多图像理解能力，我们将用户取景器内过去一段时间内的多张图像组合后作为 Prompt 输入模型，使其可以感知到过去一段时间内用户的操作意图是否遵循了模型建议，并且以此为基础进一步提出可操作的构图建议。

### 性能优化

- **GPU加速**: 利用移动设备 GPU 进行图像处理
- **内存管理**: 智能 LUT 缓存和内存回收
- **帧率优化**: 保持30FPS流畅预览体验

## 📊 基于LibreCamera的改进

本项目基于开源项目LibreCamera进行深度优化和功能扩展：

### 新增核心功能

- 🆕 **GPU加速LUT处理**: 全新的 GLSL 着色器系统
- 🆕 **AI构图建议**: 基于 NeMo 框架的智能分析
- 🆕 **自动LUT切换**: AI 驱动的 LUT 推荐
- 🆕 **MCP协议支持**: 标准化 AI 服务接口
- 🆕 **实时性能优化**: GPU 并行处理架构


## 📄 开源协议

本项目遵循 **GNU General Public License v3.0 (GPLv3)** 开源协议。
详细协议条款请参阅 [LICENSE](LICENSE) 文件。

## 🏆 Sky Hackathon 2025

本项目为Sky Hackathon 2025参赛项目

### 创新亮点

1. **跨平台AI集成**: Flutter + 基于NVIDIA NeMo框架智能分析 + 移动端GLSL GPU加速图像处理
2. **实时GPU处理**: 移动端高性能图像渲染
3. **智能用户体验**: AI驱动的摄影助手功能
   
## 👥 开发团队

- 成员：Ryan(搭建后端NeMo框架服务器，搭建多Agent工具链)，KirisameLonnet(前端Flutter开发，实现GPU加速LUT渲染并优化前端)

## 📞 关于项目其他

- **App项目仓库**: https://github.com/KirisameLonnet/LutinLens
- **服务器项目仓库**：https://github.com/m0cal/lutinlens_server


---

<div align="center">

**LutinLens - AI驱动的智能相机应用**

*Made with ❤️ for Sky Hackathon 2025*

*基于LibreCamera · 开源项目 | 遵循GPLv3协议（APP）以及Apache2.0协议（服务端）*

</div>
