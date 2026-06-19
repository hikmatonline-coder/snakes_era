import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/user_model.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _timeLeftStr = "00:00:00";
  Timer? _countdownTimer;

  // 🌟 STREAMS KO CLASS LEVEL PAR LE AAYEIN TAAKE YEH PHIR SE INITIALIZE NA HON
  late final Stream<QuerySnapshot> _dailyStream;
  late final Stream<QuerySnapshot> _weeklyStream;
  late final Stream<QuerySnapshot> _monthlyStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // 1. Streams ko sirf AIK BAAR initialize karein
    _initLeaderboardStreams();

    // 2. Timer start karein (Ab yeh streams ko disturb nahi karega)
    _startResetCountdown();
  }

  // 1. Timer Engine ko 12:00 PM se 00:00 AM (Midnight UTC = 5:00 AM PKT) par set karein
  void _startResetCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      DateTime nowUtc = DateTime.now().toUtc();
      DateTime targetTodayUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, 0, 0, 0);

      DateTime nextReset = nowUtc.isBefore(targetTodayUtc)
          ? targetTodayUtc
          : targetTodayUtc.add(const Duration(days: 1));

      Duration diff = nextReset.difference(nowUtc);

      setState(() {
        _timeLeftStr = "${diff.inHours.toString().padLeft(2, '0')}:"
            "${(diff.inMinutes % 60).toString().padLeft(2, '0')}:"
            "${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
      });
    });
  }

  void _initLeaderboardStreams() {
    final now = DateTime.now().toUtc();

    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final currentWeek = ((dayOfYear - now.weekday + 10) / 7).floor();

    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final weekStr = "${now.year}-W${currentWeek.toString().padLeft(2, '0')}";
    final monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    _dailyStream = FirebaseFirestore.instance
        .collection('users')
        .where('dailyHighScoreDate', isEqualTo: todayStr)
        .orderBy('dailyHighScore', descending: true)
        .limit(20)
        .snapshots();

    _weeklyStream = FirebaseFirestore.instance
        .collection('users')
        .where('weeklyHighScoreWeek', isEqualTo: weekStr)
        .orderBy('weeklyHighScore', descending: true)
        .limit(20)
        .snapshots();

    _monthlyStream = FirebaseFirestore.instance
        .collection('users')
        .where('monthlyHighScoreMonth', isEqualTo: monthStr)
        .orderBy('monthlyHighScore', descending: true)
        .limit(20)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // 💰 LIVE REWARD MULTIPLIER MATH
  Map<String, int> _calculateRankRewards(int rank, String period) {
    int multiplier = 1;
    if (period == 'weekly') multiplier = 3;
    if (period == 'monthly') multiplier = 10;

    if (rank == 1) return {'coins': 120 * multiplier, 'pUp': 12 * multiplier, 'tkt': 120 * multiplier};
    if (rank == 2) return {'coins': 80 * multiplier, 'pUp': 8 * multiplier, 'tkt': 80 * multiplier};
    if (rank == 3) return {'coins': 50 * multiplier, 'pUp': 5 * multiplier, 'tkt': 50 * multiplier};
    if (rank >= 4 && rank <= 10) return {'coins': 30 * multiplier, 'pUp': 3 * multiplier, 'tkt': 30 * multiplier};

    return {'coins': 0, 'pUp': 0, 'tkt': 0};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Top Score Ranks',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
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
              Tab(text: 'Daily'),
              Tab(text: 'Weekly (3x)'),
              Tab(text: 'Monthly (10x)'),
            ],
          ),
        ),
        body: Column(
          children: [
            // ⏰ LIVE SERVER COUNTDOWN TIMER TOP BAR
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.amber, size: 20),
                      SizedBox(width: 6),
                      Text("Server Reset Countdown:", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Text(
                    _timeLeftStr,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Courier'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLeaderboardContent(_dailyStream, colorScheme, 'daily'),
                  _buildLeaderboardContent(_weeklyStream, colorScheme, 'weekly'),
                  _buildLeaderboardContent(_monthlyStream, colorScheme, 'monthly'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardContent(Stream<QuerySnapshot> scoreStream, ColorScheme colorScheme, String period) {
    return StreamBuilder<QuerySnapshot>(
      stream: scoreStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load leaderboard\n(Check if Indexing is complete)'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No scores recorded yet!\nBe the first to secure Rank #1!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        final users = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;

          int displayScore = 0;
          if (period == 'daily') displayScore = data['dailyHighScore'] ?? 0;
          if (period == 'weekly') displayScore = data['weeklyHighScore'] ?? 0;
          if (period == 'monthly') displayScore = data['monthlyHighScore'] ?? 0;

          return UserModel.fromMap({
            'id': d.id,
            'highScore': displayScore,
            'displayName': data['displayName'] ?? 'Guest',
            'photoUrl': data['photoUrl'] ?? data['photoURL'] ?? '',
          });
        }).toList();

        final top3 = users.length >= 3 ? users.sublist(0, 3) : users;
        final others = users.length > 3 ? users.sublist(3) : <UserModel>[];

        return Column(
          children: [
            const SizedBox(height: 10),
            _TopThreeCircles(users: top3, period: period, rewardCalc: _calculateRankRewards),
            const SizedBox(height: 10),
            Divider(color: colorScheme.onSurface.withOpacity(0.1), thickness: 1),
            Expanded(
              child: ListView.builder(
                itemCount: others.length,
                itemExtent: 76,
                itemBuilder: (context, index) {
                  final player = others[index];
                  final rank = index + 4;
                  final rewards = _calculateRankRewards(rank, period);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.secondary.withOpacity(0.15),
                      child: Text('$rank', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(
                      player.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                    subtitle: (rank <= 10)
                        ? Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 13),
                        Text(" ${rewards['coins']}  ", style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        const Icon(Icons.offline_bolt, color: Colors.cyanAccent, size: 13),
                        Text(" ${rewards['pUp']}  ", style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        const Icon(Icons.confirmation_number, color: Colors.purpleAccent, size: 13),
                        Text(" ${rewards['tkt']}", style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    )
                        : const Text("Keep grinding!", style: TextStyle(fontSize: 11, color: Colors.white30)),
                    trailing: Text(
                      NumberFormat('#,###').format(player.highScore),
                      style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold),
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
  final String period;
  final Map<String, int> Function(int rank, String period) rewardCalc;

  const _TopThreeCircles({required this.users, required this.period, required this.rewardCalc});

  @override
  Widget build(BuildContext context) {
    final padded = List<UserModel?>.generate(3, (i) => i < users.length ? users[i] : null);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _TopUserCircle(rank: 2, user: padded[1], trophyColor: Colors.grey.shade400, period: period, rewards: rewardCalc(2, period)),
        _TopUserCircle(rank: 1, user: padded[0], trophyColor: Colors.amber, isHighlight: true, period: period, rewards: rewardCalc(1, period)),
        _TopUserCircle(rank: 3, user: padded[2], trophyColor: Colors.brown.shade400, period: period, rewards: rewardCalc(3, period)),
      ],
    );
  }
}

class _TopUserCircle extends StatelessWidget {
  final int rank;
  final UserModel? user;
  final Color trophyColor;
  final bool isHighlight;
  final String period;
  final Map<String, int> rewards;

  const _TopUserCircle({
    required this.rank,
    required this.user,
    required this.trophyColor,
    this.isHighlight = false,
    required this.period,
    required this.rewards,
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
                radius: isHighlight ? 40 : 32,
                backgroundColor: trophyColor.withOpacity(0.2),
                backgroundImage: (image != null && image.isNotEmpty) ? NetworkImage(image) : null,
                child: (image == null || image.isEmpty)
                    ? Text(
                  (user != null && user!.displayName.isNotEmpty) ? user!.displayName.substring(0, 1).toUpperCase() : '?',
                  style: TextStyle(fontSize: 24, color: trophyColor, fontWeight: FontWeight.bold),
                )
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: colorScheme.surface,
                  child: Icon(Icons.emoji_events, size: 15, color: trophyColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            user?.displayName ?? '---',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: isHighlight ? 15 : 12, color: colorScheme.onSurface),
          ),
          Text(
            user != null ? NumberFormat('#,###').format(user!.highScore) : '-',
            style: TextStyle(fontSize: isHighlight ? 14 : 12, fontWeight: FontWeight.bold, color: isHighlight ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.8)),
          ),

          const SizedBox(height: 6),
          // 🎁 MINI VISUAL REWARD BADGE FOR TOP 3 PODIUM
          if (user != null)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monetization_on, color: Colors.amber, size: 11),
                      Text(" ${rewards['coins']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.offline_bolt, color: Colors.cyanAccent, size: 11),
                      Text(" ${rewards['pUp']} ", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      Icon(Icons.confirmation_number, color: Colors.purpleAccent, size: 11),
                      Text("${rewards['tkt']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}