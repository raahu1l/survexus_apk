import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationStream(String uid) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _markAsRead(String docId, String uid) async {
    final doc =
        FirebaseFirestore.instance.collection('notifications').doc(docId);
    await doc.update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hr ago";
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Sign in to view notifications."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text("No notifications yet.",
                  style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final isRead =
                  (data['readBy'] as List<dynamic>?)?.contains(user.uid) ??
                      false;
              final title = data['title'] ?? "Notification";
              final message = data['message'] ?? "";
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

              return Card(
                color: isRead ? Colors.grey[100] : Colors.indigo[50],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(title,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                        color: Colors.black87,
                      )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message,
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 4),
                      if (timestamp != null)
                        Text(
                          _formatTime(timestamp),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                  onTap: () => _markAsRead(docs[i].id, user.uid),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
