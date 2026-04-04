import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/life_provider.dart';
import '../constants.dart';

class LifeTimerWidget extends StatelessWidget {
  const LifeTimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final lifeProvider = Provider.of<LifeProvider>(context);
    final duration = lifeProvider.timeUntilNextLife;

    String timerText = "";
    if (lifeProvider.lives < AppConstants.maxLives) {
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
      timerText = "$minutes:$seconds";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConstants.primaryColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
          const SizedBox(width: 6),
          Text(
            "${lifeProvider.lives}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (timerText.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              timerText,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ]
        ],
      ),
    );
  }
}
