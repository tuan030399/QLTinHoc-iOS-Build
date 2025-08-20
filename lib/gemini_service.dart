import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:qltinhoc/settings_service.dart';

class GeminiService {

  // HÀM MỚI: Phân tích trực tiếp từ file ảnh
  static Future<Map<String, String>> analyzeImageFile(File imageFile) async {
    if (SettingsService.geminiKey.isEmpty) { 
    print('VUI LÒNG THÊM API KEY CỦA GEMINI VÀO PHẦN CÀI ĐẶT');
    return {};
    }

    try {
    final model = GenerativeModel(
        model: 'gemini-2.0-flash', 
        apiKey: SettingsService.geminiKey // Dùng API key động
);
      // 2. Đọc file ảnh thành dữ liệu bytes
      final imageBytes = await imageFile.readAsBytes();

      // 3. Tạo câu lệnh (prompt) để yêu cầu AI
      final prompt = TextPart(
  'Phân tích hình ảnh của một "PHIẾU XUẤT". '
  'Tìm và trích xuất các thông tin sau theo định dạng JSON chính xác: '
  '"ma_phieu": Đây là chuỗi ký tự và số ngay sau chữ "PHIẾU XUẤT", ví dụ "7BB507240498". '
  '"ten_kh": Đây là tên người ngay sau dòng chữ "Tên khách hàng:". '
  '"dien_thoai": Đây là chuỗi 10 chữ số. QUAN TRỌNG: Hãy lấy số điện thoại nằm ngay bên dưới "Tên khách hàng" hoặc bên cạnh chữ "Điện thoại:", không lấy các số khác ở các vị trí khác trên phiếu. '
  'Chỉ trả về duy nhất chuỗi JSON, không giải thích gì thêm.'
);
      
      // 4. Tạo phần dữ liệu hình ảnh
      final imagePart = DataPart('image/jpeg', imageBytes);

      // 5. Gửi cả câu lệnh và hình ảnh đến AI
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      // 6. Phân tích kết quả trả về
      return _parseGeminiResponse(response.text);

    } catch (e) {
      print('Lỗi Gemini AI khi phân tích ảnh: $e');
      return {};
    }
  }

  // HÀM HỖ TRỢ: Phân tích chuỗi JSON từ kết quả của AI
  static Map<String, String> _parseGeminiResponse(String? responseText) {
    if (responseText == null || responseText.isEmpty) {
      return {};
    }

    try {
      // Cố gắng tìm và trích xuất chuỗi JSON từ text trả về
      final jsonStringMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(responseText);
      if (jsonStringMatch == null) return {};

      final jsonString = jsonStringMatch.group(0)!;
      final decodedJson = json.decode(jsonString);

      if (decodedJson is Map<String, dynamic>) {
          // Chuyển đổi các giá trị thành String
          return decodedJson.map((key, value) => MapEntry(key, value.toString()));
      }

    } catch (e) {
       print('Lỗi khi phân tích JSON từ Gemini: $e');
    }

    return {};
  }
}