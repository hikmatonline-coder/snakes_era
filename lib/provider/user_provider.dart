import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:snakes_era/core/constants.dart';
import '../model/user_model.dart';

class UserProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _coins = AppConstants.coins;
  int _powerUps = AppConstants.powerUps;

  // --- NAYI ECONOMIC SYSTEM VARIABLES ---
  int _tickets = 0;
  double _voucherWallet = 0.0;
  bool _isPremium = false;
  DateTime? _voucherExpiryDate;

  // --- NEW: DYNAMIC VOUCHER INVENTORY TRACKER ---
  // Firestore data map key hamesha string hota hy, is liye double keys ko safely track krne k liye map banaya hy
  final Map<double, int> _voucherInventory = {
    1.0: 0,
    2.0: 0,
    3.0: 0,
    5.0: 0,
  };

  int get coins => _coins;
  int get powerUps => _powerUps;
  int get tickets => _tickets;
  double get voucherWallet => _voucherWallet;
  bool get isPremium => _isPremium;
  DateTime? get voucherExpiryDate => _voucherExpiryDate;

  // Method to easily get individual counts for UI Screen
  int getVoucherCount(double value) {
    return _voucherInventory[value] ?? 0;
  }

  int _totalSecondsPlayed = 0;
  Set<String> _claimedRewards = {};
  int get totalSecondsPlayed => _totalSecondsPlayed;

  String _userName = "Player";
  int _highScore = 0;
  String? _uid;
  String? _referralCode;
  bool _remoteLoaded = false;

  // --- Crypto Tournament States ---
  String _cryptoWalletAddress = "";
  String _cryptoNetwork = "Solana";

  String get cryptoWalletAddress => _cryptoWalletAddress;
  String get cryptoNetwork => _cryptoNetwork;
  String get userName => _userName;
  int get highScore => _highScore;
  String? get uid => _uid;
  String? get referralCode => _referralCode;
  bool get remoteLoaded => _remoteLoaded;

  String _currentSkinId = "c1";
  Set<String> _ownedSkinIds = {"c1"};
  String get currentSkinId => _currentSkinId;
  Set<String> get ownedSkinIds => _ownedSkinIds;

  UserProvider() {
    _loadSkins();
    _startGlobalTimer();
    _init();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _uid = user.uid;
        _userName = user.displayName ?? "SnakeMaster";
        loadRemoteUserData();
      } else {
        resetLocalState();
      }
    });
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
    final user = UserModel.fromMap({...data, 'id': _uid});

    _coins = user.coins;
    _powerUps = user.powerUps;
    _highScore = user.highScore;
    _referralCode = user.referralCode;

    // --- VOUCHER & TICKETS INCOME FIELDS WITH EXPIRY CHECK ---
    _tickets = data['tickets'] as int? ?? 0;
    _isPremium = data['isPremium'] as bool? ?? false;

    // Fetch and parse voucher inventory safely from remote data map
    final remoteInventory = data['voucherInventory'] as Map<String, dynamic>?;
    if (remoteInventory != null) {
      remoteInventory.forEach((key, value) {
        final doubleKey = double.tryParse(key);
        if (doubleKey != null) {
          _voucherInventory[doubleKey] = value as int? ?? 0;
        }
      });
    } else {
      // Inventory reset state configuration if empty in remote
      _voucherInventory.updateAll((key, value) => 0);
    }

    if (data['voucherExpiry'] != null) {
      _voucherExpiryDate = (data['voucherExpiry'] as Timestamp).toDate();

      // Inactivity Filter: Agar user expiry date ke BAAD aya hy toh balance clear
      if (DateTime.now().isAfter(_voucherExpiryDate!)) {
        _voucherWallet = 0.0;
        _voucherInventory.updateAll((key, value) => 0); // Inventory clear on expiry
        debugPrint("🎉 Vouchers expired due to inactivity.");
      } else {
        _voucherWallet = (data['voucherWallet'] as num?)?.toDouble() ?? 0.0;
      }
    } else {
      _voucherWallet = (data['voucherWallet'] as num?)?.toDouble() ?? 0.0;
    }

    // User active hua hy toh agle 30 days tak validity barhayein
    _voucherExpiryDate = DateTime.now().add(const Duration(days: 30));

    if (_referralCode == null || _referralCode!.isEmpty) {
      final displayName = user.displayName.replaceAll(' ', '').toUpperCase();
      final prefix = displayName.length >= 3 ? displayName.substring(0, 3) : "SNK";
      _referralCode = "${prefix}${user.id.substring(0, 3)}".toUpperCase();
      _syncBalancesToFirestore();
    }

    _cryptoWalletAddress = data['cryptoWalletAddress'] as String? ?? "";
    _cryptoNetwork = data['cryptoNetwork'] as String? ?? "Solana";

    _currentSkinId = data['currentSkinId'] as String? ?? "c1";
    final remoteSkins = data['ownedSkinIds'];
    if (remoteSkins is List) {
      _ownedSkinIds = remoteSkins.map((e) => e.toString()).toSet();
    }

    await _storage.write(key: 'user_high_score_cache', value: _highScore.toString());

    final localCoins = await _storage.read(key: 'coins');
    final localPowers = await _storage.read(key: 'powers');

    if (data['coins'] == null && localCoins != null) _coins = int.tryParse(localCoins) ?? _coins;
    if (data['powerUps'] == null && localPowers != null) _powerUps = int.tryParse(localPowers) ?? _powerUps;

    await _syncBalancesToFirestore();
    await _syncSkins();
    await _clearLocalBalances();

    notifyListeners();
  }

  Future<void> _createDefaultFirestoreProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _coins = AppConstants.coins;
    _powerUps = AppConstants.powerUps;
    _tickets = 0;
    _voucherWallet = 0.0;
    _isPremium = false;
    _voucherExpiryDate = DateTime.now().add(const Duration(days: 30));
    _voucherInventory.updateAll((key, value) => 0);

    _referralCode = user.displayName?.replaceAll(' ', '').toUpperCase().substring(0, 3) ?? "SNK";
    _referralCode = "$_referralCode${user.uid.substring(0, 3)}".toUpperCase();

    await _userDoc!.set({
      'email': user.email,
      'displayName': user.displayName ?? 'Snake Player',
      'photoUrl': user.photoURL,
      'highScore': 0,
      'coins': _coins,
      'powerUps': _powerUps,
      'tickets': _tickets,
      'voucherWallet': _voucherWallet,
      'voucherInventory': _voucherInventory.map((key, value) => MapEntry(key.toString(), value)),
      'voucherExpiry': _voucherExpiryDate != null ? Timestamp.fromDate(_voucherExpiryDate!) : null,
      'isPremium': _isPremium,
      'cryptoWalletAddress': _cryptoWalletAddress,
      'cryptoNetwork': _cryptoNetwork,
      'lives': AppConstants.maxLives,
      'lastRegenMs': null,
      'ownedSkinIds': _ownedSkinIds.toList(),
      'currentSkinId': _currentSkinId,
      'referralCode': _referralCode,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ========================================================
  //          THE NEW ECONOMIC TRADES & CORE LOOPS
  // ========================================================

  /// Coins se direct tickets buy karna
  bool buyTicketWithCoins(int cost) {
    if (_coins >= cost) {
      _coins -= cost;
      _tickets += 1;
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  void addFreeTickets(int amount) {
    _tickets += amount;
    _syncBalancesToFirestore();
  }

  void addVoucherReward(double amount) {
    _voucherWallet += amount;
    _syncBalancesToFirestore();
  }

  Future<void> activatePremiumWithIAP() async {
    _isPremium = true;
    _syncBalancesToFirestore();
  }

  bool buyPremiumWithVouchers(double premiumCostUSD) {
    if (_voucherWallet >= premiumCostUSD && !_isPremium) {
      _voucherWallet -= premiumCostUSD;
      _isPremium = true;
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  bool useTicketForDraw() {
    if (_tickets >= 1) {
      _tickets -= 1;
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  /// Tickets de kar Coins buy karna
  bool tradeTicketsForCoins(int ticketCost, int coinReward) {
    if (_tickets >= ticketCost) {
      _tickets -= ticketCost;
      _coins += coinReward;
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  /// Tickets de kar PowerUps lena
  bool tradeTicketsForPowerUps(int ticketCost, int powerReward) {
    if (_tickets >= ticketCost) {
      _tickets -= ticketCost;
      _powerUps += powerReward;
      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  /// FIXED RATE CONFIGURATION: Dynamic voucher printing loop (\$1, \$2, \$3, \$5)
  bool buyVoucherWithTickets(int ticketCost, double voucherValue) {
    if (_tickets >= ticketCost) {
      _tickets -= ticketCost;

      // Update inventory map values safely
      _voucherInventory[voucherValue] = (_voucherInventory[voucherValue] ?? 0) + 1;

      // Update overall financial wallet valuation summary
      _voucherWallet += voucherValue;

      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  /// Liquidity Reverse Return Mechanism with structural 20% validation penalty check
  bool sellVoucherForTickets(double voucherValue, int ticketReward) {
    if (getVoucherCount(voucherValue) > 0) {
      // Decrease specific stock inventory count by exactly 1 item unit
      _voucherInventory[voucherValue] = _voucherInventory[voucherValue]! - 1;

      // Deduction from dynamic liquidity summary data
      _voucherWallet -= voucherValue;

      // Refund payload execution
      _tickets += ticketReward;

      _syncBalancesToFirestore();
      return true;
    }
    return false;
  }

  // ========================================================

  Future<void> updateCryptoWallet(String address, String network) async {
    _cryptoWalletAddress = address.trim();
    _cryptoNetwork = network.trim();
    notifyListeners();

    final docRef = _userDoc;
    if (docRef != null) {
      await docRef.set({
        'cryptoWalletAddress': _cryptoWalletAddress,
        'cryptoNetwork': _cryptoNetwork,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
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
    if (user == null) return;

    await _db.collection('scores').doc(user.uid).set({
      'score': newScore,
      'userId': user.uid,
      'username': user.displayName ?? "Player",
      'year': DateTime.now().year,
      'weekOfYear': getIsoWeekNumber(DateTime.now()),
      'month': DateTime.now().month,
      'timestamp': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  int getIsoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateTime(date.year, date.month, date.day)
        .difference(DateTime(date.year, 1, 1))
        .inDays
        .toString());
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  Future<void> _syncBalancesToFirestore() async {
    final docRef = _userDoc;
    if (docRef == null) return;

    final Map<String, dynamic> dataToSync = {
      'coins': _coins,
      'powerUps': _powerUps,
      'highScore': _highScore,
      'referralCode': _referralCode,
      'tickets': _tickets,
      'voucherWallet': _voucherWallet,
      // Map keys converted to string so Firestore can process safely
      'voucherInventory': _voucherInventory.map((key, value) => MapEntry(key.toString(), value)),
      'voucherExpiry': _voucherExpiryDate != null ? Timestamp.fromDate(_voucherExpiryDate!) : null,
      'isPremium': _isPremium,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    try {
      await docRef.set(dataToSync, SetOptions(merge: true));
      notifyListeners();
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  }

  // ========================================================
  //       LIVE SCORE TO TICKETS REWARD SYSTEM
  // ========================================================

  /// 1. Game ke doran live milestone achieve hone par call karein
  void addLiveMilestoneTickets(int amount) {
    _tickets += amount;
    _syncBalancesToFirestore(); // Live database me save karein
    notifyListeners();
  }

  /// 2. Game Over screen pr baki bache hue points ke tickets dene ke liye
  /// [finalScore] = Total Score, [milestonesClaimed] = Game k andar kitni baar 1000 hit hua
  void finalizeGameScoreAndTickets(int finalScore, int milestonesClaimed) {
    // 1000 score = 10 tickets, iska matlab 100 score = 1 ticket
    int totalDeservedTickets = finalScore ~/ 100;
    int alreadyGivenTickets = milestonesClaimed * 10;

    // Jo tickets game k andar live nahi mile, wo ab de dein (e.g. upar wale 500 score k 5 tickets)
    int remainingTickets = totalDeservedTickets - alreadyGivenTickets;

    if (remainingTickets > 0) {
      _tickets += remainingTickets;
    }

    // High score check aur update logic bhi sath hi handle ho jaye
    if (finalScore > _highScore) {
      _highScore = finalScore;
      updateHighScore(finalScore);
    }

    _syncBalancesToFirestore();
  }

  void resetLocalState() async {
    _uid = null;
    _remoteLoaded = false;
    _coins = AppConstants.coins;
    _powerUps = AppConstants.powerUps;
    _highScore = 0;
    _userName = "Player";
    _cryptoWalletAddress = "";
    _cryptoNetwork = "Solana";

    _tickets = 0;
    _voucherWallet = 0.0;
    _isPremium = false;
    _voucherExpiryDate = null;
    _voucherInventory.updateAll((key, value) => 0); // Clear inventory structure safely

    _currentSkinId = "c1";
    _ownedSkinIds = {"c1"};

    await _storage.delete(key: 'current_skin_id');
    await _storage.delete(key: 'owned_skin_ids');

    notifyListeners();
  }
}