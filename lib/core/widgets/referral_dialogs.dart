import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/auth_provider.dart';
import '../../provider/social_provider.dart';

class ReferralDialogs {
  static void showRedeemDialog(BuildContext context) {
    String code = "";
    final authProvider = context.read<AuthProvider>();
    final socialProvider = context.read<SocialProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // Fix: Get exact user details required for the new referral tree
    final myId = authProvider.user?.id ?? authProvider.user?.id ?? ""; // .uid or .id handled safely
    final myName = authProvider.user?.displayName ?? "Guest Player";
    final myEmail = authProvider.user?.email ?? "No Email";

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A1A),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.card_giftcard, size: 60, color: Colors.amber),
                const SizedBox(height: 16),
                const Text("Redeem Rewards", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text("Enter a referral code to claim 100 Coins & 10 PowerUps instantly!",
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                TextField(
                  onChanged: (val) => code = val,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter code here",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: () async {
                      try {
                        if (myId.isEmpty) throw Exception("User not authenticated");
                        if (code.isEmpty) throw Exception("Please enter a valid code");

                        // Fix: Updated function call with name and email
                        await socialProvider.applyReferral(context, myId, myName, myEmail, code);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }

                        messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Rewards claimed successfully!"),
                              backgroundColor: Colors.green,
                            )
                        );

                        if (context.mounted) {
                          showSuccessDialog(context);
                        }
                      } catch (e) {
                        messenger.showSnackBar(
                            SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.redAccent
                            )
                        );
                      }
                    },
                    child: const Text("CLAIM REWARD", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        content: const Text("Rewards added successfully!", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("THANKS!", style: TextStyle(color: Colors.amber))),
        ],
      ),
    );
  }
}