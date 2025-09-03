# LutinLens

一个基于Flutter开发的自由开源Android相机应用程序。

## 项目简介

LutinLens是一个注重隐私保护的相机应用，具有以下特点：
- 前后摄像头拍照和录像功能
- 默认不保存EXIF元数据，保护隐私
- 无广告、无追踪、无不必要权限
- 支持多种语言本地化
- 完全开源，基于GPL-3.0许可证

## 系统要求

- **目标平台**: Android设备
- **开发环境**: 
  - Flutter SDK 3.16.0+
  - Dart SDK 3.2.0+
  - Java JDK 17
  - Android SDK
  - Git

## 编译安装指南

### 方法一：使用 Nix (macOS/nix-darwin)

#### 前置要求

1. **安装 Nix 包管理器**：
   ```bash
   curl -L https://nixos.org/nix/install | sh
   ```

2. **启用 Flakes 支持**：
   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

3. **手动安装 Flutter SDK**：
   ```bash
   git clone https://github.com/flutter/flutter.git -b 3.24.0 ~/.flutter-sdk
   ```

4. **安装 Android Studio 和 SDK**：
   - 下载并安装 [Android Studio](https://developer.android.com/studio)
   - 通过 Android Studio SDK Manager 安装：
     - Android SDK Platform-Tools
     - Android SDK Build-Tools
     - Android API 34 (或更高版本)

#### 编译步骤

1. **克隆项目**：
   ```bash
   git clone https://github.com/KirisameLonnet/LutinLens.git
   cd LutinLens
   ```

2. **进入开发环境**：
   ```bash
   nix develop
   ```

3. **配置 Android SDK 环境变量**：
   ```bash
   export ANDROID_HOME="$HOME/Library/Android/sdk"
   export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$PATH"
   ```

4. **验证环境**：
   ```bash
   flutter doctor
   ```

5. **获取依赖**：
   ```bash
   flutter pub get
   ```

6. **连接Android设备或启动模拟器**：
   ```bash
   # 检查连接的设备
   flutter devices
   
   # 或者启动Android模拟器
   flutter emulators --launch <emulator_id>
   ```

7. **编译并安装到设备**：
   ```bash
   # Debug版本（开发测试）
   flutter run
   
   # 或者构建APK文件
   flutter build apk --release
   
   # APK文件位置：build/app/outputs/flutter-apk/app-release.apk
   ```

8. **安装到Android设备**：
   ```bash
   # 直接安装
   flutter install
   
   # 或者手动安装APK
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

---

### 方法二：使用 Archlinux

#### 前置要求

1. **更新系统**：
   ```bash
   sudo pacman -Syu
   ```

2. **安装基础依赖**：
   ```bash
   sudo pacman -S git wget curl unzip base-devel
   ```

3. **安装 Java JDK 17**：
   ```bash
   sudo pacman -S jdk17-openjdk
   
   # 设置JAVA_HOME
   echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk' >> ~/.bashrc
   echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
   source ~/.bashrc
   ```

4. **安装 Android Studio**：
   ```bash
   # 方法1：使用AUR
   yay -S android-studio
   
   # 方法2：手动下载
   # 访问 https://developer.android.com/studio 下载
   # 解压到 /opt/android-studio 并添加到PATH
   ```

5. **配置 Android SDK**：
   ```bash
   # 通过Android Studio安装SDK，或使用命令行工具
   export ANDROID_HOME="$HOME/Android/Sdk"
   export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$PATH"
   echo 'export ANDROID_HOME="$HOME/Android/Sdk"' >> ~/.bashrc
   echo 'export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$PATH"' >> ~/.bashrc
   ```

6. **安装 Flutter**：
   ```bash
   # 方法1：使用snap
   sudo pacman -S snapd
   sudo snap install flutter --classic
   
   # 方法2：手动安装
   cd ~
   git clone https://github.com/flutter/flutter.git -b stable
   echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

#### 编译步骤

1. **克隆项目**：
   ```bash
   git clone https://github.com/KirisameLonnet/LutinLens.git
   cd LutinLens
   ```

2. **验证开发环境**：
   ```bash
   flutter doctor
   ```

3. **接受Android许可证**：
   ```bash
   flutter doctor --android-licenses
   ```

4. **获取项目依赖**：
   ```bash
   flutter pub get
   ```

5. **启用USB调试并连接Android设备**：
   - 在Android设备上：设置 → 关于手机 → 连续点击"版本号"7次启用开发者选项
   - 设置 → 开发者选项 → 启用"USB调试"
   - 用USB连接设备到电脑

6. **验证设备连接**：
   ```bash
   flutter devices
   adb devices
   ```

7. **编译并安装**：
   ```bash
   # 运行debug版本（实时调试）
   flutter run
   
   # 构建release APK
   flutter build apk --release
   
   # 构建app bundle（用于Google Play）
   flutter build appbundle --release
   ```

8. **手动安装APK**：
   ```bash
   # 安装到连接的设备
   adb install build/app/outputs/flutter-apk/app-release.apk
   
   # 或者直接使用flutter命令
   flutter install
   ```

## 故障排除

### 常见问题

1. **Flutter doctor 显示问题**：
   ```bash
   # Android toolchain问题
   flutter doctor --android-licenses
   
   # 缺少Android SDK
   # 通过Android Studio SDK Manager安装所需组件
   ```

2. **Java版本问题**：
   ```bash
   # 验证Java版本
   java -version
   javac -version
   
   # 应该显示17.x.x版本
   ```

3. **设备未识别**：
   ```bash
   # 重启adb服务
   adb kill-server
   adb start-server
   
   # 检查USB驱动和调试模式
   adb devices
   ```

4. **权限问题**：
   ```bash
   # Linux/macOS添加用户到dialout组
   sudo usermod -a -G dialout $USER
   # 重新登录后生效
   ```

5. **Gradle构建失败**：
   ```bash
   # 清理构建缓存
   flutter clean
   flutter pub get
   cd android && ./gradlew clean && cd ..
   ```

### 性能优化

1. **构建发布版本**：
   ```bash
   flutter build apk --release --shrink
   ```

2. **启用R8代码压缩**（已在项目中配置）

3. **减小APK大小**：
   ```bash
   flutter build apk --split-per-abi
   ```

## 开发调试

### 热重载开发
```bash
flutter run
# 在代码修改后按 'r' 进行热重载
# 按 'R' 进行热重启
```

### 日志查看
```bash
flutter logs
# 或
adb logcat | grep flutter
```

### 性能分析
```bash
flutter run --profile
# 然后打开 Flutter Inspector
```

## 许可证

本项目基于 GPL-3.0 许可证开源。详见 [LICENSE](LICENSE) 文件。

## 贡献

欢迎提交Issue和Pull Request！请确保：
- 遵循项目代码风格
- 添加适当的测试
- 更新相关文档

## 联系方式

- 项目地址：https://github.com/KirisameLonnet/LutinLens
- 问题反馈：https://github.com/KirisameLonnet/LutinLens/issues

---

**注意**: 这是一个开发版本的构建指南。如果您只想使用应用程序，建议从 F-Droid 或 GitHub Releases 下载预编译的APK文件。
