import 'dart:typed_data';

Future<void> saveBytesToPath(String path, Uint8List bytes) async {
  throw UnsupportedError(
      'Direct file writing is not available on this platform.');
}
