import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _videoController;
  Timer? _fallbackTimer;
  var _isReady = false;
  var _hasFinished = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/videos/splash.mp4')
      ..addListener(_handleVideoState);
    _fallbackTimer = Timer(const Duration(seconds: 10), _finish);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _videoController.initialize();
      if (!mounted || _hasFinished) return;

      setState(() => _isReady = true);
      await _videoController.play();
    } catch (_) {
      _finish();
    }
  }

  void _handleVideoState() {
    final value = _videoController.value;
    if (value.hasError || value.isCompleted) {
      _finish();
    }
  }

  void _finish() {
    if (_hasFinished) return;
    _hasFinished = true;
    _fallbackTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _videoController
      ..removeListener(_handleVideoState)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoSize = _videoController.value.size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: !_isReady
            ? const ColoredBox(color: Colors.black)
            : ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: videoSize.width,
                    height: videoSize.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              ),
      ),
    );
  }
}
