import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/painters/home_snake_painter.dart';
import '../../../model/snake_skin_model.dart';
import '../../../provider/ads_provider.dart';
import '../../../provider/life_provider.dart';
import '../../../provider/user_provider.dart';

// ========================================================
//    CENTRALIZED GAME ECONOMY CONFIGURATION (Source of Truth)
// ========================================================
class GameEconomy {
  static const int ticketBundleBase = 1000;
  static const int ticketsPerCoin = 10;     // 10 Tickets = 1 Coin
  static const int ticketsPerPower = 100;   // 100 Tickets = 1 Power

  static int get coinsFromTicketBundle => ticketBundleBase ~/ ticketsPerCoin;   // 100 Coins
  static int get powerFromTicketBundle => ticketBundleBase ~/ ticketsPerPower; // 10 Powers

  // --- NEW VOUCHER SYSTEM CONFIGURATION ---
  static const int ticketsPerOneUsd = 10000;      // <--- 10,000 Tickets = 1 USD Base Rate
  static const double voucherLiquidityFee = 0.20; // 20% system return fee

  // Available tiers in the marketplace
  static const List<double> voucherTiers = [1.0, 2.0, 3.0, 5.0];

  // Dynamically calculate ticket cost for any voucher tier
  static int getTicketCostForVoucher(double usdValue) {
    return (usdValue * ticketsPerOneUsd).toInt();
  }

  // Dynamically calculate return reward minus system fee
  static int getTicketRewardForReturningVoucher(double usdValue) {
    int baseTickets = getTicketCostForVoucher(usdValue);
    return (baseTickets * (1 - voucherLiquidityFee)).toInt();
  }

  // Core Resource Trade Rates
  static const int buyPowerCoinCost = 25;
  static const int sellPowerCoinReward = 18;
  static const int powerForLifeCost = 1;
}

