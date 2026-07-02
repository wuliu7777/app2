import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import '../../api/video_api.dart';
import '../../services/download_service.dart';
import '../../widgets/ambient_background.dart';

import 'widgets/video_input_area.dart';

class VideoExtractorPage extends StatefulWidget {
  const VideoExtractorPage({super.key});

  @override
  State<VideoExtractorPage> createState() => _VideoExtractorPageState();
}

class _VideoExtractorPageState extends State<VideoExtractorPage> with WidgetsBindingObserver {
  final List<InputRowData> _rows = [InputRowData(controller: TextEditingController())];
  final VideoApi _api = VideoApi();

  bool _isLoading = false;
  int _currentParseIndex = 0;
  int _totalParseCount = 0;
  String _lastCheckedClipboardText = "";
  String? _clipboardUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        final text = data.text!.trim();
        if (text.startsWith('http') && text != _lastCheckedClipboardText) {
          if (mounted) {
            setState(() {
              _lastCheckedClipboardText = text;
              _clipboardUrl = text;
            });
            _showToast('检测到视频链接');
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }

  void _showToast(String message, {bool isError = false}) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isError ? Colors.redAccent.withOpacity(0.9) : Colors.black87,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ]
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        );
      }
    );
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _onTextChanged(int index, String text) {
    if (text.contains('\n')) {
      final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (lines.length > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _rows[index].controller.text = lines.first;
            _rows[index].state = RowState.idle;
            for (int i = 1; i < lines.length; i++) {
              _rows.insert(
                  index + i,
                  InputRowData(
                      controller: TextEditingController(text: lines[i])));
            }
          });
        });
      } else {
        setState(() {
          _rows[index].state = RowState.idle;
        });
      }
    } else {
      setState(() {
         _rows[index].state = RowState.idle;
      });
    }
  }

  void _handleAddLine() {
    setState(() {
      _rows.add(InputRowData(controller: TextEditingController()));
    });
  }

  void _handleRemoveLine(int index) {
    setState(() {
      _rows[index].controller.dispose();
      _rows.removeAt(index);
      if (_rows.isEmpty) {
        _rows.add(InputRowData(controller: TextEditingController()));
      }
    });
  }

  void _handleClearAll() {
    setState(() {
      for (var row in _rows) {
        row.controller.dispose();
      }
      _rows.clear();
      _rows.add(InputRowData(controller: TextEditingController()));
    });
  }

  void _handleResetRow(int index) {
    setState(() {
      _rows[index].state = RowState.idle;
      _rows[index].result = null;
    });
  }

  Future<void> _onExtractPressed() async {
    final pendingIndices = <int>[];
    for (int i = 0; i < _rows.length; i++) {
      if (_rows[i].controller.text.trim().isNotEmpty &&
          (_rows[i].state == RowState.idle || _rows[i].state == RowState.error)) {
        pendingIndices.add(i);
      }
    }

    if (pendingIndices.isEmpty) {
      _showToast("没有需要解析的有效链接", isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _totalParseCount = pendingIndices.length;
      _currentParseIndex = 0;
    });

    for (int i = 0; i < pendingIndices.length; i++) {
      if (!mounted) break;
      final rowIndex = pendingIndices[i];
      
      setState(() {
        _currentParseIndex = i + 1;
        _rows[rowIndex].state = RowState.loading;
      });

      try {
        final res = await _api.extractVideo(_rows[rowIndex].controller.text.trim());
        if (mounted) {
          setState(() {
            _rows[rowIndex].state = RowState.success;
            _rows[rowIndex].result = res;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _rows[rowIndex].state = RowState.error;
          });
          _showToast("第 ${rowIndex + 1} 行解析失败", isError: true);
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startDownload(int index) async {
    final row = _rows[index];
    if (row.result == null) return;

    setState(() {
      row.isDownloading = true;
      row.downloadProgress = 0.0;
    });
    try {
      final service = DownloadService();
      final filename = "video_${index + 1}";
      
      await service.downloadAndSave(
        row.result!.videoUrl,
        filename,
        (received, total) {
          if (total != -1) {
            setState(() {
              row.downloadProgress = received / total;
            });
          }
        },
      );
      if (mounted) {
        _showToast('$filename 下载成功，已保存');
      }
    } catch (e) {
      if (mounted) {
        _showToast('下载失败: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          row.isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('视频提取', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ],
      ),
      floatingActionButton: isDesktop ? null : Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : _onExtractPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '排队中 ($_currentParseIndex/$_totalParseCount)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      '批量解析',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.only(left: 32.0, right: 32.0, top: 32.0, bottom: 100.0),
          child: ListView(
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              VideoInputArea(
                rows: _rows,
                clipboardUrl: _clipboardUrl,
                onTextChanged: _onTextChanged,
                onAddLine: _handleAddLine,
                onClearAll: _handleClearAll,
                onRemoveLine: _handleRemoveLine,
                onResetRow: _handleResetRow,
                onDownload: _startDownload,
                showExtractButton: true,
                isLoading: _isLoading,
                currentParseIndex: _currentParseIndex,
                totalParseCount: _totalParseCount,
                onExtractPressed: _onExtractPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 100.0),
          children: [
            VideoInputArea(
              rows: _rows,
              clipboardUrl: _clipboardUrl,
              onTextChanged: _onTextChanged,
              onAddLine: _handleAddLine,
              onClearAll: _handleClearAll,
              onRemoveLine: _handleRemoveLine,
              onResetRow: _handleResetRow,
              onDownload: _startDownload,
              showExtractButton: false,
              isLoading: _isLoading,
              onExtractPressed: _onExtractPressed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFC4B5FD), Color(0xFF93C5FD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                '粘贴视频链接',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '支持多行批量输入，第一个链接解析完了，自动开始解析第2个，所有下载文件都会按先后顺序智能命名。',
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white60 : Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
