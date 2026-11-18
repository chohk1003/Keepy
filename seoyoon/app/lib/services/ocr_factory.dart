import 'ocr_service.dart';
import 'ocr_factory_stub.dart'
    if (dart.library.io) 'mlkit_ocr_service.dart' as platform;

/// 플랫폼에 맞는 OCR 구현. 웹 빌드에는 ML Kit 코드가 들어가지 않는다.
OcrService createOcrService() {
  final service = platform.createPlatformOcrService();
  return service.isSupported ? service : const UnsupportedOcrService();
}
