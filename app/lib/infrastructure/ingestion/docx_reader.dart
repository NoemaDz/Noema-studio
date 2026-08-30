import 'dart:io';
import 'package:archive/archive.dart';
import '../../core/providers/document_ingestion_provider.dart';
import '../../core/capabilities/capability.dart';

class DocxReader extends DocumentIngestionProvider {
  @override
  String get id => 'docx_reader';

  @override
  String get name => 'DOCX Reader';

  @override
  bool get available => true;

  @override
  Set<CapabilityType> get capabilities => {};

  @override
  HardwareRequirements get hardwareRequirements => const HardwareRequirements();
  @override
  List<String> get supportedExtensions => ['docx'];

  @override
  Future<String> readText(String filePath) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File not found: $filePath");
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // In a DOCX file, the text is inside word/document.xml
    for (final archiveFile in archive) {
      if (archiveFile.name == 'word/document.xml') {
        final content = archiveFile.content as List<int>;
        final xmlString = String.fromCharCodes(content);
        return _stripXmlTags(xmlString);
      }
    }

    return "";
  }

  String _stripXmlTags(String xmlString) {
    // Very basic XML tag stripping, prioritizing paragraph separation
    // <w:p> indicates a paragraph in Word ML
    var text = xmlString.replaceAll(RegExp(r'<w:p[^\>]*>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Clean up excessive newlines
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
