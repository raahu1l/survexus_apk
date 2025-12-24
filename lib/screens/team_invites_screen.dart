// lib/screens/invite_user_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/team_service.dart';
import '../models/invite_model.dart';

class TeamInvitesScreen extends StatelessWidget {
  const TeamInvitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Login required")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Team Invites")),
      body: StreamBuilder<List<InviteModel>>(
        stream: TeamService.myPendingInvitesStream(), // ✅ CORRECT STREAM
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final invites = snapshot.data ?? [];

          if (invites.isEmpty) {
            return const Center(
              child: Text("No pending invites"),
            );
          }

          return ListView.builder(
            itemCount: invites.length,
            itemBuilder: (_, index) {
              final invite = invites[index];

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(invite.teamName ?? "Team Invitation"),
                  subtitle: Text("Invited as: ${invite.email}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          await TeamService.declineInvite(invite);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Invite declined")),
                          );
                        },
                      ),
                      ElevatedButton(
                        child: const Text("Accept"),
                        onPressed: () async {
                          await TeamService.acceptInvite(invite); // ✅ FIXED
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("✅ Joined team")),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
