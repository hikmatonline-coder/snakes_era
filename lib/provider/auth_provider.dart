import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants.dart';
import '../model/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  UserModel? _user;
  bool _isLoading = false; // used while an explicit action (e.g. login) is running
  bool _initializing = true; // used only for startup auth check

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _initializing;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    _initializing = true;
    notifyListeners();

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _loadUserFromFirestore(currentUser);
      } else {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          // Try to refresh Firebase user from stored token if needed in future.
        }
      }
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserFromFirestore(User firebaseUser) async {
    try {
      final docRef = _db.collection('users').doc(firebaseUser.uid);

      // 1. ADD A TIMEOUT
      // If Firestore doesn't respond in 8 seconds, throw an error so we can stop loading
      final snapshot = await docRef.get().timeout(const Duration(seconds: 8));

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _user = UserModel.fromMap({
          ...data,
          'id': firebaseUser.uid,
        });
      } else {
        // 2. CREATE NEW USER LOGIC
        final newUser = UserModel(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName ?? 'Arcade Player',
          photoUrl: firebaseUser.photoURL ?? 'https://picsum.photos/200',
          highScore: 0,
          coins: AppConstants.coins,
          powerUps: AppConstants.powerUps,
          lives: AppConstants.maxLives,
        );
        await docRef.set({
          ...newUser.toMap(),
          'lastRegenMs': null,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _user = newUser;
      }
    } catch (e) {
      debugPrint("Firestore Load Error: $e");
      // If Firestore fails, we shouldn't let the user stay stuck.
      // We can fallback to a "Guest" user model or show an error.
      _user = null;
      rethrow; // Pass error up to signInWithGoogle to set isLoading = false
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false; // user cancelled
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Persist a token just to remember the session (optional but keeps your previous logic).
      final idToken = await firebaseUser.getIdToken();
      await _storage.write(key: 'auth_token', value: idToken);

      await _loadUserFromFirestore(firebaseUser);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('Google sign-in failed: $e\n$st');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateHighScore(int newScore) async {
    if (_user == null || newScore <= _user!.highScore) return;

    final updated = UserModel(
      id: _user!.id,
      email: _user!.email,
      displayName: _user!.displayName,
      photoUrl: _user!.photoUrl,
      highScore: newScore,
    );
    _user = updated;
    notifyListeners();

    await _db.collection('users').doc(updated.id).update({
      'highScore': newScore,
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    await _storage.deleteAll();
    _user = null;
    notifyListeners();
  }
}
