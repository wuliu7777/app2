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
    // 【测试捷径】如果输入的文字包含 "ok"，直接模拟返回成功的数据
    if (text.toLowerCase().contains('ok')) {
      await Future.delayed(const Duration(seconds: 1)); // 模拟1秒网络延迟
      return VideoExtractionResult(
        title: '测试视频：令人惊叹的赛博朋克城市风景 4K',
        coverUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?q=80&w=200&auto=format&fit=crop',
        videoUrl: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      );
    }

    try {
      final response = await _dio.post('/api/extract', data: {'url_text': text});
      return VideoExtractionResult.fromJson(response.data);
    } catch (e) {
      if (e is DioException) {
        throw Exception('网络请求失败: ${e.message} ${e.response?.data}');
      }
      throw Exception('Failed to extract video: $e');
    }
  }
}
