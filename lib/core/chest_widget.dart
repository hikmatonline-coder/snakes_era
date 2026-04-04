import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SpriteChest extends StatefulWidget {
  final String assetPath;
  final bool isOpen;
  final VoidCallback onTap;

  const SpriteChest({
    super.key,
    required this.assetPath,
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<SpriteChest> createState() => _SpriteChestState();
}

class _SpriteChestState extends State<SpriteChest> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _frameAnimation;
  final int totalFrames = 6;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _frameAnimation = IntTween(begin: 0, end: totalFrames - 1).animate(_controller);
    _loadImage();
  }

  // Pre-load the image into memory for smooth painting
  Future<void> _loadImage() async {
    final data = await rootBundle.load(widget.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _image = frame.image;
      });
    }
  }

  @override
  void didUpdateWidget(SpriteChest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _controller.forward();
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: _image == null
          ? const SizedBox(width: 120, height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : AnimatedBuilder(
        animation: _frameAnimation,
        builder: (context, child) {
          return Center( // Add Center to prevent stretching
            child: SizedBox(
              width: 150, // Increase this to make the chest bigger
              height: 150,
              child: ClipRect(
                child: CustomPaint(
                  size: const Size(150, 150),
                  painter: SpritePainter(
                    image: _image!,
                    frameIndex: _frameAnimation.value,
                    totalFrames: totalFrames,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SpritePainter extends CustomPainter {
  final ui.Image image;
  final int frameIndex;
  final int totalFrames;

  SpritePainter({
    required this.image,
    required this.frameIndex,
    required this.totalFrames,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..filterQuality = FilterQuality.high;

    // 1. Calculate the dimensions of ONE frame in the PNG
    double frameWidth = image.width / totalFrames;
    double frameHeight = image.height.toDouble();

    // 2. Determine the X-offset for the current frame
    double startX = frameIndex * frameWidth;

    // 3. The Source: This "crops" the black strip away and picks one chest
    Rect src = Rect.fromLTWH(startX, 0, frameWidth, frameHeight);

    // 4. The Destination: This scales the chest to fill your widget size
    // We add the offsets you requested here
    double dx = 0;
    double dy = 0;

    if (frameIndex == 0) {
      dx = 3; dy = -10;
    } else if (frameIndex == 4) {
      dx = 4; dy = 5;
    }

    Rect dst = Rect.fromLTWH(dx, dy, size.width, size.height);

    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(SpritePainter oldDelegate) =>
      oldDelegate.frameIndex != frameIndex;
}