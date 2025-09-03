import 'dart:typed_data';
import 'dart:math' as math;
import 'cube_loader.dart';

/// 软件实现的LUT处理器
class SoftwareLutProcessor {
  final CubeLut lut;
  final int lutSize;
  final Float32List lutData;

  SoftwareLutProcessor(this.lut) 
      : lutSize = lut.size,
        lutData = lut.data;

  /// 应用LUT到RGB像素
  List<int> applyLutToRgb(int r, int g, int b, double mixStrength) {
    if (mixStrength <= 0.0) {
      return [r, g, b];
    }

    // 归一化RGB值到0-1范围
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    // 计算LUT索引
    final rIndex = (rNorm * (lutSize - 1)).clamp(0.0, lutSize - 1.0);
    final gIndex = (gNorm * (lutSize - 1)).clamp(0.0, lutSize - 1.0);
    final bIndex = (bNorm * (lutSize - 1)).clamp(0.0, lutSize - 1.0);

    // 三线性插值
    final result = _trilinearInterpolation(rIndex, gIndex, bIndex);

    // 应用混合强度
    final finalR = ((1.0 - mixStrength) * rNorm + mixStrength * result[0]) * 255.0;
    final finalG = ((1.0 - mixStrength) * gNorm + mixStrength * result[1]) * 255.0;
    final finalB = ((1.0 - mixStrength) * bNorm + mixStrength * result[2]) * 255.0;

    return [
      finalR.clamp(0, 255).round(),
      finalG.clamp(0, 255).round(),
      finalB.clamp(0, 255).round(),
    ];
  }

  /// 三线性插值
  List<double> _trilinearInterpolation(double r, double g, double b) {
    final r0 = r.floor();
    final r1 = math.min(r0 + 1, lutSize - 1);
    final g0 = g.floor();
    final g1 = math.min(g0 + 1, lutSize - 1);
    final b0 = b.floor();
    final b1 = math.min(b0 + 1, lutSize - 1);

    final rFrac = r - r0;
    final gFrac = g - g0;
    final bFrac = b - b0;

    // 获取8个顶点的值
    final c000 = _getLutValue(r0, g0, b0);
    final c001 = _getLutValue(r0, g0, b1);
    final c010 = _getLutValue(r0, g1, b0);
    final c011 = _getLutValue(r0, g1, b1);
    final c100 = _getLutValue(r1, g0, b0);
    final c101 = _getLutValue(r1, g0, b1);
    final c110 = _getLutValue(r1, g1, b0);
    final c111 = _getLutValue(r1, g1, b1);

    // 三线性插值
    final result = <double>[0, 0, 0];
    for (int i = 0; i < 3; i++) {
      final c00 = c000[i] * (1 - rFrac) + c100[i] * rFrac;
      final c01 = c001[i] * (1 - rFrac) + c101[i] * rFrac;
      final c10 = c010[i] * (1 - rFrac) + c110[i] * rFrac;
      final c11 = c011[i] * (1 - rFrac) + c111[i] * rFrac;

      final c0 = c00 * (1 - gFrac) + c10 * gFrac;
      final c1 = c01 * (1 - gFrac) + c11 * gFrac;

      result[i] = c0 * (1 - bFrac) + c1 * bFrac;
    }

    return result;
  }

  /// 获取LUT中指定位置的RGB值
  List<double> _getLutValue(int r, int g, int b) {
    final index = (b * lutSize * lutSize + g * lutSize + r) * 3;
    return [
      lutData[index],
      lutData[index + 1],
      lutData[index + 2],
    ];
  }

  /// 处理图像数据
  Uint8List processImageData(Uint8List imageData, int width, int height, double mixStrength) {
    final result = Uint8List(imageData.length);
    
    for (int i = 0; i < imageData.length; i += 4) {
      final r = imageData[i];
      final g = imageData[i + 1];
      final b = imageData[i + 2];
      final a = imageData[i + 3];

      final processed = applyLutToRgb(r, g, b, mixStrength);
      
      result[i] = processed[0];
      result[i + 1] = processed[1];
      result[i + 2] = processed[2];
      result[i + 3] = a;
    }

    return result;
  }
}
