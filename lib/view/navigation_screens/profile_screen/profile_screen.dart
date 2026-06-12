import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:snakes_era/core/widgets/referral_dialogs.dart';
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

  bool _isCheckingReferral = false;

  @override
  void initState() {
    super.initState();
    // 1. Post-frame callback mein check zaroori hai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkReferralStatus();
    });
  }

  Future<void> _checkReferralStatus() async {
    if (_isCheckingReferral || !mounted) return;

    setState(() => _isCheckingReferral = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final socialProvider = Provider.of<SocialProvider>(context, listen: false);

    bool showPopup = await socialProvider.shouldShowReferralPopup(authProvider.user?.referredBy);

    if (mounted && showPopup) {
      ReferralDialogs.showRedeemDialog(context);
    }
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
              onTap: () => ReferralDialogs.showRedeemDialog(context),
            ),
            _buildSettingTile(context, icon: Icons.group, title: "My Team",
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeamScreen()))
            ),
            _buildSettingTile(context, icon: Icons.share, title: "Invite & Earn",
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.read<SocialProvider>().shareReferralCode(context.read<UserProvider>().referralCode)
            ),
            _buildSettingTile(context, icon: Icons.copy, title: "Copy Referral Code",
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final code = context.read<UserProvider>().referralCode;
                  Clipboard.setData(ClipboardData(text: code ?? ""));
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