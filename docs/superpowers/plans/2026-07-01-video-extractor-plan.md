# 视频提取工具 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** 构建一个基于 Flutter 的全平台视频提取工具，并使用 Python 部署独立的无水印视频解析后端 API 服务。

**Architecture:** 客户端/服务端架构。后端使用 Python 提供轻量级 REST API (利用 FastAPI)；前端使用 Flutter 实现工具箱首页和视频提取页面，利用 dio 进行网络请求，利用 ideo_player 预览视频，利用 path_provider 和 dio 实现文件下载。为了实现快速开发，我们将先搭建一个最基础的 Mock 后端 API 或直接接入公共免费 API，保证全链路打通。

**Tech Stack:** Flutter, Dart, Python, FastAPI, uvicorn

## 2026-07-02 Maintenance Update

真实联调中发现“解析失败”并非前端按钮失效，而是后端 URL 提取规则过宽：平台分享文案里的中文逗号、句号、右括号和后续说明文字会被一起传给 `yt-dlp`。已新增 `backend/test_main.py` 回归测试，并修正 `backend/main.py` 的 `find_first_url()`。

当前后端实现仍以 `yt-dlp` 为主；早期说明里的“双引擎”属于目标方向，不应当当作已完成能力。若继续出现平台兼容问题，下一步应先记录后端 `detail` 错误，再评估是否加入第二解析引擎或平台专用解析器。

2026-07-02 追加：先按用户选择聚焦 B 站。`backend/main.py` 已增加 B 站专用路径：识别 B 站 URL、解析 BV 号、调用 B 站 view/playurl API、通过 `/api/stream` 后端代理输出可播放地址。这样可以绕开前端直连 B 站 CDN 时缺少 `Referer` 的问题。

当前 B 站支持范围：

- 支持 `www.bilibili.com/video/BV...`。
- 支持 `b23.tv` 短链跳转。
- 优先使用 B 站返回的 `durl` 单文件视频流。
- 暂不支持只有 DASH 分离音视频流的合流播放。

2026-07-02 追加：开始按平台逐个接入，主流平台路线为：B站、抖音、快手、小红书、西瓜视频、微博视频、YouTube、Vimeo、腾讯视频、爱奇艺、优酷、芒果TV、搜狐视频、微信视频号。抖音已新增专用入口：识别 `douyin.com` 子域，`v.douyin.com` 短链先跳转，再交给 `yt-dlp`，返回结果中标记 `platform: douyin`。

运行验证：

```powershell
python -m unittest backend.test_main
```

预期结果：`Ran 7 tests ... OK`。

---

### Task 1: Initialize Flutter Project

**Files:**
- Create: lutter_app/ (Flutter project root)

- [ ] **Step 1: Create Flutter Project**

`ash
flutter create --org com.toolbox --project-name toolbox_app flutter_app
`

- [ ] **Step 2: Run tests to verify setup**

Run: cd flutter_app && flutter test
Expected: PASS

- [ ] **Step 3: Commit**

`ash
git add flutter_app/
git commit -m "chore: initialize flutter project toolbox_app"
`

### Task 2: Add Flutter Dependencies

**Files:**
- Modify: lutter_app/pubspec.yaml

- [ ] **Step 1: Add dependencies via flutter pub add**

`ash
cd flutter_app && flutter pub add dio video_player path_provider permission_handler gal
`

- [ ] **Step 2: Run pub get**

`ash
cd flutter_app && flutter pub get
`

- [ ] **Step 3: Commit**

`ash
git add flutter_app/pubspec.yaml flutter_app/pubspec.lock
git commit -m "chore: add dependencies dio, video_player, path_provider, permission_handler, gal"
`

### Task 3: Setup Backend API (Python FastAPI Mock)

**Files:**
- Create: ackend/main.py
- Create: ackend/requirements.txt

- [ ] **Step 1: Create requirements.txt**

`	ext
fastapi
uvicorn
`
Write to ackend/requirements.txt.

- [ ] **Step 2: Create main.py (Mock API)**

