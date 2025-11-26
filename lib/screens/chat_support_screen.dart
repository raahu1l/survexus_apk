// lib/screens/chat_support_screen.dart
import 'package:flutter/material.dart';
import '../services/chatbot_service.dart';

class ChatSupportScreen extends StatefulWidget {
  final String apiKey;

  const ChatSupportScreen({super.key, required this.apiKey});

  @override
  State<ChatSupportScreen> createState() => _ChatSupportScreenState();
}

class _ChatSupportScreenState extends State<ChatSupportScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [];

  @override
  void initState() {
    super.initState();

    // Auto welcome message
    messages.add({
      "sender": "bot",
      "text":
          "👋 Hello! I'm the Survexus Assistant.\nAsk me anything about using the app."
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "text": text});
      _controller.clear();
    });

    final reply = await ChatbotService.sendMessage(widget.apiKey, text);

    setState(() {
      messages.add({"sender": "bot", "text": reply});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Survexus Assistant"),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final msg = messages[i];
                final isUser = msg["sender"] == "user";

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF6366F1)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Ask about Survexus...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF6366F1)),
                  onPressed: _send,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
