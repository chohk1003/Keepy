import 'dart:io';

Future<void> deleteFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // 이미 지워졌거나 접근할 수 없는 임시 파일 — 무시한다.
  }
}