`python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import re

app = FastAPI()

class ExtractRequest(BaseModel):
    url_text: str

@app.post("/api/extract")
def extract_video(request: ExtractRequest):
    # Extract url from text (basic regex)
    url_pattern = re.compile(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+')
    urls = url_pattern.findall(request.url_text)
    
    if not urls:
        raise HTTPException(status_code=400, detail="No valid URL found in text")
    
    # In a real app, you would pass urls[0] to a real parser (like Douyin_TikTok_Download_API).
    # Here we return a mock response with a valid test video URL.
    return {
        "title": "测试视频 - 这是一个演示",
        "cover_url": "https://storage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg",
        "video_url": "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    }
`
Write to ackend/main.py.

- [ ] **Step 3: Run backend and verify with curl (manual check)**

`ash
# Run in a separate terminal: cd backend && pip install -r requirements.txt && uvicorn main:app --port 8000
# Then run:
curl -X POST http://127.0.0.1:8000/api/extract -H "Content-Type: application/json" -d '{"url_text": "look at this https://v.douyin.com/abcde/"}'
`
Expected output: JSON with 	itle, cover_url, and ideo_url.

- [ ] **Step 4: Commit**

`ash
git add backend/
git commit -m "feat: add mock python backend api for video extraction"
`

### Task 4: Create API Client in Flutter

**Files:**
- Create: lutter_app/lib/api/video_api.dart

- [ ] **Step 1: Write API Client Code**

`dart
import 'package:dio/dio.dart';

class VideoExtractionResult {
  final String title;
  final String coverUrl;
  final String videoUrl;

  VideoExtractionResult({required this.title, required this.coverUrl, required this.videoUrl});

  factory VideoExtractionResult.fromJson(Map<String, dynamic> json) {
    return VideoExtractionResult(
      title: json['title'] ?? 'Unknown Title',
      coverUrl: json['cover_url'] ?? '',
      videoUrl: json['video_url'] ?? '',
    );
  }
}

class VideoApi {
  final Dio _dio;

  // For Android emulator, 10.0.2.2 points to host localhost.
  // For Windows/Mac desktop apps, 127.0.0.1 points to localhost.
  // We'll use localhost for desktop, 10.0.2.2 as fallback.
  VideoApi() : _dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000'));

  Future<VideoExtractionResult> extractVideo(String text) async {
    try {
      final response = await _dio.post('/api/extract', data: {'url_text': text});
      return VideoExtractionResult.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to extract video: \');
    }
  }
}
`
Write to lutter_app/lib/api/video_api.dart.

- [ ] **Step 2: Commit**

`ash
git add flutter_app/lib/api/video_api.dart
git commit -m "feat: add flutter api client for video extraction"
`

### Task 5: Build Home Page (Toolbox Grid)

**Files:**
- Modify: lutter_app/lib/main.dart
- Create: lutter_app/lib/pages/home_page.dart

- [ ] **Step 1: Create home_page.dart**

`dart
import 'package:flutter/material.dart';
import 'video_extractor_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实用小工具集合'),
        centerTitle: true,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: [
          _buildToolCard(
            context,
            title: '全平台视频提取',
            icon: Icons.video_library,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VideoExtractorPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
`
Write to lutter_app/lib/pages/home_page.dart.

- [ ] **Step 2: Modify main.dart to use HomePage**

`dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const ToolboxApp());
}

class ToolboxApp extends StatelessWidget {
  const ToolboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toolbox App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
`
Replace content of lutter_app/lib/main.dart.

- [ ] **Step 3: Commit**

`ash
git add flutter_app/lib/main.dart flutter_app/lib/pages/home_page.dart
git commit -m "feat: create toolbox home page UI"
`

### Task 6: Build Video Extractor UI Structure

**Files:**
- Create: lutter_app/lib/pages/video_extractor_page.dart

- [ ] **Step 1: Write initial UI skeleton without API integration**

