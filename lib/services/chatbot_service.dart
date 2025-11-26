// lib/services/chatbot_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  static Future<String> sendMessage(String apiKey, String userMessage) async {
    final url = Uri.parse("https://api.groq.com/openai/v1/chat/completions");

    final body = {
      "model": "llama-3.3-70b-versatile",
      "messages": [
        {
          "role": "system",
          "content":
              "You are the SURVEXUS assistant. Only answer questions about the Survexus app. If the user asks anything else, reply: 'I can only assist with Survexus app features.'"
        },
        {"role": "user", "content": userMessage}
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode(body),
      );

      print("RAW GROQ RESPONSE: ${response.body}");

      final data = jsonDecode(response.body);

      // ----- FORMAT 1 -----
      // choices[0].message.content (string)
      final directContent = data["choices"]?[0]?["message"]?["content"];

      if (directContent is String && directContent.isNotEmpty) {
        return directContent;
      }

      // ----- FORMAT 2 -----
      // content: [ { "type": "text", "text": "Hello..." } ]
      final contentArray = data["choices"]?[0]?["message"]?["content"];

      if (contentArray is List && contentArray.isNotEmpty) {
        final text = contentArray[0]?["text"];
        if (text is String && text.isNotEmpty) {
          return text;
        }
      }

      return "I couldn’t understand that.";
    } catch (e) {
      return "Error: $e";
    }
  }
}
