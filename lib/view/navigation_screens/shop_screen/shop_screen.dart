import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/painters/home_snake_painter.dart';
import '../../../model/snake_skin_model.dart';
import '../../../provider/life_provider.dart';
import '../../../provider/user_provider.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {

  // Track open states for the 3 chests
  bool _isSimpleOpen = false;
  bool _isEpicOpen = false;
  bool _isLegendaryOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = Provider.of<UserProvider>(context);
    final life = Provider.of<LifeProvider>(context);
    // final adProv = Provider.of<AdProvider>(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // // --- Section 1: Daily Missions ---
          // _section(context, "DAILY MISSIONS"),
          // const SizedBox(height: 12),
          // _missionCard(context, user, adProv, "Quick Pulse", 3, 20, "m1"),
          // _missionCard(context, user, adProv, "Game Session", 10, 50, "m2"),
          // _missionCard(context, user, adProv, "Elite Endurance", 20, 80, "m3"),

          const SizedBox(height: 32),

          // --- Section 2: Treasure Vault ---
          // _section(context, "TREASURE VAULT"),
          // const SizedBox(height: 12),
          // _buildChestRow(context, user, adProv),
          //
          // const SizedBox(height: 32),

          // --- Section 3: Resource Exchange ---
          _section(context, "RESOURCE EXCHANGE"),
          const SizedBox(height: 12),
          _tradeCard(
            context,
            "Buy 1 Power",
            "Cost: 25 Coins",
            Icons.bolt,
            Colors.purpleAccent,
                () => _handleExchange(
                context,
                user.coins >= 25,
                "PURCHASE POWER",
                "Exchange 25 Coins for 1 Power-up?",
                Icons.bolt,
                Colors.purpleAccent,
                user.buyPower
            ),
          ),
          _tradeCard(
            context,
            "Sell 1 Power",
            "Get: 18 Coins",
            Icons.monetization_on,
            Colors.amber,
                () => _handleExchange(
                context,
                user.powerUps >= 1,
                "SELL POWER",
                "Exchange 1 Power-up for 18 Coins?",
                Icons.monetization_on,
                Colors.amber,
                user.sellPower
            ),
          ),
          _tradeCard(
            context,
            "Buy 1 Life",
            "Cost: 1 Power",
            Icons.favorite,
            Colors.redAccent,
                () => _handleExchange(
                context,
                user.powerUps >= 1,
                "RECHARGE LIFE",
                "Exchange 1 Power-up for 1 Life?",
                Icons.favorite,
                Colors.redAccent,
                    () {
                  user.tradePowerForLife();
                  life.addLives(1);
                }
            ),
          ),

          // --- Section 2.5: Snake Skins ---
          _section(context, "SNAKE SKINS"),
          const SizedBox(height: 12),

          // Categorized Rows
          _buildCategoryRow(context, user, "COMMON", SkinRarity.common),
          _buildCategoryRow(context, user, "RARE", SkinRarity.rare),
          _buildCategoryRow(context, user, "EPIC", SkinRarity.epic),
          _buildCategoryRow(context, user, "LEGENDARY", SkinRarity.legendary),
          _buildCategoryRow(context, user, "ULTIMATE", SkinRarity.ultimate),
        ],
      ),
    );
  }

  // // --- Mission Card Widget ---
  // Widget _missionCard(BuildContext context, UserProvider user, AdProvider adProv, String title, int minutes, int reward, String id) {
  //   final colorScheme = Theme.of(context).colorScheme;
  //   final isDark = themeIsDark(context);
  //   double progress = (user.totalSecondsPlayed / (minutes * 60)).clamp(0.0, 1.0);
  //   bool isReady = progress >= 1.0;
  //
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 16),
  //     decoration: BoxDecoration(
  //       borderRadius: BorderRadius.circular(24),
  //       color: isDark ? Colors.white.withOpacity(0.05) : colorScheme.primary.withOpacity(0.05),
  //       border: Border.all(
  //         color: isReady ? AppConstants.deepPurpleColor : colorScheme.outlineVariant.withOpacity(0.5),
  //         width: isReady ? 2 : 1,
  //       ),
  //     ),
  //     child: ClipRRect(
  //       borderRadius: BorderRadius.circular(24),
  //       child: BackdropFilter(
  //         filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  //         child: Padding(
  //           padding: const EdgeInsets.all(16),
  //           child: Row(
  //             children: [
  //               _buildProgressCircle(progress, colorScheme),
  //               const SizedBox(width: 16),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
  //                     Text("+$reward COINS", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 12)),
  //                   ],
  //                 ),
  //               ),
  //               _buildClaimButton(context, user, adProv, id, isReady, reward),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildProgressCircle(double progress, ColorScheme colorScheme) {
  //   bool isReady = progress >= 1.0;
  //   return Stack(
  //     alignment: Alignment.center,
  //     children: [
  //       SizedBox(
  //         width: 42,
  //         height: 42,
  //         child: CircularProgressIndicator(
  //           value: progress,
  //           strokeWidth: 4,
  //           backgroundColor: colorScheme.outlineVariant.withOpacity(0.2),
  //           color: isReady ? Colors.greenAccent : colorScheme.primary,
  //         ),
  //       ),
  //       Icon(
  //         isReady ? Icons.check : Icons.access_time_filled,
  //         size: 18,
  //         color: isReady ? Colors.greenAccent : colorScheme.onSurfaceVariant,
  //       ),
  //     ],
  //   );
  // }
  //
  // Widget _buildClaimButton(BuildContext context, UserProvider user, AdProvider adProv, String id, bool isReady, int reward) {
  //   final isClaimed = user.isRewardClaimed(id);
  //   final colorScheme = Theme.of(context).colorScheme;
  //
  //   // Logic: Is the mission done, not claimed, AND is an ad actually ready?
  //   bool adIsReady = adProv.isRewardedReady;
  //   bool canClick = isReady && !isClaimed && adIsReady;
  //   bool isWaitingForAd = isReady && !isClaimed && !adIsReady;
  //
  //   return ElevatedButton(
  //     onPressed: canClick
  //         ? () async {
  //       bool success = await adProv.showRewarded();
  //       if (success) {
  //         user.claimTimeReward(id, reward);
  //         _showSuccessDialog(context, Colors.greenAccent);
  //       }
  //     }
  //         : null,
  //     style: ElevatedButton.styleFrom(
  //       backgroundColor: isClaimed ? Colors.transparent : (canClick ? AppConstants.deepPurpleColor : colorScheme.surfaceContainer),
  //       foregroundColor: isClaimed ? colorScheme.onSurface : colorScheme.onPrimary,
  //       elevation: canClick ? 4 : 0,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(12),
  //         side: isClaimed ? BorderSide(color: colorScheme.outlineVariant) : BorderSide.none,
  //       ),
  //     ),
  //     child: isWaitingForAd
  //         ? SizedBox(
  //       width: 18,
  //       height: 18,
  //       child: CircularProgressIndicator(
  //         strokeWidth: 2,
  //         color: colorScheme.primary,
  //       ),
  //     )
  //         : Text(isClaimed ? "DONE" : (adProv.secondsRemaining > 0 ? "${adProv.secondsRemaining}s" : "CLAIM")),
  //   );
  // }

  // --- Trade Card Widget ---
  Widget _tradeCard(BuildContext context, String title, String price, IconData icon, Color accent, VoidCallback action) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Icon(icon, color: accent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(price),
        trailing: const Icon(Icons.swap_horiz),
        onTap: action,
      ),
    );
  }

  // --- Chest Row Widget ---
  // Widget _buildChestRow(BuildContext context, UserProvider user, AdProvider adProv) {
  //   return SingleChildScrollView(
  //     scrollDirection: Axis.horizontal,
  //     child: Row(
  //       children: [
  //         // 1. SIMPLE CHEST
  //         _chestItem(
  //             context,
  //             "SIMPLE",
  //             "DAILY FREE",
  //             Colors.greenAccent,
  //             'assets/images/chest_simple_sprite.png', // Path to your 6-frame JPG
  //             _isSimpleOpen,
  //             "• 10-50 Coins (100%)\n• 1 Power-up (50%)",
  //                 () async {
  //               // 1. Check if already claimed or loading
  //               if (user.isRewardClaimed("chest_simple") || adProv.isAdLoading) {
  //                 return;
  //               }
  //
  //               // 2. Start Animation Immediately
  //               setState(() => _isSimpleOpen = true);
  //
  //               // 3. Wait for the 600ms animation to complete
  //               await Future.delayed(const Duration(milliseconds: 600));
  //
  //               // 4. Play Ad AFTER chest is open
  //               bool success = await adProv.showRewarded();
  //
  //               // 5. If Ad finishes successfully, give rewards
  //               if (success) {
  //                 user.claimTimeReward("chest_simple", 0);
  //                 _openChest(context, user, "Simple");
  //               } else {
  //                 // Optional: Reset chest to closed if they cancel the ad
  //                 setState(() => _isSimpleOpen = false);
  //                 _showError(context, "Ad dismissed. Claim failed.");
  //               }
  //             }
  //         ),
  //
  //         // 2. EPIC CHEST
  //         _chestItem(
  //             context,
  //             "EPIC",
  //             "250 COINS",
  //             Colors.blueAccent,
  //             'assets/images/chest_epic_sprite.png',
  //             _isEpicOpen,
  //             "• 5-10 Power-ups (100%)\n• Rare Chance: Lives",
  //                 () async {
  //               // 1. Check if already claimed or loading
  //               if (user.isRewardClaimed("chest_epic") || adProv.isAdLoading) {
  //                 return;
  //               }
  //
  //               // 2. Start Animation Immediately
  //               setState(() => _isEpicOpen = true);
  //
  //               // 3. Wait for the 600ms animation to complete
  //               await Future.delayed(const Duration(milliseconds: 600));
  //
  //               // 4. Play Ad AFTER chest is open
  //               bool success = await adProv.showRewarded();
  //
  //               // 5. If Ad finishes successfully, give rewards
  //               if (success) {
  //                 user.claimTimeReward("chest_epic", 0);
  //                 _openChest(context, user, "Epic");
  //               } else {
  //                 // Optional: Reset chest to closed if they cancel the ad
  //                 setState(() => _isEpicOpen = false);
  //                 _showError(context, "Ad dismissed. Claim failed.");
  //               }
  //             }
  //         ),
  //
  //         // 3. LEGENDARY CHEST
  //         _chestItem(
  //             context,
  //             "LEGENDARY",
  //             "1000 COINS",
  //             Colors.purpleAccent,
  //             'assets/images/chest_legendary_sprite.png',
  //             _isLegendaryOpen,
  //             "• 30-50 Power-ups (100%)\n• Rare Chance: Lives",
  //                 () async {
  //               // 1. Check if already claimed or loading
  //               if (user.isRewardClaimed("chest_legendary") || adProv.isAdLoading) {
  //                 return;
  //               }
  //
  //               // 2. Start Animation Immediately
  //               setState(() => _isLegendaryOpen = true);
  //
  //               // 3. Wait for the 600ms animation to complete
  //               await Future.delayed(const Duration(milliseconds: 600));
  //
  //               // 4. Play Ad AFTER chest is open
  //               bool success = await adProv.showRewarded();
  //
  //               // 5. If Ad finishes successfully, give rewards
  //               if (success) {
  //                 user.claimTimeReward("chest_legendary", 0);
  //                 _openChest(context, user, "Legendary");
  //               } else {
  //                 // Optional: Reset chest to closed if they cancel the ad
  //                 setState(() => _isLegendaryOpen = false);
  //                 _showError(context, "Ad dismissed. Claim failed.");
  //               }
  //             }
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // --- Updated Chest Item Widget ---
  // Widget _chestItem(
  //     BuildContext context,
  //     String name,
  //     String price,
  //     Color color,
  //     String spritePath,
  //     bool isOpen,
  //     String info,
  //     VoidCallback onTap
  //     ) {
  //   return Container(
  //     width: 140,
  //     margin: const EdgeInsets.only(right: 12),
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: color.withOpacity(0.05),
  //       borderRadius: BorderRadius.circular(24),
  //       border: Border.all(color: color.withOpacity(0.2)),
  //     ),
  //     child: Column(
  //       children: [
  //         TweenAnimationBuilder<double>(
  //           tween: Tween(begin: 0.0, end: 1.0),
  //           duration: const Duration(seconds: 2),
  //           builder: (context, value, child) {
  //             // This creates a pulsing effect by oscillating the blur radius
  //             double pulse = (sin(value * 2 * pi) + 1) / 2;
  //             return AnimatedContainer(
  //               duration: const Duration(milliseconds: 500),
  //               decoration: BoxDecoration(
  //                 shape: BoxShape.circle,
  //                 boxShadow: [
  //                   BoxShadow(
  //                     color: isOpen ? Colors.transparent : color.withOpacity(0.3),
  //                     blurRadius: isOpen ? 0 : 15 + (pulse * 15),
  //                     spreadRadius: isOpen ? 0 : 2 + (pulse * 3),
  //                   ),
  //                 ],
  //               ),
  //               child: child,
  //             );
  //           },
  //           child: SpriteChest(
  //             assetPath: spritePath,
  //             isOpen: isOpen,
  //             onTap: onTap,
  //           ),
  //         ),
  //
  //         // --------------------------------------------------
  //
  //         const SizedBox(height: 8),
  //         Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
  //         Text(price, style: const TextStyle(color: Colors.white38, fontSize: 10)),
  //         const SizedBox(height: 4),
  //         // Info Button
  //         GestureDetector(
  //           onTap: () => _showInfoDialog(context, name, info, color),
  //           child: Icon(Icons.info_outline, size: 16, color: color.withOpacity(0.5)),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildCategoryRow(BuildContext context, UserProvider user, String title, SkinRarity rarity) {
    // Filter skins for this specific category
    final categorySkins = snakeSkins.where((s) => s.rarity == rarity).toList();

    if (categorySkins.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
          child: Row(
            children: [
              Container(width: 4, height: 16, color: categorySkins.first.rarityColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: categorySkins.first.rarityColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categorySkins.length,
            itemBuilder: (context, index) {
              final skin = categorySkins[index];
              bool isOwned = user.ownedSkinIds.contains(skin.id);
              bool isSelected = user.currentSkinId == skin.id;
              return _skinCard(context, skin, isOwned, isSelected, user);
            },
          ),
        ),
      ],
    );
  }

  Widget _skinCard(BuildContext context, SnakeSkin skin, bool isOwned, bool isSelected, UserProvider user) {

    final colorScheme = Theme.of(context).colorScheme;
    final displayColor = skin.rarity != null ? skin.rarityColor : Colors.grey;

    return Container(
      width: 150, // Slightly wider for the tag
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          // The border now glows with the rarity color if selected!
          color: isSelected ? displayColor : colorScheme.outlineVariant.withOpacity(0.5),
          width: isSelected ? 3 : 1,
        ),
      ),
      child: Column(
        children: [
          // --- RARITY TAG ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: displayColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              skin.rarity.name.toUpperCase(),
              style: TextStyle(color: displayColor, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: Center(
              child: Transform.scale(
                scale: 0.5, // Slightly larger than before for better visibility
                child: CustomPaint(
                  size: const Size(100, 100), // Give it a base size
                  painter: SimpleSnakePainter(
                    bodyColors: skin.bodyColors,
                    eyeColor: skin.eyeColor,
                    tongueColor: skin.tongueColor,
                  ),
                ),
              ),
            ),
          ),

          Text(skin.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),

          const SizedBox(height: 8),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected ? Colors.green : (isOwned ? colorScheme.primary : skin.rarityColor),
              minimumSize: const Size(double.infinity, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (!isOwned) {
                _handleExchange(
                    context,
                    user.coins >= skin.price,
                    "UNLOCK ${skin.rarity.name.toUpperCase()}",
                    "Spend ${skin.price} coins?",
                    Icons.stars,
                    skin.rarityColor,
                        () => user.buySkin(skin.id, skin.price)
                );
              } else {
                user.setSkin(skin.id);
              }
            },
            child: Text(
              isSelected ? "EQUIPPED" : (isOwned ? "SELECT" : "${skin.price}"),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color)),
        title: Text("$title CONTENTS", style: TextStyle(color: color)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))],
      ),
    );
  }

  // --- Logic Helpers ---
  void _openChest(BuildContext context, UserProvider user, String type) {
    int c = 0; int p = 0;
    final random = Random();
    if (type == "Simple") { c = 10 + random.nextInt(41); p = random.nextBool() ? 1 : 0; }
    else if (type == "Epic") { p = 5 + random.nextInt(6); }
    else { c = 500 + random.nextInt(301); p = 20 + random.nextInt(11); }
    user.addPurchasedItems(c, p);
    _showLootDialog(context, c, p);
  }

  void _showLootDialog(BuildContext context, int coins, int powers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber, width: 2)),
        title: const Center(child: Text("CHEST UNLOCKED!", style: TextStyle(color: Colors.amber))),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (coins > 0) _lootItem(Icons.monetization_on, "+$coins", Colors.amber),
            if (powers > 0) _lootItem(Icons.bolt, "+$powers", Colors.purpleAccent),
          ],
        ),
      ),
    );
  }

  Widget _lootItem(IconData icon, String val, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color), Text(val, style: const TextStyle(color: Colors.white))]);
  }

  void _handleExchange(BuildContext context, bool condition, String title, String msg, IconData icon, Color color, VoidCallback onConfirm) {
    if (condition) {
      _showTradeDialog(context: context, title: title, message: msg, icon: icon, color: color, onConfirm: onConfirm);
    } else {
      _showError(context, "INSUFFICIENT FUNDS");
    }
  }

  void _showTradeDialog({required BuildContext context, required String title, required String message, required IconData icon, required Color color, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.backgroundColor.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: color.withOpacity(0.3))),
        title: Column(children: [Icon(icon, color: color, size: 48), const SizedBox(height: 16), Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.black),
            onPressed: () { Navigator.pop(context); onConfirm(); _showSuccessDialog(context, color); },
            child: const Text("CONFIRM"),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  void _showSuccessDialog(BuildContext context, Color color) {
    showDialog(context: context, builder: (context) {
      Future.delayed(const Duration(milliseconds: 1500), () { if (Navigator.canPop(context)) Navigator.pop(context); });
      return AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 60), SizedBox(height: 16), Text("SUCCESS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
      );
    });
  }

  Widget _section(BuildContext context, String title) {
    return Text(title, style: TextStyle(color: AppConstants.deepPurpleColor, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14));
  }

  bool themeIsDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
}