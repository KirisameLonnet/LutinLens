import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// 手动导入已禁用
import 'package:librecamera/src/provider/lut_provider.dart';
import 'package:librecamera/src/utils/lut_manager.dart';

/// LUT管理页面
class LutManagementPage extends StatefulWidget {
  const LutManagementPage({super.key});

  @override
  State<LutManagementPage> createState() => _LutManagementPageState();
}

class _LutManagementPageState extends State<LutManagementPage> {
  @override
  void initState() {
    super.initState();
    // 确保LUT列表是最新的
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LutProvider>().loadLuts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUT 管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<LutProvider>().loadLuts(),
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              // 已移除“导入 LUT”选项
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore),
                    SizedBox(width: 8),
                    Text('重置所有 LUT'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<LutProvider>(
        builder: (context, lutProvider, child) {
          if (lutProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (lutProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lutProvider.error!,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => lutProvider.loadLuts(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          if (!lutProvider.hasLuts) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_filter,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '没有可用的 LUT',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已锁定为内置静态 LUT（不支持导入）',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lutProvider.luts.length,
            itemBuilder: (context, index) {
              final lut = lutProvider.luts[index];
              final isSelected = lutProvider.currentLut?.name == lut.name;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isSelected ? 4 : 1,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    child: Icon(
                      Icons.photo_filter,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lut.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        ),
                      ),
                      if (lut.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '默认',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    lut.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => _handleLutAction(action, lut),
                    itemBuilder: (context) => [
                      if (!isSelected)
                        const PopupMenuItem(
                          value: 'select',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle),
                              SizedBox(width: 8),
                              Text('选择'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.file_download),
                            SizedBox(width: 8),
                            Text('导出'),
                          ],
                        ),
                      ),
                      if (!lut.isDefault)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('删除', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  onTap: () => lutProvider.selectLut(lut),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'reset':
        _resetAllLuts();
        break;
    }
  }

  void _handleLutAction(String action, LutFile lut) {
    switch (action) {
      case 'select':
        context.read<LutProvider>().selectLut(lut);
        break;
      case 'export':
        _exportLut(lut);
        break;
      case 'delete':
        _deleteLut(lut);
        break;
    }
  }

  /* 手动导入功能已禁用（旧实现保留注释）
  Future<void> _importLut() async {
    // 手动导入已禁用
    if (mounted) {
      _showSnackBar('已禁用：不支持手动导入', isError: true);
    }
    return;
      final result = null;
        type: FileType.any,
        withData: true,
        dialogTitle: '选择 LUT 文件',
      );

      if (result != null) {
        final file = result.files.single;
        // 自行校验扩展名
        final isCube = (file.extension?.toLowerCase() == 'cube') || file.name.toLowerCase().endsWith('.cube');
        if (!isCube) {
          if (mounted) {
            _showSnackBar('请选择 .cube 文件', isError: true);
          }
          return;
        }
        final fileName = file.name.replaceAll(RegExp(r'\.cube\$', caseSensitive: false), '');

        // 检查是否已存在同名LUT
        final lutProvider = context.read<LutProvider>();
        if (lutProvider.hasLutWithName(fileName)) {
          final shouldReplace = await _showConfirmDialog(
            '替换 LUT',
            '已存在名为 "$fileName" 的 LUT，是否要替换它？',
          );
          if (!shouldReplace) return;
        }

        bool success = false;
        if (file.path != null) {
          success = await lutProvider.importLut(file.path!, fileName);
        } else if (file.bytes != null) {
          success = await lutProvider.importLutBytes(file.bytes as Uint8List, fileName);
        }

        if (success && mounted) {
          _showSnackBar('LUT "$fileName" 导入成功', isError: false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('导入失败: $e', isError: true);
      }
    }
  }
  */
  Future<void> _importLut() async {
    if (mounted) {
      _showSnackBar('已禁用：不支持手动导入', isError: true);
    }
  }

  Future<void> _exportLut(LutFile lut) async {
    try {
      final lutProvider = context.read<LutProvider>();
      final exportPath = await lutProvider.exportLut(lut.name);
      
      if (exportPath != null && mounted) {
        _showSnackBar('LUT "${lut.name}" 已导出到: $exportPath', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('导出失败: $e', isError: true);
      }
    }
  }

  Future<void> _deleteLut(LutFile lut) async {
    final shouldDelete = await _showConfirmDialog(
      '删除 LUT',
      '确定要删除 "${lut.name}" 吗？此操作无法撤销。',
    );

    if (shouldDelete) {
      final lutProvider = context.read<LutProvider>();
      final success = await lutProvider.deleteLut(lut.name);
      
      if (success && mounted) {
        _showSnackBar('LUT "${lut.name}" 已删除', isError: false);
      }
    }
  }

  Future<void> _resetAllLuts() async {
    final shouldReset = await _showConfirmDialog(
      '重置所有 LUT',
      '这将删除所有自定义 LUT 并恢复默认设置。确定要继续吗？',
    );

    if (shouldReset) {
      final lutProvider = context.read<LutProvider>();
      final success = await lutProvider.resetAllLuts();
      
      if (success && mounted) {
        _showSnackBar('已重置所有 LUT', isError: false);
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError 
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }
}
