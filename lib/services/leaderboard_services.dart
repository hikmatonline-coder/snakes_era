import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Retrieves the top 10 players for the CURRENT calendar week
  Stream<QuerySnapshot<Map<String, dynamic>>> getWeeklyLeaderboard() {
    final now = DateTime.now();
    final currentWeek = _getIsoWeekNumber(now);

    return _db.collection('scores')
        .where('year', isEqualTo: now.year)
        .where('weekOfYear', isEqualTo: currentWeek)
        .orderBy('score', descending: true)
        .limit(10)
        .snapshots();
  }

  /// Retrieves the top 10 players for the CURRENT calendar month
  Stream<QuerySnapshot<Map<String, dynamic>>> getMonthlyLeaderboard() {
    final now = DateTime.now();

    return _db.collection('scores')
        .where('year', isEqualTo: now.year)
        .where('month', isEqualTo: now.month)
        .orderBy('score', descending: true)
        .limit(10)
        .snapshots();
  }

  /// Helper to match the exact ISO week logic used in UserProvider
  int _getIsoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateTime(date.year, date.month, date.day)
        .difference(DateTime(date.year, 1, 1))
        .inDays
        .toString());
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}