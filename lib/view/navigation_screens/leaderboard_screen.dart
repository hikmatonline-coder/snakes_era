import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../model/user_model.dart';


class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the current theme colors
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // Background will now automatically use scaffoldBackgroundColor from your AppTheme
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('highScore', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load leaderboard'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No players yet. Play a game!'));
          }

          final users = docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return UserModel.fromMap({
              ...data,
              'id': d.id,
              'highScore': data['highScore'] ?? 0,
              'displayName': data['displayName'] ?? 'Guest',
            });
          }).toList();

          final top3 = users.length >= 3 ? users.sublist(0, 3) : users;
          final others = users.length > 3 ? users.sublist(3) : <UserModel>[];

          return Column(
            children: [
              const SizedBox(height: 16),
              _TopThreeCircles(users: top3),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: others.length,
                  itemExtent: 72,
                  itemBuilder: (context, index) {
                    final player = others[index];
                    final rank = index + 4;
                    return ListTile(
                      leading: CircleAvatar(
                        // Uses secondary color (Cyan) from your theme
                        backgroundColor: colorScheme.secondary.withOpacity(0.2),
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            // Text color adapts to background
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
                          color: colorScheme.primary, // AppConstants.primaryColor
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
      ),
    );
  }
}

class _TopThreeCircles extends StatelessWidget {
  final List<UserModel> users;

  const _TopThreeCircles({required this.users});

  @override
  Widget build(BuildContext context) {
    // Ensure we always show up to 3 slots
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
                  user?.displayName.substring(0, 1).toUpperCase() ?? '?',
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
                  // Dynamic background for the trophy icon
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
              fontSize: isHighlight ? 18 : 14,
              color: colorScheme.onSurface, // Adapts to theme
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user != null ? NumberFormat('#,###').format(user!.highScore) : '-',
            style: TextStyle(
              fontSize: isHighlight ? 18 : 14,
              fontWeight: FontWeight.bold,
              // Highlighted primary color, otherwise theme onSurface
              color: isHighlight ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '#$rank',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withOpacity(0.6), // Muted rank text
            ),
          ),
        ],
      ),
    );
  }
}
