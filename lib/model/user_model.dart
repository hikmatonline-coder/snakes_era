class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final int highScore;
  final int coins;
  final int powerUps;
  final int lives;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    this.highScore = 0,
    this.coins = 100,
    this.powerUps = 10,
    this.lives = 5,
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
    );
  }
}
