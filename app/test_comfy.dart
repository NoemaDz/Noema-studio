import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = "http://127.0.0.1:8188";
  
  try {
    final res = await http.get(Uri.parse(baseUrl));
    print("ComfyUI is running: \${res.statusCode}");
  } catch (e) {
    print("Cannot connect to ComfyUI: \$e");
  }
}
