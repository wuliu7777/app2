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
      throw Exception('Failed to extract video: \$e');
    }
  }
}