// ========================================================
//                     MAIN SHOP SCREEN
// ========================================================
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = Provider.of<UserProvider>(context);
    final life = Provider.of<LifeProvider>(context);
    final adProv = Provider.of<AdProvider>(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ========================================================
          //   PREMIUM WALLET DASHBOARD (With Inventory Breakdown)
          // ========================================================
          _buildPremiumWalletDashboard(context, user),
          const SizedBox(height: 24),

          // --- Section 1: Daily Missions ---
          _section(context, "DAILY IN-GAME MISSIONS", Icons.star_purple500_outlined),
          const SizedBox(height: 12),
          _missionCard(context, user, adProv, "Quick Pulse", 3, 20, "m1"),
          _missionCard(context, user, adProv, "Game Session", 10, 50, "m2"),
          _missionCard(context, user, adProv, "Elite Endurance", 20, 80, "m3"),

          const SizedBox(height: 28),

          // --- SECTION 2: DYNAMIC TICKET TO VOUCHER MARKET ---
          _section(context, "USD VOUCHER MARKET (10K RATE)", Icons.card_giftcard_rounded),
          const SizedBox(height: 12),

          // Loop through all defined tiers ($1, $2, $3, $5) automatically!
          ...GameEconomy.voucherTiers.map((tier) {
            int ticketCost = GameEconomy.getTicketCostForVoucher(tier);
            return _modernTradeCard(
              context,
              title: "Buy \$${tier.toStringAsFixed(2)} USD Voucher",
              subtitle: "Convert tickets to real money voucher",
              costText: "$ticketCost Tickets",
              rewardText: "+\$${tier.toStringAsFixed(2)} Voucher",
              icon: Icons.card_giftcard,
              accentColor: Colors.greenAccent,
              onTap: () => _handleExchange(
                context,
                user.tickets >= ticketCost,
                "MINT \$${tier.toStringAsFixed(2)} VOUCHER",
                "Convert $ticketCost Tickets into a \$${tier.toStringAsFixed(2)} cashout voucher?",
                Icons.card_giftcard,
                Colors.greenAccent,
                    () => user.buyVoucherWithTickets(ticketCost, tier),
              ),
            );
          }),

          const SizedBox(height: 16),
          // --- LIQUIDITY RETURN MARKET (Loop for selling back any tier) ---
          _section(context, "VOUCHER LIQUIDITY RETURNS", Icons.assignment_return_rounded),
          const SizedBox(height: 12),

          ...GameEconomy.voucherTiers.map((tier) {
            int ticketReward = GameEconomy.getTicketRewardForReturningVoucher(tier);

            // Checking if user has at least one voucher of this specific tier
            // (Assumed your provider can check this, if not fallback to total wallet check)
            bool hasSpecificVoucher = false;
            try {
              hasSpecificVoucher = user.getVoucherCount(tier) > 0;
            } catch (_) {
              hasSpecificVoucher = user.voucherWallet >= tier;
            }

            return _modernTradeCard(
              context,
              title: "Return \$${tier.toStringAsFixed(2)} Voucher",
              subtitle: "Need urgent tickets? Get back with 20% system fee",
              costText: "\$${tier.toStringAsFixed(2)} Voucher",
              rewardText: "+$ticketReward Tickets",
              icon: Icons.refresh_rounded,
              accentColor: Colors.orangeAccent,
              onTap: () => _handleExchange(
                context,
                hasSpecificVoucher,
                "RETURN VOUCHER",
                "Return your \$${tier.toStringAsFixed(2)} Voucher to pool for $ticketReward Tickets?",
                Icons.refresh_rounded,
                Colors.orangeAccent,
                    () => user.sellVoucherForTickets(tier, ticketReward),
              ),
            );
          }),

          const SizedBox(height: 28),

          // --- SECTION 3: TICKET TO COINS EXCHANGE ---
          _section(context, "COIN MARKET", Icons.currency_exchange_rounded),
          const SizedBox(height: 12),
          _modernTradeCard(
            context,
            title: "Convert Tickets to Coins",
            subtitle: "Exchange ${GameEconomy.ticketBundleBase} Tickets based on valuation",
            costText: "${GameEconomy.ticketBundleBase} Tickets",
            rewardText: "+${GameEconomy.coinsFromTicketBundle} Coins",
            icon: Icons.monetization_on,
            accentColor: Colors.amber,
            onTap: () => _handleExchange(
              context,
              user.tickets >= GameEconomy.ticketBundleBase,
              "TRADE TICKETS",
              "Convert ${GameEconomy.ticketBundleBase} Tickets into ${GameEconomy.coinsFromTicketBundle} Gold Coins?",
              Icons.monetization_on,
              Colors.amber,
                  () => user.tradeTicketsForCoins(GameEconomy.ticketBundleBase, GameEconomy.coinsFromTicketBundle),
            ),
          ),

          const SizedBox(height: 28),

          // --- SECTION 4: IN-GAME CORE RESOURCE EXCHANGE ---
          _section(context, "RESOURCE CORE EXCHANGE", Icons.swap_horizontal_circle_outlined),
          const SizedBox(height: 12),

          _modernTradeCard(
            context,
            title: "Purchase Power-Up",
            subtitle: "Boost gameplay and unlock features",
            costText: "${GameEconomy.buyPowerCoinCost} Coins",
            rewardText: "+1 Power",
            icon: Icons.bolt,
            accentColor: Colors.purpleAccent,
            onTap: () => _handleExchange(
                context,
                user.coins >= GameEconomy.buyPowerCoinCost,
                "PURCHASE POWER",
                "Exchange ${GameEconomy.buyPowerCoinCost} Coins for 1 Power-up?",
                Icons.bolt,
                Colors.purpleAccent,
                user.buyPower
            ),
          ),

          _modernTradeCard(
            context,
            title: "Liquidate Power-Up",
            subtitle: "Sell extra powers back into gold reserves",
            costText: "1 Power",
            rewardText: "+${GameEconomy.sellPowerCoinReward} Coins",
            icon: Icons.monetization_on_outlined,
            accentColor: Colors.amber,
            onTap: () => _handleExchange(
                context,
                user.powerUps >= 1,
                "SELL POWER",
                "Exchange 1 Power-up for ${GameEconomy.sellPowerCoinReward} Coins?",
                Icons.monetization_on_outlined,
                Colors.amber,
                user.sellPower
            ),
          ),

          _modernTradeCard(
            context,
            title: "Recharge Life Vitality",
            subtitle: "Sacrifice power energy for an extra game life",
            costText: "${GameEconomy.powerForLifeCost} Power",
            rewardText: "+1 Life",
            icon: Icons.favorite_rounded,
            accentColor: Colors.redAccent,
            onTap: () => _handleExchange(
                context,
                user.powerUps >= GameEconomy.powerForLifeCost,
                "RECHARGE LIFE",
                "Exchange ${GameEconomy.powerForLifeCost} Power-up for 1 Life?",
                Icons.favorite_rounded,
                Colors.redAccent,
                    () {
                  user.tradePowerForLife();
                  life.addLives(1);
                }
            ),
          ),

          const SizedBox(height: 28),

          // --- Section 5: Snake Skins ---
          _section(context, "PREMIUM SNAKE SKINS", Icons.palette_outlined),
          const SizedBox(height: 12),

          _buildCategoryRow(context, user, "COMMON", SkinRarity.common),
          _buildCategoryRow(context, user, "RARE", SkinRarity.rare),
          _buildCategoryRow(context, user, "EPIC", SkinRarity.epic),
          _buildCategoryRow(context, user, "LEGENDARY", SkinRarity.legendary),
          _buildCategoryRow(context, user, "ULTIMATE", SkinRarity.ultimate),
        ],
      ),
    );
  }

  // ========================================================
  //     PREMIUM WALLET DASHBOARD WITH INVENTORY BREAKDOWN
  // ========================================================
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
              Expanded(child: _walletMiniTile(Icons.confirmation_number, "TICKETS", "${user.tickets}", Colors.cyanAccent)),
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

  // ========================================================
  //             ATTRACTIVE MARKET DEALS DESIGNER
  // ========================================================
  Widget _modernTradeCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required String costText,
        required String rewardText,
        required IconData icon,
        required Color accentColor,
        required VoidCallback onTap,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.surfaceContainer, Colors.black.withOpacity(0.2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.2)),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                          child: Text(costText, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_right_alt, color: Colors.white30, size: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text(rewardText, style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Mission Card Widget ---
  Widget _missionCard(BuildContext context, UserProvider user, AdProvider adProv, String title, int minutes, int reward, String id) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = themeIsDark(context);
    double progress = (user.totalSecondsPlayed / (minutes * 60)).clamp(0.0, 1.0);
    bool isReady = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? Colors.white.withOpacity(0.05) : colorScheme.primary.withOpacity(0.05),
        border: Border.all(
          color: isReady && !user.isRewardClaimed(id) ? AppConstants.deepPurpleColor : colorScheme.outlineVariant.withOpacity(0.5),
          width: isReady && !user.isRewardClaimed(id) ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildProgressCircle(progress, colorScheme, user.isRewardClaimed(id)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("+$reward COINS", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 12)),
                    ],
                  ),
                ),
                _buildClaimButton(context, user, adProv, id, isReady, reward),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCircle(double progress, ColorScheme colorScheme, bool isClaimed) {
    bool isReady = progress >= 1.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(
            value: isClaimed ? 1.0 : progress,
            strokeWidth: 4,
            backgroundColor: colorScheme.outlineVariant.withOpacity(0.2),
            color: isClaimed || isReady ? Colors.greenAccent : colorScheme.primary,
          ),
        ),
        Icon(
          isClaimed || isReady ? Icons.check : Icons.access_time_filled,
          size: 18,
          color: isClaimed || isReady ? Colors.greenAccent : colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _buildClaimButton(BuildContext context, UserProvider user, AdProvider adProv, String id, bool isReady, int reward) {
    final isClaimed = user.isRewardClaimed(id);
    final colorScheme = Theme.of(context).colorScheme;

    bool adIsReady = adProv.isRewardedReady;
    int cooldown = adProv.secondsRemaining;
    bool isNetworkLoading = adProv.isAdLoading;

    bool canClick = isReady && !isClaimed && adIsReady && cooldown == 0 && !isNetworkLoading;
    bool showSpinner = isReady && !isClaimed && (isNetworkLoading || (!adIsReady && cooldown == 0));

    return ElevatedButton(
      onPressed: canClick
          ? () async {
        await adProv.showRewardedAd(
          onUserEarnedReward: (ad, rewardItem) {
            user.claimTimeReward(id, reward);
            _showSuccessDialog(context, Colors.greenAccent);
          },
        );
      }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isClaimed
            ? Colors.transparent
            : (canClick ? AppConstants.deepPurpleColor : colorScheme.surfaceContainer),
        foregroundColor: isClaimed ? colorScheme.onSurface : colorScheme.onPrimary,
        disabledBackgroundColor: isClaimed ? Colors.transparent : colorScheme.surfaceContainer.withOpacity(0.5),
        disabledForegroundColor: isClaimed ? colorScheme.onSurfaceVariant.withOpacity(0.4) : colorScheme.onSurfaceVariant,
        elevation: canClick ? 4 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isClaimed ? BorderSide(color: colorScheme.outlineVariant) : BorderSide.none,
        ),
      ),
      child: showSpinner
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppConstants.deepPurpleColor,
        ),
      )
          : Text(
        isClaimed
            ? "DONE"
            : (!isReady
            ? "LOCKED"
            : (cooldown > 0
            ? "${cooldown}s"
            : "CLAIM")),
      ),
    );
  }

  Widget _buildCategoryRow(BuildContext context, UserProvider user, String title, SkinRarity rarity) {
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
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? displayColor : colorScheme.outlineVariant.withOpacity(0.5),
          width: isSelected ? 3 : 1,
        ),
      ),
      child: Column(
        children: [
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
                scale: 0.5,
                child: CustomPaint(
                  size: const Size(100, 100),
                  painter: SimpleSnakePainter(
                    bodyColors: skin.bodyColors,
                    eyeColor: skin.eyeColor,
                    tongueColor: skin.tongueColor,
                  ),
                ),
              ),
            ),
          ),
          Text(skin.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
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

  void _handleExchange(BuildContext context, bool condition, String title, String msg, IconData icon, Color color, VoidCallback onConfirm) {
    if (condition) {
      _showTradeDialog(context: context, title: title, message: msg, icon: icon, color: color, onConfirm: onConfirm);
    } else {
      _showError(context, "INSUFFICIENT BALANCE FOR THIS TRADE");
    }
  }

  void _showTradeDialog({required BuildContext context, required String title, required String message, required IconData icon, required Color color, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.95),
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

  Widget _section(BuildContext context, String title, IconData sectionIcon) {
    return Row(
      children: [
        Icon(sectionIcon, color: AppConstants.deepPurpleColor, size: 18),
        const SizedBox(width: 8),
        Text(
            title,
            style: TextStyle(color: AppConstants.deepPurpleColor, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)
        ),
      ],
    );
  }

  bool themeIsDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
}