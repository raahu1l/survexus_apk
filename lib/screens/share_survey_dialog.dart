import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class ShareSurveyDialog extends StatelessWidget {
  final String surveyId;
  final String surveyTitle;

  const ShareSurveyDialog({
    super.key,
    required this.surveyId,
    required this.surveyTitle,
  });

  @override
  Widget build(BuildContext context) {
    final surveyLink = "https://survexus.app/respond/$surveyId";

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: const [
          Icon(Icons.share_rounded, color: Colors.indigo),
          SizedBox(width: 10),
          Text(
            "Share Survey",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Survey Title
            Text(
              surveyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 20),

            /// QR CODE
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: QrImageView(
                data: surveyLink,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            /// Link text
            SelectableText(
              surveyLink,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.indigo,
                decoration: TextDecoration.underline,
              ),
            ),

            const SizedBox(height: 25),

            /// SHARE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context); // Close dialog safely

                  await Share.share(
                    "📊 Survey Invitation: $surveyTitle\n\nRespond here:\n$surveyLink",
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text("Share Link"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// COPY LINK BUTTON (fixed snackbar bug)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: surveyLink));

                  // USE SAFE CONTEXT — DO NOT USE NAVIGATOR OVERLAY
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Link copied to clipboard!"),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, color: Colors.indigo),
                label: const Text(
                  "Copy Link",
                  style: TextStyle(color: Colors.indigo),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Close",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.indigo,
            ),
          ),
        ),
      ],
    );
  }
}
