import 'package:flutter/services.dart';

/// Downloads an image from [url] (a public avatar URL or a signed storage URL)
/// so it can be framed again.
Future<Uint8List> fetchImageBytes(String url) async {
  final data = await NetworkAssetBundle(Uri.parse(url)).load(url);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
