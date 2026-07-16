import 'dart:typed_data';

import 'share_export_io.dart'
    if (dart.library.js_interop) 'share_export_web.dart' as impl;

typedef ExportHandler = Future<void> Function(
    Uint8List bytes, String filename, String mimeType);

/// Test seam: widget tests set this to capture exports instead of hitting
/// platform plugins (share sheet / browser download).
ExportHandler? debugExportHandler;

/// Hands the finished export to the platform: the system share sheet on
/// device (so it can go straight to WhatsApp/email), a browser download
/// on web.
Future<void> shareExportFile(
    Uint8List bytes, String filename, String mimeType) {
  final override = debugExportHandler;
  if (override != null) return override(bytes, filename, mimeType);
  return impl.shareExportFile(bytes, filename, mimeType);
}
