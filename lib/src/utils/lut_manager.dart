import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LUT文件管理器
/// 负责管理用户的LUT文件，包括默认LUT的初始化、用户LUT的增删改查等
class LutManager {
  static const String _lutsInitializedKey = 'luts_initialized';
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
  /// 首次运行时将assets中的默认LUT复制到用户目录
  static Future<void> initializeLuts() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      bool lutsInitialized = prefs.getBool(_lutsInitializedKey) ?? false;
      
      if (!lutsInitialized) {
        await _copyDefaultLutsToUserDirectory();
        await prefs.setBool(_lutsInitializedKey, true);
        print('✅ LUT初始化完成');
      } else {
        print('ℹ️ LUT已经初始化过');
      }
    } catch (e) {
      print('❌ LUT初始化失败: $e');
    }
  }

  /// 从assets复制默认LUT到用户目录
  static Future<void> _copyDefaultLutsToUserDirectory() async {
    try {
      final Directory userLutsDir = await getUserLutsDirectory();
      
      // 直接复制预设的LUT文件夹
      await _copyAssetFolder('$_defaultLutPath/CINEMATIC_FILM/', userLutsDir);
      await _copyAssetFolder('$_defaultLutPath/VINTAGE_FILM/', userLutsDir);
      await _copyAssetFolder('$_defaultLutPath/MODERN_DIGITAL/', userLutsDir);
      
    } catch (e) {
      print('❌ 复制默认LUT失败: $e');
    }
  }

  /// 复制assets文件夹到用户目录
  static Future<void> _copyAssetFolder(String assetPath, Directory targetDir) async {
    try {
      // 复制CINEMATIC_FILM.cube文件
      final ByteData cubeData = await rootBundle.load('${assetPath}CINEMATIC_FILM.cube');
      final File cubeFile = File('${targetDir.path}/CINEMATIC_FILM.cube');
      await cubeFile.writeAsBytes(cubeData.buffer.asUint8List());

      // 复制describe.csv文件（如果存在且非空）
      try {
        final ByteData csvData = await rootBundle.load('${assetPath}discribe.csv');
        final File csvFile = File('${targetDir.path}/discribe.csv');
        await csvFile.writeAsBytes(csvData.buffer.asUint8List());
      } catch (e) {
        // 创建一个空的描述文件
        final File csvFile = File('${targetDir.path}/discribe.csv');
        await csvFile.writeAsString('name,description\nCINEMATIC_FILM,Cinematic film look LUT\n');
      }

      print('✅ 已复制LUT文件夹: $assetPath');
    } catch (e) {
      print('❌ 复制文件夹失败 $assetPath: $e');
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
      final File describeFile = File('${lutsDir.path}/discribe.csv');
      
      if (await describeFile.exists()) {
        final String content = await describeFile.readAsString();
        final List<String> lines = content.split('\n');
        
        for (String line in lines) {
          if (line.startsWith(lutName)) {
            final List<String> parts = line.split(',');
            return parts.length > 1 ? parts[1] : 'No description';
          }
        }
      }
      
      return 'No description';
    } catch (e) {
      return 'No description';
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
      final File describeFile = File('${lutsDir.path}/discribe.csv');
      
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
      final File describeFile = File('${lutsDir.path}/discribe.csv');
      
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
