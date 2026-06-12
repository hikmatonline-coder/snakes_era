import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/user_provider.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final uid = userProv.uid;

    // Safety check: Agar user login nahi hai
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Referrals")),
        body: const Center(child: Text("Please login to view referrals.", style: TextStyle(color: Colors.white))),
        backgroundColor: const Color(0xFF1A1A1A),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Dark Background
      appBar: AppBar(
        title: const Text("My Referrals", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Ab hum sidha 'users' collection se user ka apna data le rahe hain
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading data", style: TextStyle(color: Colors.redAccent)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>?;

          // Referrals list fetch karna
          List referrals = userData != null && userData.containsKey('referrals')
              ? userData['referrals']
              : [];

          // Agar kisi ne abhi tak join nahi kiya
          if (referrals.isEmpty) {
            return _buildEmptyState();
          }

          // List View: Jin doston ne join kar liya hai
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: referrals.length,
            itemBuilder: (context, index) {
              var person = referrals[index];
              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    child: const Icon(Icons.person, color: Colors.amber),
                  ),
                  title: Text(
                    person['name'] ?? "Unknown Player",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  subtitle: Text(
                    person['email'] ?? "No email provided",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Khali screen ka design
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text(
            "No Referrals Yet",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Share your code to invite friends\nand earn rewards!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }
}