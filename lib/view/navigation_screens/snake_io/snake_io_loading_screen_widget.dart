import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../core/painters/logo_painter.dart';

class GameLoadingScreen extends StatefulWidget {
  final VoidCallback onReady;
  const GameLoadingScreen({super.key, required this.onReady});

  @override
  State<GameLoadingScreen> createState() => _GameLoadingScreenState();
}

class _GameLoadingScreenState extends State<GameLoadingScreen> {
  double progress = 0.0;
  String status = "Checking Server...";

  @override
  void initState() {
    super.initState();
    _prepareGame();
  }

  Future<void> _prepareGame() async {
    try {
      // 1. Check Internet
      final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

      // If no internet, wait 2 seconds then "Proceed anyway" (Offline Mode)
      // Or you can stay stuck if you strictly require ads
      if (connectivityResult.contains(ConnectivityResult.none)) {
        setState(() => status = "Offline Mode - Limited Features");
        await Future.delayed(const Duration(seconds: 2));
      }

      // 2. Simulated Loading (Force it to finish)
      for (int i = 0; i < 100; i++) {
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 20)); // Made it slightly faster
        setState(() {
          progress = i / 100.0;
          if (i == 30) status = "Spawning NPCs...";
          if (i == 70) status = "Preparing Arena...";
        });
      }

      // 3. Trigger the transition
      print("Loading Complete - Calling onReady");
      widget.onReady();

    } catch (e) {
      print("Error during load: $e");
      widget.onReady(); // Fallback: start game anyway
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              painter: AppLogoPainter(),
            ),
            const Text("SNAKE.IO", style: TextStyle(color: Colors.cyanAccent, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(value: progress, color: Colors.cyanAccent, backgroundColor: Colors.white10),
            ),
            const SizedBox(height: 10),
            Text(status, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}