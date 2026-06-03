import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:snakes_era/view/navigation_screens/profile_screen/team_screen.dart';
import '../../../core/constants.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/life_provider.dart';
import '../../../provider/social_provider.dart';
import '../../../provider/theme_provider.dart';
import '../../../provider/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final socialProvider = Provider.of<SocialProvider>(context, listen: false);

      bool showPopup = await socialProvider.shouldShowReferralPopup(authProvider.user?.referredBy);

      if (showPopup) {
        _showReferralDialog(context);
      }
    });
  }

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

            _buildSettingTile(context, icon: Icons.brightness_6, title: "Dark Mode",
              trailing: Switch(
                value: themeProvider.themeMode == ThemeMode.dark,
                activeColor: AppConstants.primaryColor,
                onChanged: (val) => themeProvider.toggleTheme(),
              ),
            ),
            _buildSettingTile(context, icon: Icons.notifications, title: "Notifications",
              trailing: const Icon(Icons.chevron_right),
            ),
            _buildSettingTile(context, icon: Icons.card_giftcard, title: "Redeem Referral Code",
              trailing: const Icon(Icons.edit, size: 16),
              onTap: () => _showReferralDialog(context),
            ),
            _buildSettingTile(context, icon: Icons.group, title: "My Team",
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeamScreen()))
            ),
            _buildSettingTile(context, icon: Icons.share, title: "Invite & Earn",
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.read<SocialProvider>().shareReferralCode(user?.id ?? "")
            ),
            _buildSettingTile(context, icon: Icons.copy, title: "Copy Referral Code",
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: user?.id ?? ""));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code Copied!")));
                }),
            _buildSettingTile(context, icon: Icons.shield, title: "Privacy Policy",
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

  Widget _buildSettingTile(BuildContext context, {required IconData icon, required String title, required Widget trailing, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppConstants.primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

void _showReferralDialog(BuildContext context) {
  String code = "";
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard, size: 60, color: Colors.amber), // Gift Icon
            const SizedBox(height: 16),
            const Text("Unlock Rewards!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Enter your friend's code to claim 30 Coins & 3 PowerUps instantly!",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              onChanged: (val) => code = val,
              decoration: InputDecoration(
                hintText: "Paste referral code here",
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  try {
                    final myId = context.read<AuthProvider>().user?.id ?? "";
                    await context.read<SocialProvider>().applyReferral(myId, code);
                    Navigator.pop(ctx);
                    _showSuccessDialog(context); // Niche wala function call karein
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                child: const Text("CLAIM REWARD", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Separate Success Dialog for clean code
void _showSuccessDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
      content: const Text("Yay! Rewards added successfully!", textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("THANKS!")),
      ],
    ),
  );
}