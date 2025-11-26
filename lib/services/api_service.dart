import 'dart:convert';
import 'dart:developer'; // ✅ use this instead of print()
import 'package:http/http.dart' as http;

class ApiService {
  /// ✅ Reliable Free API — always returns JSON (no key required)
  static const String _publicApiUrl =
      'https://api.spaceflightnewsapi.net/v4/articles/?limit=10';

  /// ✅ Guaranteed fallback data (shown even if API fails)
  static const List<Map<String, String>> _fallbackNews = [
    {
      "title": "AI Revolutionizes Healthcare",
      "description":
          "Machine learning enables early disease detection across India.",
      "url": "https://example.com/ai-health"
    },
    {
      "title": "Startups Launch Low-Cost Satellites",
      "description":
          "Space tech startups are making headlines with low-cost satellite innovations.",
      "url": "https://example.com/startup-space"
    },
    {
      "title": "EV Adoption Soars Past 3 Million",
      "description":
          "Electric mobility reshapes transport across India's urban cities.",
      "url": "https://example.com/ev-boom"
    },
  ];

  /// ✅ Fetch latest news, with full fallback protection
  static Future<List<Map<String, String>>> fetchNews() async {
    final url = Uri.parse(_publicApiUrl);

    try {
      final response = await http.get(url, headers: {
        "Accept": "application/json"
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = json.decode(response.body);

        final List<dynamic> articles =
            decoded['results'] ?? decoded['articles'] ?? [];

        if (articles.isNotEmpty) {
          final parsed = articles.map<Map<String, String>>((a) {
            return {
              "title": (a['title'] ?? "Untitled Article").toString(),
              "description": (a['summary'] ??
                      a['description'] ??
                      "No description available")
                  .toString(),
              "url": (a['url'] ?? "").toString(),
            };
          }).toList();

          if (parsed.isNotEmpty) return parsed;
        }
      }

      // ⚠️ API returned empty or bad data
      log("NEWS API: empty or invalid response — using fallback.");
      return _fallbackNews;
    } on FormatException catch (e) {
      log("NEWS API Format Error: $e");
      return _fallbackNews;
    } on http.ClientException catch (e) {
      log("NEWS API Client Error: $e");
      return _fallbackNews;
    } on Exception catch (e) {
      log("NEWS API Unknown Error: $e");
      return _fallbackNews;
    }
  }
}
