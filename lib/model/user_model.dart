import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final int highScore;
  final int coins;
  final int powerUps;
  final int lives;
  final String? referredBy;
  final String? referralCode;
  final int tickets;
  final double voucherWallet;
  final bool isPremium;
  final DateTime? voucherExpiry;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    this.highScore = 0,
    this.coins = 100,
    this.powerUps = 10,
    this.lives = 5,
    this.referredBy,
    this.referralCode,
    this.tickets = 0,
    this.voucherWallet = 0.0,
    this.isPremium = false,
    this.voucherExpiry,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'highScore': highScore,
      'coins': coins,
      'powerUps': powerUps,
      'lives': lives,
      'referredBy': referredBy,
      'referralCode': referralCode,
      'tickets': tickets,
      'voucherWallet': voucherWallet,
      'isPremium': isPremium,
      'voucherExpiry': voucherExpiry != null ? Timestamp.fromDate(voucherExpiry!) : null,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? 'Guest',
      photoUrl: map['photoUrl'] ?? 'https://picsum.photos/200',
      highScore: (map['highScore'] as num?)?.toInt() ?? 0,
      coins: (map['coins'] as num?)?.toInt() ?? 100,
      powerUps: (map['powerUps'] as num?)?.toInt() ?? 10,
      lives: (map['lives'] as num?)?.toInt() ?? 5,
      referredBy: map['referredBy'],
      referralCode: map['referralCode'],
      tickets: (map['tickets'] as num?)?.toInt() ?? 0,
      voucherWallet: (map['voucherWallet'] as num?)?.toDouble() ?? 0.0,
      isPremium: map['isPremium'] ?? false,
      voucherExpiry: map['voucherExpiry'] != null
          ? (map['voucherExpiry'] as Timestamp).toDate()
          : null,
    );
  }
}