`dart
import 'package:flutter/material.dart';

class VideoExtractorPage extends StatefulWidget {
  const VideoExtractorPage({super.key});

  @override
  State<VideoExtractorPage> createState() => _VideoExtractorPageState();
}

class _VideoExtractorPageState extends State<VideoExtractorPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onExtractPressed() {
    // Placeholder for extraction logic
    setState(() {
      _isLoading = true;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全平台视频提取')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '请在此粘贴视频链接（例如：抖音、B站、快手、YouTube等）\n可包含分享口令',
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
          ],
        ),
      ),
    );
  }
}
`
Write to lutter_app/lib/pages/video_extractor_page.dart.

- [ ] **Step 2: Commit**

`ash
git add flutter_app/lib/pages/video_extractor_page.dart
git commit -m "feat: build skeleton UI for video extractor page"
`

### Task 7: Integrate API and Display Result

**Files:**
- Modify: lutter_app/lib/pages/video_extractor_page.dart

- [ ] **Step 1: Add API call and Result UI**

`dart
import 'package:flutter/material.dart';
import '../api/video_api.dart';
// import 'video_player_page.dart'; // Future import

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
                hintText: '请在此粘贴视频链接\n支持混合文本',
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
                      // TODO: Navigate to player
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('下载保存'),
                    onPressed: () {
                      // TODO: Download logic
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
`
Replace content of lutter_app/lib/pages/video_extractor_page.dart.

- [ ] **Step 2: Commit**

`ash
git add flutter_app/lib/pages/video_extractor_page.dart
git commit -m "feat: integrate api with video extractor page"
`

### Task 8: Implement Video Player View

**Files:**
- Create: lutter_app/lib/pages/video_player_page.dart
- Modify: lutter_app/lib/pages/video_extractor_page.dart

- [ ] **Step 1: Write video_player_page.dart**

`dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerPage({super.key, required this.videoUrl, required this.title});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    Center(
                      child: IconButton(
                        iconSize: 64,
                        icon: Icon(
                          _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying ? _controller.pause() : _controller.play();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
`

- [ ] **Step 2: Connect Player in Extractor Page**
In lutter_app/lib/pages/video_extractor_page.dart, add the import:
import 'video_player_page.dart';
And update the "直接播放" button's onPressed:
`dart
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
`

- [ ] **Step 3: Commit**

`ash
git add flutter_app/lib/pages/video_player_page.dart flutter_app/lib/pages/video_extractor_page.dart
git commit -m "feat: add video player page"
`

### Task 9: Implement File Download and Save

**Files:**
- Create: lutter_app/lib/services/download_service.dart
- Modify: lutter_app/lib/pages/video_extractor_page.dart

- [ ] **Step 1: Write download service**

`dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<void> downloadAndSave(String url, String filename, Function(int, int) onProgress) async {
    // Check permission for gallery
    bool hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      hasAccess = await Gal.requestAccess();
      if (!hasAccess) {
        throw Exception("需要相册或存储权限才能保存视频");
      }
    }

    // Get temp directory to store downloaded file
    final dir = await getTemporaryDirectory();
    final savePath = '\/.mp4';

    // Download file
    await _dio.download(
      url, 
      savePath, 
      onReceiveProgress: onProgress,
    );

    // Save to gallery
    await Gal.putVideo(savePath);
    
    // Clean up temp file
    final file = File(savePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
`
Write to lutter_app/lib/services/download_service.dart.

- [ ] **Step 2: Connect Download button in UI**
In lutter_app/lib/pages/video_extractor_page.dart, import the service:
import '../services/download_service.dart';

Add state variables in _VideoExtractorPageState:
`dart
bool _isDownloading = false;
double _downloadProgress = 0.0;
`

Update the "下载保存" button block:
`dart
Expanded(
  child: _isDownloading 
  ? Column(
      children: [
        LinearProgressIndicator(value: _downloadProgress),
        Text('\%'),
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
            "video_\",
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载失败: ')));
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
`

- [ ] **Step 3: Commit**

`ash
git add flutter_app/lib/services/download_service.dart flutter_app/lib/pages/video_extractor_page.dart
git commit -m "feat: implement download and save to gallery"
`

