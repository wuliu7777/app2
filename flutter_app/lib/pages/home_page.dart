import 'dart:ui';
import 'package:flutter/material.dart';
import 'video_extractor/video_extractor_page.dart';
import '../widgets/ambient_background.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 全局统一高级环境光效背景
          const Positioned.fill(child: AmbientBackground()),

          // 主内容区域
          isDesktop ? _buildDesktopHome(isDark) : _buildMobileHome(isDark),
        ],
      ),
    );
  }

  // ============== 桌面端专属布局 ==============
  Widget _buildDesktopHome(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 24.0, top: 12.0),
              child: _buildDesktopMenuButton(isDark),
            ),
          ],
        ),
        // 从左上角开始排布，不使用居中和最大宽度限制
        SliverPadding(
          padding: const EdgeInsets.only(top: 24.0, left: 32.0, right: 32.0, bottom: 40.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              mainAxisSpacing: 24.0,
              crossAxisSpacing: 24.0,
              mainAxisExtent: 220,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return _GlassToolCard(
                    title: '视频提取',
                    description: '一键获取各大平台无水印视频',
                    icon: Icons.smart_display_rounded,
                    gradientColors: const [Color(0xFF8B5CF6), Color(0xFF3B82F6)], // 紫蓝
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VideoExtractorPage(),
                        ),
                      );
                    },
                  );
                } else if (index == 1) {
                  return _GlassToolCard(
                    title: '图片压缩',
                    description: '本地高效无损压缩图片大小',
                    icon: Icons.image_rounded,
                    gradientColors: const [Color(0xFF10B981), Color(0xFF059669)], // 翠绿
                    onTap: () {},
                  );
                }
                return null;
              },
              childCount: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopMenuButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz_rounded, color: isDark ? Colors.white : Colors.black87),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Theme.of(context).cardColor,
        elevation: 8,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 8),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'home',
            child: Row(
              children: [
                Icon(Icons.home_rounded, size: 20, color: Theme.of(context).iconTheme.color),
                const SizedBox(width: 12),
                const Text('主页', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings_rounded, size: 20, color: Theme.of(context).iconTheme.color),
                const SizedBox(width: 12),
                const Text('设置', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          // 处理菜单点击
        },
      ),
    );
  }

  // ============== 移动端专属布局 ==============
  Widget _buildMobileHome(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.transparent, // 完全透明，融入环境光
          elevation: 0,
          scrolledUnderElevation: 0,
          // 删除了“实用工具箱”文字标题
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : Colors.black87),
                onPressed: () {},
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 移动端改为3列
              mainAxisSpacing: 12.0,
              crossAxisSpacing: 12.0,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildListDelegate([
              _MobileGlassToolCard(
                title: '视频提取',
                icon: Icons.smart_display_rounded,
                gradientColors: const [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VideoExtractorPage(),
                    ),
                  );
                },
              ),
              _MobileGlassToolCard(
                title: '图片压缩',
                icon: Icons.image_rounded,
                gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                onTap: () {},
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// 桌面端高级质感玻璃卡片
class _GlassToolCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _GlassToolCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_GlassToolCard> createState() => _GlassToolCardState();
}

class _GlassToolCardState extends State<_GlassToolCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(_isHovered ? 0.2 : 0.08)
                      : Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradientColors.first.withOpacity(_isHovered ? 0.15 : 0.0),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: widget.gradientColors.first.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(widget.icon, size: 28, color: Colors.white),
                        ),
                        const Spacer(),
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 移动端质感玻璃卡片 (重新设计)
class _MobileGlassToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _MobileGlassToolCard({
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors.first.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 24, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
