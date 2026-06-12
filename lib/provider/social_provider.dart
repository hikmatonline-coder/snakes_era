import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snakes_era/provider/user_provider.dart';

class SocialProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Referral Popup Fix ---
  Future<bool> shouldShowReferralPopup(String? referredBy) async {
    // Agar pehle se referred hai, to show na ho
    if (referredBy != null && referredBy.isNotEmpty) return false;

    final prefs = await SharedPreferences.getInstance();

    // Check if we already showed it today or if it's already dismissed
    bool isDismissed = prefs.getBool('referral_dismissed') ?? false;
    if (isDismissed) return false;

    int openCount = prefs.getInt('app_referral_popup_count') ?? 0;
    openCount++;

    if (openCount >= 4) {
      await prefs.setInt('app_referral_popup_count', 0); // Reset after showing
      return true;
    } else {
      await prefs.setInt('app_referral_popup_count', openCount);
      return false;
    }
  }

  // --- Apply Referral Fix ---
// SocialProvider.dart ka method ensure karein aesa ho:
  Future<void> applyReferral(BuildContext context, String myUid, String myName, String myEmail, String referralCode) async {
    String cleanCode = referralCode.trim().toUpperCase();

    await _db.runTransaction((transaction) async {
      QuerySnapshot query = await _db.collection('users').where('referralCode', isEqualTo: cleanCode).get();
      if (query.docs.isEmpty) throw Exception("Invalid Code!");

      DocumentSnapshot referrerDoc = query.docs.first;

      // Referrer ke account mein naye bande ka data daal do
      transaction.update(referrerDoc.reference, {
        'referrals': FieldValue.arrayUnion([{
          'name': myName,
          'email': myEmail,
          'joinedAt': DateTime.now().toIso8601String() // Time check ke liye
        }]),
        'coins': FieldValue.increment(100),
        'powerUps': FieldValue.increment(10),
      });

      // Apne account mein reward lo
      transaction.update(_db.collection('users').doc(myUid), {
        'referredBy': cleanCode,
        'coins': FieldValue.increment(100),
        'powerUps': FieldValue.increment(10),
      });
    });

    // UI Refresh (Is liye BuildContext pass kiya tha)
    context.read<UserProvider>().loadRemoteUserData();
  }
  void shareReferralCode(String? code) {
    if (code == null || code.isEmpty) return;

    String message = "Join me on Snakes Era! Use my code: $code to get 30 Coins & 3 PowerUps instantly! Download now.";

    Share.share(message);
  }

  Future<void> joinTeam(BuildContext context, String myUid, String teamId) async {
    await _db.runTransaction((transaction) async {
      DocumentReference teamRef = _db.collection('teams').doc(teamId);
      DocumentReference userRef = _db.collection('users').doc(myUid);

      transaction.update(teamRef, {
        'memberUids': FieldValue.arrayUnion([myUid])
      });

      transaction.update(userRef, {
        'teamId': teamId,
      });
    });

    context.read<UserProvider>().loadRemoteUserData();
  }
}