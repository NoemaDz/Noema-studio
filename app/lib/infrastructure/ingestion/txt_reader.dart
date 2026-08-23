import 'dart:io';
import '../../core/providers/document_ingestion_provider.dart';

class TxtReader implements DocumentIngestionProvider {
  @override
  String get id => 'txt_reader';

  @override
  String get name => 'TXT Reader';

  @override
  bool get available => true;
  @override
  List<String> get supportedExtensions => ['txt'];

  @override
  Future<String> readText(String filePath) async {
    final File file = File(filePath);
    if (!await file.exists()) {
      throw Exception("File not found: $filePath");
    }

    return await file.readAsString();
  }
}
