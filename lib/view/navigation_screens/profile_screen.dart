import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../provider/auth_provider.dart';
import '../../provider/life_provider.dart';
import '../../provider/theme_provider.dart';
import '../../provider/user_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(user?.photoUrl ?? 'https://picsum.photos/200'),
              backgroundColor: AppConstants.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(user?.displayName ?? "Guest Player", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(user?.email ?? "no-email@arcade.com", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            _buildSettingTile(
              context,
              icon: Icons.brightness_6,
              title: "Dark Mode",
              trailing: Switch(
                value: themeProvider.themeMode == ThemeMode.dark,
                activeColor: AppConstants.primaryColor,
                onChanged: (val) => themeProvider.toggleTheme(),
              ),
            ),
            _buildSettingTile(
              context,
              icon: Icons.notifications,
              title: "Notifications",
              trailing: const Icon(Icons.chevron_right),
            ),
            _buildSettingTile(
              context,
              icon: Icons.shield,
              title: "Privacy Policy",
              trailing: const Icon(Icons.chevron_right),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                context.read<UserProvider>().resetLocalState();
                context.read<LifeProvider>().resetLocalState();
                await authProvider.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
                elevation: 0,
              ),
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(BuildContext context, {required IconData icon, required String title, required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.primaryColor),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}
