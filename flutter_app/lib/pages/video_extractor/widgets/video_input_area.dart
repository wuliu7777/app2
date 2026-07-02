import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../widgets/glass_card.dart';
import '../../../api/video_api.dart';
import '../../video_player_page.dart';

OverlayEntry? _activeFloatingPlayer;

class FloatingVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final VoidCallback onClose;
  final VoidCallback onFullScreen;

  const FloatingVideoPlayer({
    super.key, 
    required this.videoUrl, 
    required this.title, 
    required this.onClose,
    required this.onFullScreen,
  });

  @override
  State<FloatingVideoPlayer> createState() => _FloatingVideoPlayerState();
}

class _FloatingVideoPlayerState extends State<FloatingVideoPlayer> {
  double x = -1;
  double y = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (x == -1) {
      final size = MediaQuery.of(context).size;
      x = size.width - 420;
      y = size.height - 300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            x += details.delta.dx;
            y += details.delta.dy;
          });
        },
        child: Material(
          elevation: 24,
          borderRadius: BorderRadius.circular(16),
          color: Colors.black,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 400,
            height: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayerPage(
                  videoUrl: widget.videoUrl,
                  title: widget.title,
                  isFloating: true,
                  onClose: widget.onClose,
                  onFullScreen: widget.onFullScreen,
                ),
                if (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android)
                  Center(
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: widget.onFullScreen,
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Icon(Icons.fullscreen_rounded, size: 48, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayActionGroup extends StatefulWidget {
  final VoidCallback onPlaySmall;
  final VoidCallback onPlayFull;

  const _PlayActionGroup({required this.onPlaySmall, required this.onPlayFull});

  @override
  State<_PlayActionGroup> createState() => _PlayActionGroupState();
}

class _PlayActionGroupState extends State<_PlayActionGroup> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isTouch = Theme.of(context).platform == TargetPlatform.iOS || 
                    Theme.of(context).platform == TargetPlatform.android;
    final showFull = _isHovered || isTouch;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        width: 88, // 固定宽度预留全屏按钮空间，避免挤压右侧按钮
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 全屏按钮（从右向左滑出）
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: showFull ? 0 : 40,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: showFull ? 1.0 : 0.0,
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.green),
                  onPressed: showFull ? widget.onPlayFull : null,
                  tooltip: '全屏播放',
                ),
              ),
            ),
            // 小窗播放按钮（位置绝对固定）
            Positioned(
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.green),
                onPressed: widget.onPlaySmall,
                tooltip: '小窗播放',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum RowState {
  idle,
  loading,
  success,
  error,
}

class InputRowData {
  TextEditingController controller;
  RowState state;
  VideoExtractionResult? result;
  bool isDownloading;
  double downloadProgress;

  InputRowData({
    required this.controller,
    this.state = RowState.idle,
    this.result,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });
}

class VideoInputArea extends StatelessWidget {
  final List<InputRowData> rows;
  final String? clipboardUrl;
  final Function(int, String) onTextChanged;
  final VoidCallback onAddLine;
  final VoidCallback onClearAll;
  final Function(int) onRemoveLine;
  final Function(int) onResetRow;
  final Function(int) onDownload;
  final bool showExtractButton;
  final bool isLoading;
  final int currentParseIndex;
  final int totalParseCount;
  final VoidCallback? onExtractPressed;

  const VideoInputArea({
    super.key,
    required this.rows,
    this.clipboardUrl,
    required this.onTextChanged,
    required this.onAddLine,
    required this.onClearAll,
    required this.onRemoveLine,
    required this.onResetRow,
    required this.onDownload,
    this.showExtractButton = false,
    this.isLoading = false,
    this.currentParseIndex = 0,
    this.totalParseCount = 0,
    this.onExtractPressed,
  });

