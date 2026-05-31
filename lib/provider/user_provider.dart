import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snakes_era/core/constants.dart';

class UserProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _coins = AppConstants.coins;
  int _powerUps = AppConstants.powerUps;

  int get coins => _coins;
  int get powerUps => _powerUps;

  int _totalSecondsPlayed = 0;
  Set<String> _claimedRewards = {};

  int get totalSecondsPlayed => _totalSecondsPlayed;

  String _userName = "Player";
  int _highScore = 0;
  String? _uid;
  bool _remoteLoaded = false;

  String get userName => _userName;
  int get highScore => _highScore;
  String? get uid => _uid;
  bool get remoteLoaded => _remoteLoaded;

  String _currentSkinId = "c1";
  Set<String> _ownedSkinIds = {"c1"};

  String get currentSkinId => _currentSkinId;
  Set<String> get ownedSkinIds => _ownedSkinIds;

  UserProvider() {
    _loadSkins();
    _startGlobalTimer();
    _init();
  }

  String? get _firebaseUid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _firebaseUid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  Future<void> _init() async {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];

    String? lastResetDate = await _storage.read(key: 'last_mission_reset_date');
    String? savedSeconds = await _storage.read(key: 'seconds_played');
    _totalSecondsPlayed = int.parse(savedSeconds ?? '0');

    if (lastResetDate != today) {
      _totalSecondsPlayed = 0;
      _claimedRewards = {};
      await _storage.write(key: 'last_mission_reset_date', value: today);
      await _storage.write(key: 'seconds_played', value: '0');
      await _storage.write(key: 'claimed_tasks', value: '');
    } else {
      String? claimed = await _storage.read(key: 'claimed_tasks');
      if (claimed != null && claimed.isNotEmpty) {
        _claimedRewards = claimed.split(',').toSet();
      }
    }

    notifyListeners();
  }

  /// Loads coins, powerUps, and highScore from Firestore. Call after login.
  Future<void> loadRemoteUserData() async {
    final docRef = _userDoc;
    if (docRef == null) return;

    try {
      final snapshot = await docRef.get();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        _uid = user.uid;
        _userName = user.displayName ?? "SnakeMaster";
      }

      if (snapshot.exists) {
        final data = snapshot.data()!;
        await _applyRemoteData(data);
      } else {
        await _createDefaultFirestoreProfile();
      }

      _remoteLoaded = true;
    } catch (e) {
      debugPrint('Failed to load user data from Firestore: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _applyRemoteData(Map<String, dynamic> data) async {
    _coins = (data['coins'] as num?)?.toInt() ?? AppConstants.coins;
    _powerUps = (data['powerUps'] as num?)?.toInt() ?? AppConstants.powerUps;
    _highScore = (data['highScore'] as num?)?.toInt() ?? 0;

    final remoteSkins = data['ownedSkinIds'];
    if (remoteSkins is List) {
      _ownedSkinIds = remoteSkins.map((e) => e.toString()).toSet();
      if (_ownedSkinIds.isEmpty) _ownedSkinIds = {"c1"};
    }
    _currentSkinId = data['currentSkinId'] as String? ?? _currentSkinId;

    // One-time migration from local secure storage
    final localCoins = await _storage.read(key: 'coins');
    final localPowers = await _storage.read(key: 'powers');
    if (data['coins'] == null && localCoins != null) {
      _coins = int.tryParse(localCoins) ?? _coins;
    }
    if (data['powerUps'] == null && localPowers != null) {
      _powerUps = int.tryParse(localPowers) ?? _powerUps;
    }

    await _syncBalancesToFirestore();
    await _syncSkins();
    await _clearLocalBalances();
  }

  Future<void> _createDefaultFirestoreProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _coins = AppConstants.coins;
    _powerUps = AppConstants.powerUps;

    await _userDoc!.set({
      'email': user.email,
      'displayName': user.displayName ?? 'Snake Player',
      'photoUrl': user.photoURL,
      'highScore': 0,
      'coins': _coins,
      'powerUps': _powerUps,
      'lives': AppConstants.maxLives,
      'lastRegenMs': null,
      'ownedSkinIds': _ownedSkinIds.toList(),
      'currentSkinId': _currentSkinId,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _clearLocalBalances() async {
    await _storage.delete(key: 'coins');
    await _storage.delete(key: 'powers');
  }

  void _startGlobalTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _totalSecondsPlayed++;
      notifyListeners();

      if (_totalSecondsPlayed % 30 == 0) {
        _storage.write(key: 'seconds_played', value: _totalSecondsPlayed.toString());
      }
    });
  }

  bool buyPower() {
    if (_coins >= 25) {
      _coins -= 25;
      _powerUps += 1;
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  bool sellPower() {
    if (_powerUps >= 1) {
      _powerUps -= 1;
      _coins += 18;
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  bool tradePowerForLife() {
    if (_powerUps >= 1) {
      _powerUps -= 1;
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  bool isRewardClaimed(String id) => _claimedRewards.contains(id);

  void claimTimeReward(String id, int coins) async {
    if (!_claimedRewards.contains(id)) {
      final today = DateTime.now().toIso8601String().split('T')[0];

      _claimedRewards.add(id);
      addPurchasedItems(coins, 0);

      await _storage.write(key: 'claimed_tasks', value: _claimedRewards.join(','));
      await _storage.write(key: 'last_mission_reset_date', value: today);

      notifyListeners();
    }
  }

  Future<void> _loadSkins() async {
    String? current = await _storage.read(key: 'current_skin_id');
    String? owned = await _storage.read(key: 'owned_skin_ids');

    if (current != null) _currentSkinId = current;
    if (owned != null && owned.isNotEmpty) {
      _ownedSkinIds = owned.split(',').toSet();
    }
    notifyListeners();
  }

  bool isSkinOwned(String id) => _ownedSkinIds.contains(id);

  bool buySkin(String id, int price) {
    if (_coins >= price && !_ownedSkinIds.contains(id)) {
      _coins -= price;
      _ownedSkinIds.add(id);
      _currentSkinId = id;
      _syncSkins();
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  void setSkin(String id) async {
    if (_ownedSkinIds.contains(id)) {
      _currentSkinId = id;
      await _storage.write(key: 'current_skin_id', value: id);
      _syncSkins();
      notifyListeners();
    }
  }

  Future<void> _syncSkins() async {
    await _storage.write(key: 'owned_skin_ids', value: _ownedSkinIds.join(','));
    await _storage.write(key: 'current_skin_id', value: _currentSkinId);

    final docRef = _userDoc;
    if (docRef != null) {
      await docRef.set({
        'ownedSkinIds': _ownedSkinIds.toList(),
        'currentSkinId': _currentSkinId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    notifyListeners();
  }

  bool spendCoins(int amount) {
    if (_coins >= amount) {
      _coins -= amount;
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  void addPurchasedItems(int coinAmount, int powerAmount) {
    _coins += coinAmount;
    _powerUps += powerAmount;
    _syncBalancesToFirestore();
  }

  void addCoins(int amount) {
    _coins += amount;
    _syncBalancesToFirestore();
  }

  void addPowerUps(int amount) {
    _powerUps += amount;
    _syncBalancesToFirestore();
  }

  void initializeUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      _userName = user.displayName ?? "SnakeMaster";
      loadRemoteUserData();
    }
  }

  Future<void> updateHighScore(int newScore) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("DEBUG: No User Logged In!");
      return;
    }

    if (newScore > _highScore) {
      _highScore = newScore;
      notifyListeners();

      await _db.collection('users').doc(user.uid).set({
        'highScore': _highScore,
        'displayName': user.displayName ?? "Snake Player",
        'email': user.email,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _syncBalancesToFirestore() async {
    notifyListeners();

    final docRef = _userDoc;
    if (docRef == null) return;

    try {
      await docRef.set({
        'coins': _coins,
        'powerUps': _powerUps,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to sync balances to Firestore: $e');
    }
  }

  /// Resets in-memory state after sign-out.
  void resetLocalState() {
    _uid = null;
    _remoteLoaded = false;
    _coins = AppConstants.coins;
    _powerUps = AppConstants.powerUps;
    _highScore = 0;
    _userName = "Player";
    notifyListeners();
  }
}
