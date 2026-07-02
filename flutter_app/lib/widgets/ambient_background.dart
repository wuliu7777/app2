import 'package:flutter/material.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      // 摒弃一切渐变和光效，回归最纯粹极致的纯色背景
      // 深色采用 Apple 风格的高级纯深空灰，浅色采用干净的珍珠白
      color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7), 
    );
  }
}
