// lib/screens/invite_inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/invite_model.dart';
import '../services/team_service.dart';

class InviteInboxScreen extends StatelessWidget {
  const InviteInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team Invites')),
        body: const Center(
          child: Text('Sign in to see your team invites.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Invites'),
      ),
      body: StreamBuilder<List<InviteModel>>(
        stream: TeamService.myPendingInvitesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Text('Error loading invites: ${snap.error}'),
            );
          }

          final invites = snap.data ?? [];

          if (invites.isEmpty) {
            return const Center(
              child: Text(
                'No pending invites.\nAsk your team admin to send you one.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final invite = invites[index];
              return _InviteCard(invite: invite);
            },
          );
        },
      ),
    );
  }
}

class _InviteCard extends StatefulWidget {
  final InviteModel invite;
  const _InviteCard({required this.invite});

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  bool _loading = false;

  Future<void> _handleAccept() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      await TeamService.acceptInvite(widget.invite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Joined team "${widget.invite.teamName ?? 'Team'}" successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleDecline() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      await TeamService.declineInvite(widget.invite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invite.teamName ?? 'Team',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Invited as: ${invite.email}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (invite.invitedByEmail != null) ...[
              const SizedBox(height: 2),
              Text(
                'By: ${invite.invitedByEmail}',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _handleAccept,
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _loading ? null : _handleDecline,
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
