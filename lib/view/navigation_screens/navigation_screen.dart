import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/widgets/life_timer_widget.dart';
import '../../provider/life_provider.dart';
import '../../provider/user_provider.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'shop_screen/shop_screen.dart';
import 'snake_io/snake_io_home_screen.dart';
import 'spin_wheel/spin_wheel_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {

  int _currentIndex = 2;
  bool _remoteDataRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemoteGameData());
  }

  Future<void> _loadRemoteGameData() async {
    if (_remoteDataRequested || !mounted) return;
    _remoteDataRequested = true;

    final userProv = context.read<UserProvider>();
    final lifeProv = context.read<LifeProvider>();

    userProv.initializeUser();
    await lifeProv.loadRemoteUserData();
  }

  final List<Widget> _pages = [
    const SpinWheelScreen(),
    ShopScreen(),
    const SnakeIOHomeScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {

    final lifeProv = Provider.of<LifeProvider>(context);
    final userProv = Provider.of<UserProvider>(context);

    // Check if we need the extra space for the timer
    // Width is 80 if lives are full (no timer), otherwise 120 (timer visible)
    double dynamicWidth = lifeProv.lives >= AppConstants.maxLives ? 80.0 : 120.0;

    return Scaffold(
      // backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // 1. LIFE ICONS (START)
        // We increase leadingWidth to ensure the life icons don't get squished
        leadingWidth: dynamicWidth,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Center(child: LifeTimerWidget()),
        ),
        // 2. COINS & POWERUPS (END)
        actions: [
          _buildStatChip(context, Icons.bolt, "${userProv.powerUps}", Colors.purpleAccent),
          const SizedBox(width: 12),
          _buildStatChip(context, Icons.monetization_on, "${userProv.coins}", Colors.amber),
          const SizedBox(width: 16),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppConstants.primaryColor.withOpacity(0.1), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: AppConstants.backgroundColor,
          selectedItemColor: AppConstants.primaryColor,
          unselectedItemColor: AppConstants.navBarUnSelectedItem,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: AppConstants.navSpin),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: AppConstants.navShop),
            BottomNavigationBarItem(icon: Icon(Icons.sports_esports), label: AppConstants.navGames),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: AppConstants.navRank),
            BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: AppConstants.navProfile),
          ],
        ),
      ),
    );
  }

  // Refactored helper for the Stats Bar
  Widget _buildStatChip(BuildContext context, IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}