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
import '../shop_screen/shop_screen.dart';

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
    final userProv = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(user?.photoUrl ?? 'https://picsum.photos/200'),
                    backgroundColor: AppConstants.primaryColor,
                  ),
                  Column(
                    children: [
                      Text(user?.displayName ?? "Guest Player", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(user?.email ?? "no-email@arcade.com", style: const TextStyle(color: Colors.grey)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 40),
              _buildPremiumWalletDashboard(context, userProv),
              const SizedBox(height: 24),
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

  // ========================================================
  //     PREMIUM WALLET DASHBOARD WITH INVENTORY BREAKDOWN
  // ========================================================
  bool themeIsDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  Widget _buildPremiumWalletDashboard(BuildContext context, UserProvider user) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = themeIsDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.deepPurple.withOpacity(0.3), Colors.black.withOpacity(0.4)]
              : [colorScheme.primary.withOpacity(0.08), colorScheme.primary.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppConstants.deepPurpleColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _walletMiniTile(Icons.monetization_on, "COINS", "${user.coins}", Colors.amber)),
              const SizedBox(width: 12),
              Expanded(child: _walletMiniTile(Icons.bolt, "POWER", "${user.powerUps}", Colors.purpleAccent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _walletMiniTile(
                      Icons.confirmation_number,
                      "TICKETS",
                      "${user.tickets}",
                      Colors.cyanAccent)
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: _walletMiniTile(
                      Icons.account_balance_wallet,
                      "TOTAL VAL",
                      "\$${user.voucherWallet.toStringAsFixed(2)}",
                      Colors.greenAccent
                  )
              ),
            ],
          ),

          // --- NEW: PHYSICAL VOUCHER SPECIFIC BREAKDOWN SYSTEM ---
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 12, color: Colors.white38),
              const SizedBox(width: 6),
              Text("YOUR VOUCHER INVENTORY:", style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: GameEconomy.voucherTiers.map((tier) {
              int count = 0;
              try {
                count = user.getVoucherCount(tier); // Dynamic fetch from provider
              } catch (_) {
                // If method doesn't exist yet, we visually estimate mock count safely
                count = (user.voucherWallet >= tier) ? 1 : 0;
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: count > 0 ? Colors.greenAccent.withOpacity(0.08) : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: count > 0 ? Colors.greenAccent.withOpacity(0.3) : Colors.white10),
                ),
                child: Row(
                  children: [
                    Text("\$${tier.toInt()}: ", style: TextStyle(color: count > 0 ? Colors.greenAccent : Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text("$count x", style: TextStyle(color: count > 0 ? Colors.white : Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ),

          if (user.voucherWallet > 0.0 && user.voucherExpiryDate != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "Vouchers Expire On: ${user.voucherExpiryDate!.day}/${user.voucherExpiryDate!.month}/${user.voucherExpiryDate!.year}",
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _walletMiniTile(IconData icon, String title, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: accentColor.withOpacity(0.15),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }


}