import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Device path: write to the temp dir and open the system share sheet.
Future<void> shareExportFile(
    Uint8List bytes, String filename, String mimeType) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: mimeType)],
  ));
}
