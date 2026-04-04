import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/ads_provider.dart';
import '../../provider/life_provider.dart';
import '../constants.dart';

class NoLivesSheet extends StatefulWidget {
  const NoLivesSheet({super.key});

  @override
  State<NoLivesSheet> createState() => _NoLivesSheetState();
}

class _NoLivesSheetState extends State<NoLivesSheet> {

  @override
  Widget build(BuildContext context) {
    // Accessing providers
    final lifeProv = Provider.of<LifeProvider>(context, listen: false);
    // final adProv = Provider.of<AdProvider>(context);

    String buttonText = "WATCH AD";

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppConstants.backgroundColor.withOpacity(0.8),
            border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, color: AppConstants.primaryColor, size: 64),
              const SizedBox(height: 16),
              const Text(
                AppConstants.noLivesHeader,
                style: TextStyle(
                    color: AppConstants.primaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2),
              ),
              const SizedBox(height: 12),
              const Text(
                AppConstants.noLivesBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 32),

              // Action Button
              // ElevatedButton.icon(
              //   onPressed: adProv.isAdLoading || adProv.secondsRemaining > 0 || adProv.reachedLimit ? null : () async {
              //     bool success = await adProv.showRewarded();
              //     if (success) {
              //       lifeProv.addLives(1);
              //     } else {
              //       ScaffoldMessenger.of(context).showSnackBar(
              //           const SnackBar(content: Text("Ad not ready or limit reached. Try again soon!"))
              //       );
              //     }
              //   },
              //   icon: adProv.isAdLoading
              //       ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              //       : const Icon(Icons.play_circle_fill),
              //   label: Text(buttonText),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: AppConstants.primaryColor,
              //     disabledBackgroundColor: Colors.white10,
              //     minimumSize: const Size(double.infinity, 56),
              //   ),
              // ),

              // // Secondary text to show progress
              // if (!adProv.reachedLimit)
              //   Padding(
              //     padding: const EdgeInsets.only(top: 8.0),
              //     child: Text(
              //       "Daily Ads: ${adProv.dailyAdsWatched}/5",
              //       style: const TextStyle(color: Colors.white38, fontSize: 12),
              //     ),
              //   ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppConstants.waitBtn, style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}