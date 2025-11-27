import 'package:flutter/material.dart';
import '../services/team_service.dart';
import '../models/team_model.dart';

class TeamManagementScreen extends StatelessWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teams")),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.group_add),
        onPressed: () => _createTeamDialog(context),
      ),
      body: StreamBuilder<List<TeamModel>>(
        stream: TeamService.myTeamsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text("❌ ERROR: ${snap.error}"));
          }

          final teams = snap.data ?? [];

          if (teams.isEmpty) {
            return const Center(child: Text("No teams yet"));
          }

          return ListView.builder(
            itemCount: teams.length,
            itemBuilder: (_, i) {
              final team = teams[i];
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(team.name),
                  subtitle: Text("${team.members.length} members"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteTeam(context, team),
                  ),
                  onTap: () => _openTeam(context, team),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _createTeamDialog(BuildContext context) {
    final c = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Team"),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: "Team name"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = c.text.trim();
              if (name.isEmpty) return;

              try {
                await TeamService.createTeam(name);

                if (context.mounted) Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Team created")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text("❌ $e")));
              }
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }

  void _openTeam(BuildContext context, TeamModel team) {
    final email = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(team.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              ...team.members.map((m) => ListTile(
                    title: Text(m.email),
                    trailing: Text(m.role),
                  )),
              const Divider(),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: "Invite email"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await TeamService.sendInvite(
                      teamId: team.id,
                      teamName: team.name,
                      emailToInvite: email.text.trim(),
                    );
                    if (context.mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Invite sent")),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("❌ $e")));
                  }
                },
                child: const Text("Send Invite"),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _deleteTeam(BuildContext context, TeamModel team) async {
    try {
      await TeamService.deleteTeam(team.id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("🗑 Team deleted")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ $e")));
    }
  }
}
