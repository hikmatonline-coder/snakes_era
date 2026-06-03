import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SocialProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void shareReferralCode(String myId) {
    Share.share("Join Snakes Era with my code: $myId! Let's win together!");
  }

  Future<void> applyReferral(String myUid, String referralCode) async {
    // 1. Khud ka code check
    if (myUid == referralCode) {
      throw Exception("You can't use your own code");
    }

    DocumentReference myRef = _db.collection('users').doc(myUid);
    DocumentReference referrerRef = _db.collection('users').doc(referralCode);

    // 2. Check: Kya user pehle hi kisi ka code use kar chuka hai?
    DocumentSnapshot myDoc = await myRef.get();
    if (myDoc.exists && myDoc.data() != null) {
      Map<String, dynamic> userData = myDoc.data() as Map<String, dynamic>;
      if (userData.containsKey('referredBy') && userData['referredBy'] != null) {
        throw Exception("Already used your code!");
      }
    }

    // 3. Referrer ka existence check
    DocumentSnapshot referrerDoc = await referrerRef.get();
    if (!referrerDoc.exists) {
      throw Exception("Invalid Referral Code!");
    }

    // 4. Batch Write: Rewards (Coins + PowerUps)
    WriteBatch batch = _db.batch();

    // Inviter (Referrer) ko rewards: 50 coins + 5 powerups
    batch.update(referrerRef, {
      'coins': FieldValue.increment(50),
      'powerUps': FieldValue.increment(5),
    });

    // New User (Referred) ko rewards: 30 coins + 3 powerups
    batch.update(myRef, {
      'coins': FieldValue.increment(30),
      'powerUps': FieldValue.increment(3),
      'referredBy': referralCode,
    });

    await batch.commit();
    notifyListeners();
  }

  Future<void> joinTeam(String myUid, String teamId) async {
    DocumentReference teamRef = _db.collection('teams').doc(teamId);
    DocumentSnapshot teamDoc = await teamRef.get();

    if (!teamDoc.exists) {
      throw Exception("Team not found!");
    }

    WriteBatch batch = _db.batch();
    batch.update(_db.collection('users').doc(myUid), {'teamId': teamId});
    batch.update(teamRef, {'memberUids': FieldValue.arrayUnion([myUid])});

    await batch.commit();
    notifyListeners();
  }

  Future<bool> shouldShowReferralPopup(String? referredBy) async {
    // 1. Agar user ne pehle hi refer kiya hai, to popup ki zaroorat nahi
    if (referredBy != null && referredBy.isNotEmpty) {
      return false;
    }

    // 2. Open count check karein
    final prefs = await SharedPreferences.getInstance();
    int openCount = prefs.getInt('app_open_count') ?? 0;
    openCount++;

    if (openCount >= 5) {
      await prefs.setInt('app_open_count', 0); // Count reset
      return true; // Popup show karo
    } else {
      await prefs.setInt('app_open_count', openCount);
      return false; // Popup mat show karo
    }
  }
}