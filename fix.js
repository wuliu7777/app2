const fs = require('fs');
const content = "import 'package:flutter/material.dart';
import '../api/video_api.dart';
import 'video_player_page.dart';
import '../services/download_service.dart';

class VideoExtractorPage extends StatefulWidget {
  const VideoExtractorPage({super.key});

  @override
  State<VideoExtractorPage> createState() => _VideoExtractorPageState();
}

class _VideoExtractorPageState extends State<VideoExtractorPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  VideoExtractionResult? _result;
  String? _errorMessage;
  final VideoApi _api = VideoApi();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _onExtractPressed() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final res = await _api.extractVideo(text);
      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全平台视频提取')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '请在此粘贴视频链接\\n支持混合文本',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _onExtractPressed,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Text('开始解析', style: TextStyle(fontSize: 16)),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildResultCard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(VideoExtractionResult result) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.coverUrl.isNotEmpty) 
              Image.network(result.coverUrl, height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 100)),
            const SizedBox(height: 16),
            Text(result.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('直接播放'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerPage(
                            videoUrl: result.videoUrl,
                            title: result.title,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _isDownloading 
                  ? Column(
                      children: [
                        LinearProgressIndicator(value: _downloadProgress),
                        Text('\\\\\\%'),
                      ],
                    )
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('下载保存'),
                      onPressed: () async {
                        setState(() {
                          _isDownloading = true;
                          _downloadProgress = 0.0;
                        });
                        try {
                          final service = DownloadService();
                          await service.downloadAndSave(
                            result.videoUrl, 
                            'video_\\\\\',
                            (received, total) {
                              if (total != -1) {
                                setState(() {
                                  _downloadProgress = received / total;
                                });
                              }
                            }
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('下载成功，已保存至相册/系统下载目录')));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载失败: \\\\\')));
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isDownloading = false;
                            });
                          }
                        }
                      },
                    ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
";
fs.writeFileSync('.worktrees/feature-video-extractor/flutter_app/lib/pages/video_extractor_page.dart', content, 'utf8');
