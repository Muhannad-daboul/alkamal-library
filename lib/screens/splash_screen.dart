import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _ctrl;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goHome());
      return;
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  Future<void> _initVideo() async {
    _ctrl = VideoPlayerController.asset('assets/videos/splash.mp4');
    try {
      await _ctrl.initialize().timeout(const Duration(seconds: 5));
      _ctrl.addListener(_onVideoUpdate);
      if (mounted) {
        setState(() => _videoReady = true);
        await _ctrl.play();
      }
    } catch (_) {
      _goHome();
    }
  }

  void _onVideoUpdate() {
    final val = _ctrl.value;
    if (val.isInitialized &&
        val.duration.inMilliseconds > 0 &&
        !val.isPlaying &&
        !val.isBuffering &&
        val.position.inMilliseconds >= val.duration.inMilliseconds - 200) {
      _goHome();
    }
  }

  void _goHome() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (!mounted) return;
    final route = hasOnboarded ? '/home' : '/onboarding';
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    if (_videoReady) {
      _ctrl.removeListener(_onVideoUpdate);
      _ctrl.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _videoReady
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _ctrl.value.size.width,
                  height: _ctrl.value.size.height,
                  child: VideoPlayer(_ctrl),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
