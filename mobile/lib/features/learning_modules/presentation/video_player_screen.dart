import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/config/api_config.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String filePath;

  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.filePath,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  String _resolveMediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    return '${ApiConfig.baseUrl}$normalized';
  }

  Future<void> _initPlayer() async {
    final url = _resolveMediaUrl(widget.filePath);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      await controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split('/').last;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF2D2323),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildPlayer(fileName),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text(
                'Playing from ${_resolveMediaUrl(widget.filePath)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(String fileName) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade200, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load video.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              fileName,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        Container(
          color: Colors.black87,
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                  });
                },
              ),
              Expanded(
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.orange.shade400,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }
}
