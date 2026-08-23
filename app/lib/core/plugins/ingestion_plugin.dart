import 'plugin_interface.dart';
import 'plugin_context.dart';

import '../../infrastructure/ingestion/pdf_reader.dart';
import '../../infrastructure/ingestion/txt_reader.dart';
import '../../infrastructure/ingestion/docx_reader.dart';

class IngestionPlugin implements IPlugin {
  @override
  String get name => 'Document Ingestion';

  @override
  String get version => '1.0.0';

  @override
  void register(PluginContext context) {
    context.providers.register(PdfReader());
    context.providers.register(TxtReader());
    context.providers.register(DocxReader());
  }
}
