import 'package:flutter/foundation.dart';
import 'package:librecamera/src/utils/lut_manager.dart';

/// LUT状态管理Provider
class LutProvider extends ChangeNotifier {
  List<LutFile> _luts = [];
  LutFile? _currentLut;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<LutFile> get luts => _luts;
  LutFile? get currentLut => _currentLut;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLuts => _luts.isNotEmpty;

  /// 初始化LUT系统
  Future<void> initializeLuts() async {
    _setLoading(true);
    _clearError();

    try {
      await LutManager.initializeLuts();
      await loadLuts();
    } catch (e) {
      _setError('初始化LUT失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 加载所有LUT文件
  Future<void> loadLuts() async {
    try {
      _luts = await LutManager.getAllLuts();
      
      // 如果当前没有选择LUT，选择默认的
      if (_currentLut == null && _luts.isNotEmpty) {
        _currentLut = _luts.firstWhere(
          (lut) => lut.isDefault,
          orElse: () => _luts.first,
        );
      }
      
      notifyListeners();
    } catch (e) {
      _setError('加载LUT列表失败: $e');
    }
  }

  /// 选择LUT
  void selectLut(LutFile lut) {
    if (_currentLut != lut) {
      _currentLut = lut;
      notifyListeners();
    }
  }

  /// 通过名称选择LUT
  void selectLutByName(String lutName) {
    final lut = _luts.where((l) => l.name == lutName).firstOrNull;
    if (lut != null) {
      selectLut(lut);
    }
  }

  /// 导入LUT文件
  Future<bool> importLut(String sourcePath, String lutName) async {
    _setLoading(true);
    _clearError();

    try {
      final bool success = await LutManager.importLut(sourcePath, lutName);
      if (success) {
        await loadLuts(); // 重新加载列表
      } else {
        _setError('导入LUT失败');
      }
      return success;
    } catch (e) {
      _setError('导入LUT时发生错误: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 删除LUT文件
  Future<bool> deleteLut(String lutName) async {
    _setLoading(true);
    _clearError();

    try {
      final bool success = await LutManager.deleteLut(lutName);
      if (success) {
        // 如果删除的是当前选择的LUT，切换到默认LUT
        if (_currentLut?.name == lutName) {
          final defaultLut = _luts.firstWhere(
            (lut) => lut.isDefault,
            orElse: () => _luts.isNotEmpty ? _luts.first : LutFile(name: 'None', path: '', description: ''),
          );
          _currentLut = defaultLut.name.isNotEmpty ? defaultLut : null;
        }
        await loadLuts(); // 重新加载列表
      } else {
        _setError('删除LUT失败');
      }
      return success;
    } catch (e) {
      _setError('删除LUT时发生错误: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 导出LUT文件
  Future<String?> exportLut(String lutName) async {
    _setLoading(true);
    _clearError();

    try {
      final String? exportPath = await LutManager.exportLut(lutName);
      if (exportPath == null) {
        _setError('导出LUT失败');
      }
      return exportPath;
    } catch (e) {
      _setError('导出LUT时发生错误: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// 重置所有LUT
  Future<bool> resetAllLuts() async {
    _setLoading(true);
    _clearError();

    try {
      final bool success = await LutManager.resetAllLuts();
      if (success) {
        await loadLuts(); // 重新加载列表
      } else {
        _setError('重置LUT失败');
      }
      return success;
    } catch (e) {
      _setError('重置LUT时发生错误: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 获取LUT文件路径（用于图像处理）
  String? getCurrentLutPath() {
    return _currentLut?.path;
  }

  /// 检查是否有可用的LUT
  bool hasLutWithName(String name) {
    return _luts.any((lut) => lut.name == name);
  }

  /// 获取默认LUT
  LutFile? getDefaultLut() {
    return _luts.where((lut) => lut.isDefault).firstOrNull;
  }

  // 私有辅助方法
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
    
    // 自动清除错误信息（3秒后）
    Future.delayed(const Duration(seconds: 3), () {
      if (_error == error) {
        _clearError();
      }
    });
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// 清除所有状态
  void clear() {
    _luts.clear();
    _currentLut = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

// 扩展方法，为List添加firstOrNull方法（如果不存在的话）
extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
