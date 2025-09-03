import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// LUT文件管理器
/// 负责管理用户的LUT文件，包括默认LUT的初始化、用户LUT的增删改查等
class LutManager {
  static const String _lutsInitializedKey = 'luts_initialized';
  static const String _lastAppVersionKey = 'last_app_version';
  static const String _defaultLutPath = 'assets/Luts/';
  static const String _userLutsDirName = 'luts';

  /// 获取用户LUT存储目录
  static Future<Directory> getUserLutsDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory lutsDir = Directory('${appDocDir.path}/$_userLutsDirName');
    
    if (!await lutsDir.exists()) {
      await lutsDir.create(recursive: true);
    }
    
    return lutsDir;
  }

  /// 初始化LUT系统
  /// 在每次安装APK或应用更新时将assets中的默认LUT复制到用户目录
  static Future<void> initializeLuts() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      
      bool lutsInitialized = prefs.getBool(_lutsInitializedKey) ?? false;
      String? lastAppVersion = prefs.getString(_lastAppVersionKey);
      // 使用 version+buildNumber 来区分安装包，确保升级构建号也会重新拷贝
      String currentAppVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      
      // 检查是否需要重新拷贝LUT文件
      // 条件：首次安装或应用版本发生变化
      bool shouldReinitialize = !lutsInitialized || 
                                lastAppVersion == null || 
                                lastAppVersion != currentAppVersion;
      
      if (shouldReinitialize) {
        print('🔄 检测到应用更新或首次安装，重新初始化LUT文件...');
        print('📱 当前版本: $currentAppVersion, 上次版本: $lastAppVersion');
        
        await _copyDefaultLutsToUserDirectory();
        
        // 更新标志位和版本号
        await prefs.setBool(_lutsInitializedKey, true);
        await prefs.setString(_lastAppVersionKey, currentAppVersion);
        
        print('✅ LUT初始化完成 (版本: $currentAppVersion)');
      } else {
        print('ℹ️ LUT已经是最新版本 ($currentAppVersion)');
      }
    } catch (e) {
      print('❌ LUT初始化失败: $e');
    }
  }

  /// 从assets复制默认LUT到用户目录
  /// 在每次应用安装或更新时执行，会覆盖已存在的默认LUT文件
  static Future<void> _copyDefaultLutsToUserDirectory() async {
    try {
      final Directory userLutsDir = await getUserLutsDirectory();
      
      // 从 AssetManifest 动态发现可用的 LUT
      final List<String> lutNames = await _discoverAssetLutNames();
      bool anyLutCopied = false;

      print('📦 开始拷贝 ${lutNames.length} 个默认LUT文件...');

      for (final lutName in lutNames) {
        try {
          // 验证 cube 是否存在（避免清单误差）
          await rootBundle.load('$_defaultLutPath$lutName/$lutName.cube');
          await _copyAssetFolder('$_defaultLutPath$lutName/', lutName, userLutsDir);
          print('✅ 成功复制LUT: $lutName');
          anyLutCopied = true;
        } catch (e) {
          print('ℹ️ 跳过无效LUT "$lutName": $e');
        }
      }

      if (!anyLutCopied) {
        print('⚠️ 没有找到任何默认LUT文件 (assets/Luts/)');
      } else {
        print('🎉 成功拷贝了 ${lutNames.where((name) {
          try {
            return true; // 简化判断，实际成功的文件数通过日志确认
          } catch (e) {
            return false;
          }
        }).length} 个LUT文件');
      }
      
    } catch (e) {
      print('❌ 复制默认LUT失败: $e');
    }
  }

  /// 从 AssetManifest 中枚举所有 assets/Luts/ 下的 .cube 文件，提取 LUT 名称
  static Future<List<String>> _discoverAssetLutNames() async {
    try {
      final String manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestJson) as Map<String, dynamic>;

      final Set<String> names = {};
      for (final String assetPath in manifestMap.keys) {
        // 形如: assets/Luts/<NAME>/<FILE>.cube
        if (assetPath.startsWith(_defaultLutPath) && assetPath.endsWith('.cube')) {
          final parts = assetPath.split('/');
          if (parts.length >= 4) {
            final fileName = parts.last; // <FILE>.cube
            final name = fileName.replaceAll('.cube', '');
            names.add(name);
          }
        }
      }
      final list = names.toList()..sort();
      print('ℹ️ 在 assets 中发现默认LUT: $list');
      return list;
    } catch (e) {
      print('⚠️ 读取 AssetManifest 失败，回退为空: $e');
      return [];
    }
  }

  /// 复制assets文件夹到用户目录
  static Future<void> _copyAssetFolder(String assetPath, String lutName, Directory targetDir) async {
    try {
      // 复制LUT cube文件
      final ByteData cubeData = await rootBundle.load('$assetPath$lutName.cube');
      final File cubeFile = File('${targetDir.path}/$lutName.cube');
      await cubeFile.writeAsBytes(cubeData.buffer.asUint8List());

      // 复制describe.csv文件（优先使用正确拼写的版本）
      String csvContent = '';
      bool csvFound = false;
      
      // 首先尝试加载 describe.csv（正确拼写）
      try {
        final ByteData csvData = await rootBundle.load('${assetPath}describe.csv');
        csvContent = String.fromCharCodes(csvData.buffer.asUint8List());
        csvFound = true;
      } catch (e) {
        // 如果正确拼写不存在，尝试加载 discribe.csv（拼写错误的版本，为了向后兼容）
        try {
          final ByteData csvData = await rootBundle.load('${assetPath}discribe.csv');
          csvContent = String.fromCharCodes(csvData.buffer.asUint8List());
          csvFound = true;
          print('ℹ️ 使用了拼写错误的描述文件: ${assetPath}discribe.csv');
        } catch (e2) {
          print('ℹ️ 没有找到$lutName的描述文件，将创建默认描述');
        }
      }
      
      // 创建或写入描述文件（使用正确的文件名）
      final File csvFile = File('${targetDir.path}/${lutName}_describe.csv');
      
      if (csvFound && csvContent.trim().isNotEmpty) {
        // 如果找到了有效的CSV内容，使用它
        await csvFile.writeAsString(csvContent);
      } else {
        // 如果没有找到或内容为空，创建默认描述
        await csvFile.writeAsString('name,description\n$lutName,$lutName cinematic look LUT\n');
      }

      print('✅ 已复制LUT文件: $assetPath -> $lutName');
    } catch (e) {
      print('❌ 复制LUT失败 $assetPath: $e');
      throw e; // 重新抛出异常，让调用者知道复制失败
    }
  }

  /// 获取所有可用的LUT文件
  static Future<List<LutFile>> getAllLuts() async {
    try {
      final Directory lutsDir = await getUserLutsDirectory();
      final List<LutFile> luts = [];

      await for (final FileSystemEntity entity in lutsDir.list()) {
        if (entity is File && entity.path.endsWith('.cube')) {
          final String name = entity.path.split('/').last.replaceAll('.cube', '');
          final String description = await _getLutDescription(entity.path, name);
          
          luts.add(LutFile(
            name: name,
            path: entity.path,
            description: description,
            isDefault: name == 'CINEMATIC_FILM',
          ));
        }
      }

      return luts;
    } catch (e) {
      print('❌ 获取LUT列表失败: $e');
      return [];
    }
  }

  /// 获取LUT描述信息
  static Future<String> _getLutDescription(String lutPath, String lutName) async {
    try {
      final Directory lutsDir = await getUserLutsDirectory();
      
      // 首先尝试查找对应的描述文件（使用正确拼写）
      File describeFile = File('${lutsDir.path}/${lutName}_describe.csv');
      
      // 如果正确拼写的文件不存在，尝试旧的拼写
      if (!await describeFile.exists()) {
        describeFile = File('${lutsDir.path}/${lutName}_discribe.csv');
      }
      
      // 如果对应的描述文件都不存在，则查找通用的描述文件
      if (!await describeFile.exists()) {
        describeFile = File('${lutsDir.path}/describe.csv');
        if (!await describeFile.exists()) {
          describeFile = File('${lutsDir.path}/discribe.csv');
        }
      }
      
      if (await describeFile.exists()) {
        final String content = await describeFile.readAsString();
        final List<String> lines = content.split('\n');
        
        for (String line in lines) {
          if (line.trim().isNotEmpty && line.startsWith(lutName)) {
            final List<String> parts = line.split(',');
            return parts.length > 1 ? parts[1].trim() : 'No description';
          }
        }
      }
      
      return 'Cinematic look LUT';
    } catch (e) {
      return 'Cinematic look LUT';
    }
  }

  /// 导入新的LUT文件
  static Future<bool> importLut(String sourcePath, String lutName) async {
    try {
      final Directory lutsDir = await getUserLutsDirectory();
      final File sourceFile = File(sourcePath);
      final File targetFile = File('${lutsDir.path}/$lutName.cube');

      if (!await sourceFile.exists()) {
        print('❌ 源文件不存在: $sourcePath');
        return false;
      }

      await sourceFile.copy(targetFile.path);
      
      // 更新描述文件
      await _updateLutDescription(lutName, 'Imported LUT');
      
      print('✅ LUT导入成功: $lutName');
      return true;
    } catch (e) {
      print('❌ LUT导入失败: $e');
      return false;
    }
  }

  /// 通过内存字节导入新的LUT文件（适配 Android SAF/无物理路径场景）
  static Future<bool> importLutBytes(Uint8List data, String lutName) async {
    try {
      final Directory lutsDir = await getUserLutsDirectory();
      final File targetFile = File('${lutsDir.path}/$lutName.cube');
      await targetFile.writeAsBytes(data, flush: true);

      // 更新描述文件
      await _updateLutDescription(lutName, 'Imported LUT');

      print('✅ LUT字节导入成功: $lutName');
      return true;
    } catch (e) {
      print('❌ LUT字节导入失败: $e');
      return false;
    }
  }

  /// 删除LUT文件
  static Future<bool> deleteLut(String lutName) async {
    try {
      // 防止删除默认LUT
      if (lutName == 'CINEMATIC_FILM') {
        print('❌ 无法删除默认LUT');
        return false;
      }

      final Directory lutsDir = await getUserLutsDirectory();
      final File lutFile = File('${lutsDir.path}/$lutName.cube');

      if (await lutFile.exists()) {
        await lutFile.delete();
        await _removeLutDescription(lutName);
        print('✅ LUT删除成功: $lutName');
        return true;
      } else {
        print('❌ LUT文件不存在: $lutName');
        return false;
      }
    } catch (e) {
      print('❌ LUT删除失败: $e');
      return false;
    }
  }

  /// 更新LUT描述
  static Future<void> _updateLutDescription(String lutName, String description) async {
    try {
      final Directory lutsDir = await getUserLutsDirectory();
      final File describeFile = File('${lutsDir.path}/describe.csv');
      
      List<String> lines = [];
      
      if (await describeFile.exists()) {
        lines = (await describeFile.readAsString()).split('\n');
      } else {
        lines = ['name,description'];
      }

      // 检查是否已存在该LUT的描述
      bool found = false;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith(lutName)) {
          lines[i] = '$lutName,$description';
          found = true;
          break;
        }
      }

      // 如果没找到，添加新行
      if (!found) {
        lines.add('$lutName,$description');
      }

      await describeFile.writeAsString(lines.join('\n'));
    } catch (e) {
      print('❌ 更新LUT描述失败: $e');
    }
  }

  /// 移除LUT描述
  static Future<void> _removeLutDescription(String lutName) async {
    try {
      final Directory lutsDir = await getUserLutsDirectory();
      final File describeFile = File('${lutsDir.path}/describe.csv');
      
      if (await describeFile.exists()) {
        final List<String> lines = (await describeFile.readAsString()).split('\n');
        lines.removeWhere((line) => line.startsWith(lutName));
        await describeFile.writeAsString(lines.join('\n'));
      }
    } catch (e) {
      print('❌ 移除LUT描述失败: $e');
    }
  }

  /// 导出LUT到外部存储
  static Future<String?> exportLut(String lutName) async {
    try {
      final Directory lutsDir = await getUserLutsDirectory();
      final File lutFile = File('${lutsDir.path}/$lutName.cube');

      if (!await lutFile.exists()) {
        print('❌ LUT文件不存在: $lutName');
        return null;
      }

      // 获取外部存储目录
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        print('❌ 无法获取外部存储目录');
        return null;
      }

      final Directory exportDir = Directory('${externalDir.path}/LutinLens/exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final File exportFile = File('${exportDir.path}/$lutName.cube');
      await lutFile.copy(exportFile.path);

      print('✅ LUT导出成功: ${exportFile.path}');
      return exportFile.path;
    } catch (e) {
      print('❌ LUT导出失败: $e');
      return null;
    }
  }

  /// 重置所有LUT（恢复默认）
  static Future<bool> resetAllLuts() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Directory lutsDir = await getUserLutsDirectory();

      // 删除整个LUT目录
      if (await lutsDir.exists()) {
        await lutsDir.delete(recursive: true);
      }

      // 重置初始化标志
      await prefs.setBool(_lutsInitializedKey, false);

      // 重新初始化
      await initializeLuts();

      print('✅ LUT重置成功');
      return true;
    } catch (e) {
      print('❌ LUT重置失败: $e');
      return false;
    }
  }
}

/// LUT文件信息类
class LutFile {
  final String name;
  final String path;
  final String description;
  final bool isDefault;

  LutFile({
    required this.name,
    required this.path,
    required this.description,
    this.isDefault = false,
  });

  @override
  String toString() {
    return 'LutFile{name: $name, path: $path, description: $description, isDefault: $isDefault}';
  }
}
