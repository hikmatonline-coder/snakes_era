// import 'dart:io';
// import 'package:flutter/foundation.dart';
//
// class AdHelper {
//   // --- REAL IDS (Replace these with IDs from AdMob Console) ---
//   static const String _androidRealRewardedID = "ca-app-pub-7462766040867655/1727431741";
//   static const String _androidRealInterstitialID = "ca-app-pub-7462766040867655/6049820138";
//
//   // --- TEST IDS (Google's Official IDs) ---
//   static const String _androidTestRewardedID = "ca-app-pub-3940256099942544/5224354917";
//   static const String _androidTestInterstitialID = "ca-app-pub-3940256099942544/1033173712";
//
//   // REWARDED LOGIC
//   static String get rewardedAdUnitId {
//     if (kReleaseMode) {
//       return _androidRealRewardedID;
//     } else {
//       return _androidTestRewardedID;
//     }
//   }
//
//   // INTERSTITIAL LOGIC
//   static String get interstitialAdUnitId {
//     if (kReleaseMode) {
//       return _androidRealInterstitialID;
//     } else {
//       return _androidTestInterstitialID;
//     }
//   }
// }