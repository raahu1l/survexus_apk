import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';

class ExportService {
  static Future<String> generateCSV() async {
    final responses =
        await FirebaseFirestore.instance.collection('responses').get();
    final buffer = StringBuffer();
    buffer.writeln("Survey ID, User ID, Answer Count, Date");

    for (var doc in responses.docs) {
      final data = doc.data();
      buffer.writeln(
          "${data['surveyId'] ?? ''},${data['userId'] ?? ''},${(data['responses'] as List?)?.length ?? 0},${data['respondedAt']}");
    }
    return buffer.toString();
  }

  static Future<pw.Document> generatePDF() async {
    final pdf = pw.Document();
    final responses =
        await FirebaseFirestore.instance.collection('responses').get();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("Survey Analytics Report")),
          pw.Table.fromTextArray(
            headers: ["Survey ID", "User ID", "Responses", "Date"],
            data: responses.docs.map((doc) {
              final data = doc.data();
              return [
                data['surveyId'] ?? '',
                data['userId'] ?? '',
                ((data['responses'] as List?)?.length ?? 0).toString(),
                data['respondedAt']?.toDate().toString() ?? ''
              ];
            }).toList(),
          )
        ],
      ),
    );

    return pdf;
  }
}
