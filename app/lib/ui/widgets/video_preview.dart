import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String? videoPath;

  const VideoPreviewWidget({super.key, this.videoPath});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    // Dispose old controller
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _initialized = false;
    }

    if (widget.videoPath == null) {
      if (mounted) setState(() {});
      return;
    }

    final isNetwork = widget.videoPath!.startsWith('http://') || widget.videoPath!.startsWith('https://');
    if (!isNetwork && !File(widget.videoPath!).existsSync()) {
      if (mounted) setState(() {});
      return;
    }

    if (isNetwork) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath!));
    } else {
      _controller = VideoPlayerController.file(File(widget.videoPath!));
    }
    
    try {
      await _controller!.initialize();
      _controller!.setLooping(true);
      
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _controller!.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialized = false;
        });
      }
      print("VideoPlayer failed to initialize: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoPath == null) {
      return _buildPlaceholder("No Video Generated Yet");
    }

    if (!_initialized || _controller == null) {
      return _buildPlaceholder("Loading Video...");
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          // Play/Pause Overlay
          GestureDetector(
            onTap: () {
              setState(() {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Progress Bar
          Positioned(
             bottom: 0,
             left: 0,
             right: 0,
             child: VideoProgressIndicator(
               _controller!, 
               allowScrubbing: true,
               colors: VideoProgressColors(
                 playedColor: Theme.of(context).colorScheme.primary,
                 backgroundColor: Colors.white24,
               ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String text) {
    final bool hasError = text == "Loading Video..." && !_initialized && widget.videoPath != null;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_creation_outlined, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              hasError ? "Video Generated Successfully!" : text,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
            ),
            if (hasError && widget.videoPath != null && !widget.videoPath!.startsWith('http')) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (Platform.isLinux) {
                    Process.run('xdg-open', [widget.videoPath!]);
                  } else if (Platform.isWindows) {
                    Process.run('explorer', [widget.videoPath!]);
                  } else if (Platform.isMacOS) {
                    Process.run('open', [widget.videoPath!]);
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text("Open Video in External Player"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Internal player is unsupported on Linux.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
