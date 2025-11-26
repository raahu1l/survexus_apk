import 'package:flutter/material.dart';
import '../services/api_service.dart'; // ✅ Adjust this path if needed

class NewsTab extends StatefulWidget {
  final VoidCallback onCreateSurvey;
  const NewsTab({required this.onCreateSurvey, super.key});

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  List articles = [];
  bool loading = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final result = await ApiService.fetchNews();
      if (result.isNotEmpty) {
        setState(() {
          articles = result;
          loading = false;
        });
      } else {
        setState(() {
          error = 'No news articles available.';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error fetching news: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FC),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create Survey'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              minimumSize: const Size(180, 44),
            ),
            onPressed: widget.onCreateSurvey,
          ),
          const SizedBox(height: 12),

          // Loading indicator
          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          // Error screen
          else if (error.isNotEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: _fetchNews,
                    ),
                  ],
                ),
              ),
            )
          // News list
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchNews,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  itemCount: articles.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, idx) {
                    final article = articles[idx];

                    final title = article['title'] ?? 'Untitled';
                    final description = article['description'] ??
                        article['content'] ??
                        'No details';
                    final url = article['url'] ??
                        article['readMoreUrl'] ??
                        'No source link available';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(title),
                            content: SingleChildScrollView(
                              child: Text('$description\n\n🔗 Source:\n$url'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
