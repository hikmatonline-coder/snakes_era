import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../model/user_model.dart';
import '../../provider/user_provider.dart'; // Keep your existing user model import

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Calculates the current ISO week number to query matching entries
  int _getIsoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateTime(date.year, date.month, date.day)
        .difference(DateTime(date.year, 1, 1))
        .inDays
        .toString());
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

    final userProv = Provider.of<UserProvider>(context, listen: false);
    final currentWeek = userProv.getIsoWeekNumber(now);

    // 1. Live stream targeting the current week's chronological scores
    final weeklyStream = FirebaseFirestore.instance
        .collection('scores')
        .where('year', isEqualTo: now.year)
        .where('weekOfYear', isEqualTo: currentWeek)
        .orderBy('score', descending: true)
        .limit(20)
        .snapshots();

    // 2. Live stream targeting the current month's chronological scores
    final monthlyStream = FirebaseFirestore.instance
        .collection('scores')
        .where('year', isEqualTo: now.year)
        .where('month', isEqualTo: now.month)
        .orderBy('score', descending: true)
        .limit(20)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Top Score Ranks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
          tabs: const [
            Tab(text: 'Weekly Prizes'),
            Tab(text: 'Monthly Grand Prize'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardContent(weeklyStream, colorScheme),
          _buildLeaderboardContent(monthlyStream, colorScheme),
        ],
      ),
    );
  }

  Widget _buildLeaderboardContent(
      Stream<QuerySnapshot> scoreStream,
      ColorScheme colorScheme,
      ) {
    return StreamBuilder<QuerySnapshot>(
      stream: scoreStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          debugPrint("Total docs found: ${snapshot.data!.docs.length}");
          if (snapshot.data!.docs.isNotEmpty) {
            debugPrint("First doc data: ${snapshot.data!.docs.first.data()}");
          }
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // Print the error code to the log. If an index is missing, click the link here!
          debugPrint('Firestore Error: ${snapshot.error}');
          return const Center(child: Text('Failed to load leaderboard'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No scores recorded yet!\nBe the first to secure Rank #1!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          );
        }

        // Map the flat structural entries inside 'scores' to temporary UserModels for your UI
        final users = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return UserModel.fromMap({
            'id': data['userId'] ?? d.id,
            'highScore': data['score'] ?? 0,
            'displayName': data['username'] ?? 'Guest',
            'photoUrl': data['photoUrl'] ?? '',
          });
        }).toList();

        // Slice out your dynamic layouts
        final top3 = users.length >= 3 ? users.sublist(0, 3) : users;
        final others = users.length > 3 ? users.sublist(3) : <UserModel>[];

        return Column(
          children: [
            const SizedBox(height: 16),
            _TopThreeCircles(users: top3),
            const SizedBox(height: 16),
            Divider(color: colorScheme.onSurface.withOpacity(0.1), thickness: 1),
            Expanded(
              child: ListView.builder(
                itemCount: others.length,
                itemExtent: 72,
                itemBuilder: (context, index) {
                  final player = others[index];
                  final rank = index + 4;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.secondary.withOpacity(0.2),
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      player.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    trailing: Text(
                      NumberFormat('#,###').format(player.highScore),
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopThreeCircles extends StatelessWidget {
  final List<UserModel> users;

  const _TopThreeCircles({required this.users});

  @override
  Widget build(BuildContext context) {
    final padded = List<UserModel?>.generate(3, (i) => i < users.length ? users[i] : null);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _TopUserCircle(
          rank: 2,
          user: padded[1],
          trophyColor: Colors.grey.shade400,
        ),
        _TopUserCircle(
          rank: 1,
          user: padded[0],
          trophyColor: Colors.amber,
          isHighlight: true,
        ),
        _TopUserCircle(
          rank: 3,
          user: padded[2],
          trophyColor: Colors.brown.shade400,
        ),
      ],
    );
  }
}

class _TopUserCircle extends StatelessWidget {
  final int rank;
  final UserModel? user;
  final Color trophyColor;
  final bool isHighlight;

  const _TopUserCircle({
    required this.rank,
    required this.user,
    required this.trophyColor,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final image = user?.photoUrl;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: isHighlight ? 38 : 32,
                backgroundColor: trophyColor.withOpacity(0.2),
                backgroundImage: (image != null && image.isNotEmpty)
                    ? NetworkImage(image)
                    : null,
                child: (image == null || image.isEmpty)
                    ? Text(
                  (user != null && user!.displayName.isNotEmpty)
                      ? user!.displayName.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontSize: 24,
                      color: trophyColor,
                      fontWeight: FontWeight.bold),
                )
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.surface,
                  child: Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: trophyColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            user?.displayName ?? '---',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isHighlight ? 16 : 13,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user != null ? NumberFormat('#,###').format(user!.highScore) : '-',
            style: TextStyle(
              fontSize: isHighlight ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '#$rank',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}