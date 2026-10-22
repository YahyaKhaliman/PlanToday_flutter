import 'package:image_picker/image_picker.dart';

/// Helper utilitas untuk kompresi gambar di sisi Frontend (Flutter) sebelum dikirim ke server.
/// Membatasi resolusi dan kualitas gambar saat pengambilan agar ukuran file berkurang ke kisaran 100-300 KB (< 500 KB).
class ImageCompressHelper {
  static const double maxWidth = 1024;
  static const double maxHeight = 1024;
  static const int imageQuality = 70;
  static const int targetMaxSizeBytes = 500 * 1024; // 500 KB

  /// Memilih gambar dari kamera atau galeri dengan kompresi bawaan platform.
  static Future<XFile?> pickCompressedImage(
    ImagePicker picker, {
    required ImageSource source,
  }) async {
    return await picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }
}
