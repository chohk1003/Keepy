import 'image_cleanup_stub.dart' if (dart.library.io) 'image_cleanup_io.dart' as impl;

/// 촬영 원본을 인식 직후 지운다 (NFR-05: 이미지 미저장).
Future<void> deleteCapturedImage(String path) => impl.deleteFile(path);
