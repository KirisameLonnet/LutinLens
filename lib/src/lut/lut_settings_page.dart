import 'package:flutter/material.dart';
import '../utils/lut_manager.dart';
import 'lut_preview_manager.dart';

/// LUT设置页面
class LutSettingsPage extends StatefulWidget {
  const LutSettingsPage({super.key});

  @override
  State<LutSettingsPage> createState() => _LutSettingsPageState();
}

class _LutSettingsPageState extends State<LutSettingsPage> {
  List<LutFile> _lutFiles = [];
  bool _isLoading = true;
  String? _selectedLutPath;
  double _mixStrength = 1.0;
  bool _isPreviewEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadLuts();
    _loadSettings();
  }

  Future<void> _loadLuts() async {
    setState(() => _isLoading = true);
    
    try {
      final luts = await LutManager.getAllLuts();
      setState(() {
        _lutFiles = luts;
        _isLoading = false;
      });
    } catch (e) {
      print('加载LUT列表失败: $e');
      setState(() => _isLoading = false);
    }
  }

  void _loadSettings() {
    final manager = LutPreviewManager.instance;
    setState(() {
      _selectedLutPath = manager.currentLutPath;
      _mixStrength = manager.mixStrength;
      _isPreviewEnabled = manager.isEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LUT 设置'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 预览开关
        _buildPreviewSwitch(),
        
        // 混合强度滑块
        if (_isPreviewEnabled) _buildMixStrengthSlider(),
        
        // LUT列表
        Expanded(child: _buildLutList()),
        
        // 底部按钮
        _buildBottomButtons(),
      ],
    );
  }

  Widget _buildPreviewSwitch() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '启用LUT预览',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Switch(
            value: _isPreviewEnabled,
            onChanged: (value) {
              setState(() => _isPreviewEnabled = value);
              LutPreviewManager.instance.setEnabled(value);
            },
            activeThumbColor: Colors.blue,
            activeTrackColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildMixStrengthSlider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LUT强度: ${(_mixStrength * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.grey[700],
              thumbColor: Colors.blue,
              overlayColor: Colors.blue.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _mixStrength,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(_mixStrength * 100).toInt()}%',
              onChanged: (value) {
                setState(() => _mixStrength = value);
                LutPreviewManager.instance.setMixStrength(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLutList() {
    if (_lutFiles.isEmpty) {
      return const Center(
        child: Text(
          '未找到LUT文件',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: _lutFiles.length,
        itemBuilder: (context, index) {
          final lut = _lutFiles[index];
          final isSelected = _selectedLutPath == lut.path;
          
          return ListTile(
            title: Text(
              lut.name,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              lut.description,
              style: TextStyle(color: Colors.grey[400]),
            ),
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
            trailing: lut.isDefault
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '默认',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : null,
            onTap: () async {
              setState(() => _selectedLutPath = lut.path);
              await LutPreviewManager.instance.setCurrentLut(lut.path);
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _importLut,
              icon: const Icon(Icons.file_upload),
              label: const Text('导入LUT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _resetToDefault,
              icon: const Icon(Icons.refresh),
              label: const Text('重置默认'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importLut() async {
    // TODO: 实现LUT导入功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('LUT导入功能开发中')),
    );
  }

  Future<void> _resetToDefault() async {
    try {
      final defaultPath = await LutPreviewManager.instance.getDefaultLutPath();
      setState(() {
        _selectedLutPath = defaultPath;
        _mixStrength = 1.0;
        _isPreviewEnabled = true;
      });
      
      final manager = LutPreviewManager.instance;
      await manager.setCurrentLut(defaultPath);
      manager.setMixStrength(1.0);
      manager.setEnabled(true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置为默认设置')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重置失败: $e')),
      );
    }
  }
}
