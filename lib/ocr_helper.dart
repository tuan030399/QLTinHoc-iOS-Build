import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:qltinhoc/gemini_service.dart';

// --- BỎ "const" Ở ĐÂY ---
const String OCR_RESULT_DATA = 'data';
const String OCR_RESULT_METHOD = 'method';

class OcrHelper {
  static Future<Map<String, dynamic>> pickAndScanImage() async {
    try {
      final imageFile = await _pickImageFromCamera();
      if (imageFile == null) return {};

      print("Đang thử phân tích bằng Gemini AI...");
      final aiResult = await GeminiService.analyzeImageFile(imageFile);
      
      if (aiResult.isNotEmpty) {
        print("Gemini AI phân tích thành công!");
        return { OCR_RESULT_DATA: aiResult, OCR_RESULT_METHOD: 'Gemini AI (Online)', };
      }

      print("Gemini AI thất bại, chuyển sang OCR offline...");
      final fallbackResult = await _scanTextOffline(imageFile);
      
      return { OCR_RESULT_DATA: fallbackResult, OCR_RESULT_METHOD: 'ML Kit (Offline)', };

    } catch (e) {
      print("Lỗi trong OcrHelper: $e");
      return {};
    }
  }

  static Future<File?> _pickImageFromCamera() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage( source: ImageSource.camera, imageQuality: 80, );
    if (pickedFile == null) return null;
    return File(pickedFile.path); // Giữ nguyên cách chuyển đổi này
  }

  static Future<Map<String, String>> _scanTextOffline(File imageFile) async {
    // Sửa logic offline ở đây - xem Phần 2
    return {}; // Tạm thời để trống
  }


}