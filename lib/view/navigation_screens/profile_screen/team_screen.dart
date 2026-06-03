import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/social_provider.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Join a Team"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('teams').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var team = snapshot.data!.docs[index];
              return ListTile(
                title: Text(team['teamName'] ?? "Unnamed Team"),
                trailing: ElevatedButton(
                  onPressed: () async {
                    try {
                      await context.read<SocialProvider>().joinTeam(uid!, team.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined Successfully!")));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  child: const Text("Join"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}