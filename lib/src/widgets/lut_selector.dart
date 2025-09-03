import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:librecamera/src/provider/lut_provider.dart';
import 'package:librecamera/src/pages/lut_management_page.dart';

/// LUT选择器Widget - 可以在相机界面中使用
class LutSelector extends StatelessWidget {
  const LutSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LutProvider>(
      builder: (context, lutProvider, child) {
        if (!lutProvider.hasLuts) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: PopupMenuButton<String>(
            tooltip: 'LUT滤镜',
            icon: const Icon(
              Icons.photo_filter,
              color: Colors.white,
            ),
            itemBuilder: (context) => [
              ...lutProvider.luts.map(
                (lut) => PopupMenuItem<String>(
                  value: lut.name,
                  child: Row(
                    children: [
                      Icon(
                        lutProvider.currentLut?.name == lut.name
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: lutProvider.currentLut?.name == lut.name
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              lut.name,
                              style: TextStyle(
                                fontWeight: lutProvider.currentLut?.name == lut.name
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                            if (lut.description.isNotEmpty)
                              Text(
                                lut.description,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (lut.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '默认',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: '__manage__',
                child: Row(
                  children: [
                    Icon(
                      Icons.settings,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '管理 LUT',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == '__manage__') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const LutManagementPage(),
                  ),
                );
              } else {
                lutProvider.selectLutByName(value);
              }
            },
          ),
        );
      },
    );
  }
}

/// 紧凑的LUT选择器 - 显示当前LUT名称
class CompactLutSelector extends StatelessWidget {
  const CompactLutSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LutProvider>(
      builder: (context, lutProvider, child) {
        if (!lutProvider.hasLuts) {
          return const SizedBox.shrink();
        }

        final currentLut = lutProvider.currentLut;
        
        return GestureDetector(
          onTap: () => _showLutBottomSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_filter,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  currentLut?.name ?? 'No LUT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLutBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部把手
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.photo_filter),
                  const SizedBox(width: 8),
                  const Text(
                    '选择 LUT 滤镜',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LutManagementPage(),
                        ),
                      );
                    },
                    tooltip: '管理 LUT',
                  ),
                ],
              ),
            ),
            // LUT列表
            Consumer<LutProvider>(
              builder: (context, lutProvider, child) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lutProvider.luts.length,
                    itemBuilder: (context, index) {
                      final lut = lutProvider.luts[index];
                      final isSelected = lutProvider.currentLut?.name == lut.name;

                      return ListTile(
                        leading: Icon(
                          isSelected 
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(lut.name)),
                            if (lut.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '默认',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: lut.description.isNotEmpty
                            ? Text(
                                lut.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () {
                          lutProvider.selectLut(lut);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
