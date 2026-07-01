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
    final savePath = '\/\.mp4';

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
