import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OcrResult {
  const OcrResult({required this.lines, required this.elapsedMilliseconds});

  final List<String> lines;
  final int elapsedMilliseconds;
}

/// Keeps image files inside the Android picker/cache lifecycle. Callers receive
/// text and timing only.
class AndroidOcrService {
  AndroidOcrService._();

  static final instance = AndroidOcrService._();
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const _cacheChannel = MethodChannel('keepy/ocr_cache');

  final _picker = ImagePicker();
  bool _busy = false;

  /// With no source, recover a picker result after Android recreates the app.
  Future<OcrResult?> read({ImageSource? source}) async {
    if (!isSupported || _busy) return null;
    _busy = true;
    _PickerCache? cache;
    Set<String>? previousPaths;
    final files = <XFile>[];
    try {
      final cachePath = await _cacheChannel.invokeMethod<String>('cachePath');
      if (cachePath == null || cachePath.isEmpty) {
        throw StateError('Android cache path is unavailable.');
      }
      cache = _PickerCache(Directory(cachePath));
      previousPaths = await cache.paths();
      if (source == null) {
        final recovered = await _picker.retrieveLostData();
        final recoveredFiles = recovered.files;
        if (recoveredFiles != null) files.addAll(recoveredFiles);
        final error = recovered.exception;
        if (error != null) throw error;
      } else {
        // Keep the original resolution and avoid an extra resized cache copy.
        final picked = await _picker.pickImage(
          source: source,
          requestFullMetadata: false,
        );
        if (picked != null) files.add(picked);
      }
      if (files.isEmpty) return null;
      return await _recognize(files.first.path);
    } finally {
      try {
        if (cache != null && previousPaths != null) {
          await cache.clean(previousPaths, files.map((file) => file.path));
        }
      } finally {
        _busy = false;
      }
    }
  }

  Future<OcrResult> _recognize(String path) async {
    // ML Kit's Korean model also recognizes Latin. One pass preserves mixed
    // lines and avoids duplicates from combining recognizer outputs.
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    final image = InputImage.fromFilePath(path);
    final stopwatch = Stopwatch()..start();
    try {
      final recognized = await recognizer.processImage(image);
      stopwatch.stop();
      final milliseconds = stopwatch.elapsedMilliseconds;
      debugPrint('Keepy OCR: ${milliseconds}ms');
      return OcrResult(
        lines: [
          for (final block in recognized.blocks)
            for (final line in block.lines) line.text,
        ],
        elapsedMilliseconds: milliseconds,
      );
    } finally {
      stopwatch.stop();
      await recognizer.close();
    }
  }
}

/// image_picker_android creates camera JPEGs as UUID + a numeric suffix and
/// gallery copies in UUID directories under the private app cache. A cancelled
/// camera intent can return no XFile even when its output file was created.
class _PickerCache {
  const _PickerCache(this.directory);

  final Directory directory;

  static const _uuid =
      '[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
      '[89ab][0-9a-f]{3}-[0-9a-f]{12}';
  static final _galleryDir = RegExp('^$_uuid\$');
  static final _cameraFile = RegExp('^$_uuid-?[0-9]+[.]jpg\$');

  Stream<FileSystemEntity> get _entries =>
      directory.list(followLinks: false).where((entry) {
        final name =
            entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
        return (entry is File && _cameraFile.hasMatch(name)) ||
            (entry is Directory && _galleryDir.hasMatch(name));
      });

  Future<Set<String>> paths() => _entries.map((entry) => entry.path).toSet();

  Future<void> clean(
    Set<String> previousPaths,
    Iterable<String> pickedPaths,
  ) async {
    final returned = pickedPaths.toSet();
    try {
      await for (final entry in _entries) {
        final fresh = !previousPaths.contains(entry.path);
        if (entry is File && (fresh || returned.contains(entry.path))) {
          await _delete(entry);
        } else if (entry is Directory) {
          var ownsDirectory = fresh;
          await for (final child in entry.list(followLinks: false)) {
            if (child is File && (fresh || returned.contains(child.path))) {
              ownsDirectory = true;
              await _delete(child);
            }
          }
          // Remove only an empty picker directory, never a directory tree.
          if (ownsDirectory &&
              !await entry.list(followLinks: false).any((_) => true)) {
            await _delete(entry);
          }
        }
      }
    } on FileSystemException {
      debugPrint('Keepy OCR: temporary image cleanup failed');
    }
  }

  Future<void> _delete(FileSystemEntity entry) async {
    try {
      await entry.delete();
    } on FileSystemException {
      debugPrint('Keepy OCR: temporary image cleanup failed');
    }
  }
}
