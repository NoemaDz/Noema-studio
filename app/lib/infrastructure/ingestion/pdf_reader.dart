import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/providers/document_ingestion_provider.dart';

class PdfReader implements DocumentIngestionProvider {
  @override
  String get id => 'pdf_reader';

  @override
  String get name => 'PDF Reader';

  @override
  bool get available => true;
  @override
  List<String> get supportedExtensions => ['pdf'];

  @override
  Future<String> readText(String filePath) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File not found: $filePath");
    }

    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    print("PdfReader: Loaded document");
    final extractor = PdfTextExtractor(document);
    print("PdfReader: Extracting text...");
    final text = extractor.extractText();
    print("PdfReader: Text extracted, disposing document...");
    document.dispose();

    return text;
  }
}
