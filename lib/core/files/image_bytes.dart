import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Downloads an image from [url] (a public avatar URL or a signed storage URL)
/// so it can be framed again.
Future<Uint8List> fetchImageBytes(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw http.ClientException(
      'Image download failed (${response.statusCode})',
      Uri.parse(url),
    );
  }
  return response.bodyBytes;
}
