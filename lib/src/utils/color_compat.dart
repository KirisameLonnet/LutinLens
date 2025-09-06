import 'package:flutter/material.dart';

// Compatibility shim for Flutter versions prior to Color.withValues.
// If the SDK already provides withValues, the instance member is used and
// this extension is ignored. We only support the 'alpha' named argument here
// because the codebase only uses it.
extension ColorWithValuesCompat on Color {
  Color withValues({double? alpha}) {
    return withOpacity(alpha ?? (this.alpha / 255.0));
  }
}

