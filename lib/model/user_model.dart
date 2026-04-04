class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final int highScore;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    this.highScore = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'highScore': highScore,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? 'Guest',
      photoUrl: map['photoUrl'] ?? 'https://picsum.photos/200',
      highScore: map['highScore'] ?? 0,
    );
  }
}
