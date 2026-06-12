import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ADDED: Provider import
import '../../../model/snake_skin_model.dart'; // ADDED: Apne skin model ka sahi path dein
import '../../../provider/snake_game_provider.dart'; // ADDED: Game provider path
import '../../../provider/user_provider.dart'; // ADDED: User provider path
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
        ? const SnakeIOGame() // Added const if applicable
        : GameLoadingScreen(
      onReady: () {
        // ============================================================
        // 💥 LIVE TICKET SYSTEM & GAME INITIALIZATION ON READY
        // ============================================================
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final gameProvider = Provider.of<SnakeGameProvider>(context, listen: false);

        // 1. User ki current selected skin fetch karein
        final activeSkin = snakeSkins.firstWhere(
              (s) => s.id == userProvider.currentSkinId,
          orElse: () => snakeSkins.first,
        );

        // 2. Game loop start karein aur live tickets ka callback attach karein
        gameProvider.startGame(
          activeSkin.bodyColors,
          onLiveTicketsRewarded: (ticketsAmount, message) {

            // Step A: Direct wallet mein tickets inject karein
            userProvider.addFreeTickets(ticketsAmount);

            // Step B: In-game floating popup alert show karein
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.confirmation_number, color: Colors.amber),
                    const SizedBox(width: 10),
                    Text(
                      message,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                backgroundColor: Colors.deepPurpleAccent,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );

        // 3. State flip karein taake actual gameplay screen load ho jaye
        setState(() {
          _isReady = true;
        });
      },
    );
  }
}