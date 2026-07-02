import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;
  final bool isFloating;
  final VoidCallback? onClose;
  final VoidCallback? onFullScreen;

  const VideoPlayerPage({
    super.key, 
    required this.videoUrl, 
    required this.title,
    this.isFloating = false,
    this.onClose,
    this.onFullScreen,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isFloating) {
      _setLandscape();
    }
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  void _setLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() => _isLandscape = true);
  }

  void _setPortrait() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    setState(() => _isLandscape = false);
  }

  void _toggleOrientation() {
    if (_isLandscape) {
      _setPortrait();
    } else {
      _setLandscape();
    }
  }

  @override
  void dispose() {
    if (!widget.isFloating) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isFloating,
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
        actions: [
          if (!widget.isFloating)
            IconButton(
              icon: Icon(_isLandscape ? Icons.screen_lock_portrait_rounded : Icons.screen_lock_landscape_rounded),
              onPressed: _toggleOrientation,
              tooltip: _isLandscape ? '切换为竖屏' : '切换为横屏',
            ),
          if (widget.isFloating && widget.onFullScreen != null)
            IconButton(
              icon: const Icon(Icons.fullscreen_rounded),
              onPressed: widget.onFullScreen,
              tooltip: '全屏播放',
            ),
          if (widget.isFloating && widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: widget.onClose,
              tooltip: '关闭小窗',
            ),
        ],
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
