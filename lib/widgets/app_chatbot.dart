// lib/widgets/app_chatbot.dart

import 'package:flutter/material.dart';
import '../secrets.dart';
import '../services/chatbot_service.dart';

class AppChatBotButton extends StatelessWidget {
  const AppChatBotButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.indigo,
      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const AppChatBotSheet(),
        );
      },
    );
  }
}

class AppChatBotWelcomeBanner extends StatefulWidget {
  const AppChatBotWelcomeBanner({super.key});

  @override
  State<AppChatBotWelcomeBanner> createState() =>
      _AppChatBotWelcomeBannerState();
}

class _AppChatBotWelcomeBannerState extends State<AppChatBotWelcomeBanner> {
  bool show = true;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Positioned(
      bottom: 95,
      right: 20,
      left: 20,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "👋 Hello! How can I help you understand Survexus?",
                  style: TextStyle(fontSize: 15),
                ),
              ),
              InkWell(
                onTap: () => setState(() => show = false),
                child: const Icon(Icons.close, size: 20),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class AppChatBotSheet extends StatefulWidget {
  const AppChatBotSheet({super.key});

  @override
  State<AppChatBotSheet> createState() => _AppChatBotSheetState();
}

class _AppChatBotSheetState extends State<AppChatBotSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [];
  bool loading = false;

  // 👉 Your API KEY stays here
  final String apiKey = groqApiKey;

  // 👉 User role
  final String userRole = "user"; // guest / user / vip

  // -------------------------------------------------------------
  // INITIAL BOT MESSAGE (Only addition you asked for)
  // -------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    messages.add({
      "sender": "bot",
      "text":
          "Hi! I'm the Survexus Assistant 🤖\nHow can I help you today?\n\nYou can ask about:\n• Creating surveys\n• Responding\n• Analytics\n• Guest mode\n• Managing surveys"
    });
  }

  // -------------------------------------------------------------
  // ROLE PROMPT
  // -------------------------------------------------------------
  String getRolePrompt() {
    if (userRole == "guest") {
      return """
You are the Survexus Assistant for *GUEST USERS*.

GUEST RULES:
• Guests CANNOT create surveys.
• Guests CANNOT view analytics.
• Guests CANNOT manage responses.
• Guests can ONLY respond to surveys.

If user asks for a restricted feature:
"As a guest, you cannot perform this action. Please login."

If question is outside Survexus:
"I can only assist with Survexus app features."
""";
    }

    if (userRole == "vip") {
      return """
You are the Survexus Assistant for *VIP USERS*.

VIP FEATURES:
• Create unlimited surveys  
• View advanced analytics  
• Deep explanations  
• Manage responses  
• Full permissions

If outside Survexus:
"I can only assist with Survexus app features."
""";
    }

    return """
You are the Survexus Assistant for *NORMAL LOGGED-IN USERS*.

USER FEATURES:
• Can create surveys  
• Can respond  
• Can view analytics  
• Can manage their OWN surveys  
• Guests CANNOT create surveys

If outside Survexus:
"I can only assist with Survexus app features."
""";
  }

  // -------------------------------------------------------------
  // SEND TO CHATBOT SERVICE
  // -------------------------------------------------------------
  Future<String> getBotReply(String message) async {
    final fullPrompt = """
${getRolePrompt()}

User: $message
""";

    return await ChatbotService.sendMessage(apiKey, fullPrompt);
  }

  // -------------------------------------------------------------
  // SEND MESSAGE
  // -------------------------------------------------------------
  void sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "text": text});
      loading = true;
    });

    _controller.clear();

    final reply = await getBotReply(text);

    setState(() {
      loading = false;
      messages.add({"sender": "bot", "text": reply});
    });
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // drag indicator
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          const Text(
            "Survexus Assistant",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const Divider(),

          Expanded(
            child: ListView(
              children: messages.map((msg) {
                final isUser = msg["sender"] == "user";

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.indigo : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          if (loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Ask something about Survexus...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.indigo,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: sendMessage,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