  Widget _buildRow(BuildContext context, int index, bool isDark) {
    final row = rows[index];
    final isFirstRow = index == 0;
    final rowBorderRadius = isFirstRow
        ? const BorderRadius.vertical(top: Radius.circular(24))
        : BorderRadius.zero;

    return Stack(
      children: [
        // 基础输入层
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.controller,
                maxLines: 1,
                onChanged: (text) => onTextChanged(index, text),
                onSubmitted: (_) {
                  if (!isLoading && onExtractPressed != null) {
                    onExtractPressed!();
                  }
                },
                style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: '在这里粘贴视频链接...',
                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: row.controller.text.isNotEmpty
                  ? IconButton(
                      key: const ValueKey('close'),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: isDark ? Colors.white30 : Colors.black38,
                      onPressed: () {
                        row.controller.clear();
                        onTextChanged(index, '');
                        // 如果需要整行删除，也可以换成 onRemoveLine(index)
                      },
                      tooltip: '清空内容',
                    )
                  : (clipboardUrl != null
                      ? IconButton(
                          key: const ValueKey('paste'),
                          icon: const Icon(Icons.content_paste_rounded, size: 20),
                          color: const Color(0xFF3B82F6),
                          onPressed: () {
                            row.controller.text = clipboardUrl!;
                            onTextChanged(index, clipboardUrl!);
                          },
                          tooltip: '粘贴链接',
                        )
                      : const SizedBox.shrink(key: ValueKey('empty'))),
            ),
            const SizedBox(width: 8),
          ],
        ),

        // 加载态（底部动画线条）
        if (row.state == RowState.loading)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),

        // 成功态（绿色毛玻璃遮罩层，含播放和下载按钮）
        if (row.state == RowState.success && row.result != null)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: rowBorderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: rowBorderRadius,
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(isDark ? 0.2 : 0.4),
                      width: 1,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.greenAccent.withOpacity(isDark ? 0.15 : 0.25),
                        Colors.greenAccent.withOpacity(isDark ? 0.05 : 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (row.isDownloading)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: row.downloadProgress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF059669).withOpacity(0.5) : const Color(0xFF10B981).withOpacity(0.4),
                                borderRadius: rowBorderRadius,
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          const SizedBox(width: 16),
                      // 缩略图
                      if (row.result!.coverUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            row.result!.coverUrl,
                            width: 50,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              width: 50,
                              height: 40,
                              color: Colors.black12,
                              child: const Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      // 标题
                      Expanded(
                        child: Text(
                          row.result!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      // 操作按钮
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PlayActionGroup(
                            onPlaySmall: () {
                              _activeFloatingPlayer?.remove();
                              _activeFloatingPlayer = OverlayEntry(
                                builder: (context) => FloatingVideoPlayer(
                                  videoUrl: row.result!.videoUrl,
                                  title: row.result!.title,
                                  onClose: () {
                                    _activeFloatingPlayer?.remove();
                                    _activeFloatingPlayer = null;
                                  },
                                  onFullScreen: () {
                                    _activeFloatingPlayer?.remove();
                                    _activeFloatingPlayer = null;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => VideoPlayerPage(
                                          videoUrl: row.result!.videoUrl,
                                          title: row.result!.title,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                              Overlay.of(context).insert(_activeFloatingPlayer!);
                            },
                            onPlayFull: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideoPlayerPage(
                                    videoUrl: row.result!.videoUrl,
                                    title: row.result!.title,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (row.isDownloading)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                '${(row.downloadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.download_rounded, color: Colors.green),
                              onPressed: () => onDownload(index),
                            ),
                          
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 20, color: Colors.green),
                            onPressed: () => onResetRow(index),
                            tooltip: '重新编辑链接',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.green),
                            onPressed: () => onRemoveLine(index),
                            tooltip: '清除此行',
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
                ),
              ),
            ),
          ),

        // 失败态（红色毛玻璃遮罩层，点击重置）
        if (row.state == RowState.error)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: rowBorderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onResetRow(index),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: rowBorderRadius,
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(isDark ? 0.2 : 0.4),
                          width: 1,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent.withOpacity(isDark ? 0.15 : 0.25),
                            Colors.redAccent.withOpacity(isDark ? 0.05 : 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '解析失败，点击重新编辑',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.redAccent.shade100 : Colors.redAccent.shade700,
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                  _buildRow(context, i, isDark),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                TextButton.icon(
                  onPressed: onAddLine,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('添加一行'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                TextButton.icon(
                  onPressed: onClearAll,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('全部清空'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white54 : Colors.black54,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (showExtractButton)
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: isLoading ? null : onExtractPressed,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          child: isLoading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '排队中 ($currentParseIndex/$totalParseCount)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  '批量解析',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
