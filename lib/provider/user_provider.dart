import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snakes_era/core/constants.dart';

class UserProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  int _coins = AppConstants.coins;
  int _powerUps = AppConstants.powerUps;

  int get coins => _coins;
  int get powerUps => _powerUps;

  int _totalSecondsPlayed = 0;
  Set<String> _claimedRewards = {};

  int get totalSecondsPlayed => _totalSecondsPlayed;

  // Variables to hold user data
  String _userName = "Player";
  int _highScore = 0;
  String? _uid;

  // Getters
  String get userName => _userName;
  int get highScore => _highScore;
  String? get uid => _uid;

  // --- NEW SKIN VARIABLES ---
  String _currentSkinId = "s1"; // Default classic skin
  Set<String> _ownedSkinIds = {"s1"}; // Default unlocked

  String get currentSkinId => _currentSkinId;
  Set<String> get ownedSkinIds => _ownedSkinIds;

  UserProvider() {
    _loadBalances();
    _loadSkins();
    _startGlobalTimer();
    _init();
  }

  Future<void> _init() async {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];

    // 1. Load Last Reset Date
    String? lastResetDate = await _storage.read(key: 'last_mission_reset_date');

    // 2. Load Total Seconds
    String? savedSeconds = await _storage.read(key: 'seconds_played');
    _totalSecondsPlayed = int.parse(savedSeconds ?? '0');

    // 3. Check for Daily Reset
    if (lastResetDate != today) {
      // NEW DAY: Reset missions and playtime
      _totalSecondsPlayed = 0;
      _claimedRewards = {};
      await _storage.write(key: 'last_mission_reset_date', value: today);
      await _storage.write(key: 'seconds_played', value: '0');
      await _storage.write(key: 'claimed_tasks', value: '');
    } else {
      // SAME DAY: Load claimed rewards
      String? claimed = await _storage.read(key: 'claimed_tasks');
      if (claimed != null && claimed.isNotEmpty) {
        _claimedRewards = claimed.split(',').toSet();
      }
    }

    notifyListeners();
  }

  void _startGlobalTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _totalSecondsPlayed++;
      notifyListeners();

      // Auto-save every 30 seconds
      if (_totalSecondsPlayed % 30 == 0) {
        _storage.write(key: 'seconds_played', value: _totalSecondsPlayed.toString());
      }
    });
  }

  Future<void> _loadBalances() async {
    String? c = await _storage.read(key: 'coins');
    String? p = await _storage.read(key: 'powers');

    // Set starting balances only if it's the first time
    if (c == null) {
      await _save(100, 10);
      _coins = 100;
      _powerUps = 10;
    } else {
      _coins = int.parse(c);
      _powerUps = int.parse(p ?? '10');
    }
    notifyListeners();
  }

  // --- Exchange Logic ---
  bool buyPower() {
    if (_coins >= 25) {
      _coins -= 25;
      _powerUps += 1;
      _save(_coins, _powerUps);
      return true;
    }
    return false;
  }

  bool sellPower() {
    if (_powerUps >= 1) {
      _powerUps -= 1;
      _coins += 18;
      _save(_coins, _powerUps);
      return true;
    }
    return false;
  }

  // Used by LifeProvider/Shop to trade 1 Powerup for 1 Life
  bool tradePowerForLife() {
    if (_powerUps >= 1) {
      _powerUps -= 1;
      _save(_coins, _powerUps);
      return true;
    }
    return false;
  }

  void startSessionTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _totalSecondsPlayed++;
      notifyListeners();
    });
  }

  bool isRewardClaimed(String id) => _claimedRewards.contains(id);

  void claimTimeReward(String id, int coins) async {
    if (!_claimedRewards.contains(id)) {
      final today = DateTime.now().toIso8601String().split('T')[0];

      _claimedRewards.add(id);
      addPurchasedItems(coins, 0);

      // Save status and ensure the date is current
      await _storage.write(key: 'claimed_tasks', value: _claimedRewards.join(','));
      await _storage.write(key: 'last_mission_reset_date', value: today);

      notifyListeners();
    }
  }

  /// Load skins from storage
  Future<void> _loadSkins() async {
    String? current = await _storage.read(key: 'current_skin_id');
    String? owned = await _storage.read(key: 'owned_skin_ids');

    if (current != null) _currentSkinId = current;
    if (owned != null && owned.isNotEmpty) {
      _ownedSkinIds = owned.split(',').toSet();
    }
    notifyListeners();
  }

  /// Check if a specific skin is owned
  bool isSkinOwned(String id) => _ownedSkinIds.contains(id);

  /// Handle skin purchase
  bool buySkin(String id, int price) {
    if (_coins >= price && !_ownedSkinIds.contains(id)) {
      _coins -= price;
      _ownedSkinIds.add(id);
      _currentSkinId = id; // Auto-equip on buy
      _syncSkins(); // Save to storage
      _sync();      // Save coins
      return true;
    }
    return false;
  }

  /// Change equipped skin
  void setSkin(String id) async {
    if (_ownedSkinIds.contains(id)) {
      _currentSkinId = id;
      await _storage.write(key: 'current_skin_id', value: id);
      notifyListeners();
    }
  }

  /// Helper to save owned skins list
  Future<void> _syncSkins() async {
    await _storage.write(key: 'owned_skin_ids', value: _ownedSkinIds.join(','));
    await _storage.write(key: 'current_skin_id', value: _currentSkinId);
    notifyListeners();
  }

  /// Deducts coins if available. Returns true if successful.
  bool spendCoins(int amount) {
    if (_coins >= amount) {
      _coins -= amount;
      _sync(); // This calls your _save and notifyListeners logic
      return true;
    }
    return false;
  }

  /// Unified method to add resources from Chests, Spin Wheels, or IAP
  void addPurchasedItems(int coinAmount, int powerAmount) {
    _coins += coinAmount;
    _powerUps += powerAmount;
    _sync();
  }

  void addCoins(int amount) {
    _coins += amount;
    // Save to SharedPreferences or Database here
    notifyListeners();
  }

  void addPowerUps(int amount) {
    _powerUps += amount;
    notifyListeners();
  }

  /// Update high Score to firebase...
  // 1. Call this when the user logs in or when the app starts
  void initializeUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      _userName = user.displayName ?? "SnakeMaster";
      // You could also fetch the high score from Firestore here
      _loadRemoteHighScore();
    }
  }

  // 2. Logic to update High Score in Firebase
  Future<void> updateHighScore(int newScore) async {
    final user = FirebaseAuth.instance.currentUser; // Get fresh ID
    if (user == null) {
      debugPrint("DEBUG: No User Logged In!");
      return;
    }

    if (newScore > _highScore) {
      _highScore = newScore;
      notifyListeners();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'highScore': _highScore,
        'displayName': user.displayName ?? "Snake Player",
        'email': user.email,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint("DEBUG: Firestore Updated Successfully!");
    }
  }

  // Helper to pull the score from Firebase when app opens
  Future<void> _loadRemoteHighScore() async {
    if (_uid == null) return;
    var doc = await FirebaseFirestore.instance.collection('leaderboard').doc(_uid).get();
    if (doc.exists) {
      _highScore = doc.data()?['score'] ?? 0;
      notifyListeners();
    }
  }

  /// Helper to handle both saving to Secure Storage and UI refreshing
  Future<void> _sync() async {
    await _storage.write(key: 'coins', value: _coins.toString());
    await _storage.write(key: 'powers', value: _powerUps.toString());
    notifyListeners();
  }

  Future<void> _save(int c, int p) async {
    await _storage.write(key: 'coins', value: c.toString());
    await _storage.write(key: 'powers', value: p.toString());
    notifyListeners();
  }
}