import 'package:flutter/material.dart';
import 'snake_io_game.dart';
import 'snake_io_loading_screen_widget.dart';

class SnakeGameWrapper extends StatefulWidget {
  const SnakeGameWrapper({super.key});

  @override
  State<SnakeGameWrapper> createState() => _SnakeGameWrapperState();
}

class _SnakeGameWrapperState extends State<SnakeGameWrapper> {
  bool _isReady = false;

  @override
  Widget build(BuildContext context) {
    // If not ready, show loading. When onReady hits, flip to the game!
    return _isReady
        ? SnakeIOGame()
        : GameLoadingScreen(onReady: () {
      setState(() {
        _isReady = true;
      });
    });
  }
}