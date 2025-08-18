import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // Các "khóa" để lưu trữ, giúp tránh lỗi chính tả
  static const _sheetIdKey = 'google_sheet_id';
  static const _geminiApiKey = 'gemini_api_key';
  static const _gSheetJsonKey = 'gsheet_credentials_json';

  // Các biến tĩnh để truy cập nhanh từ mọi nơi trong ứng dụng
  static String sheetId = '';
  static String geminiKey = '';
  static String gsheetJson = '';

  // Hàm này phải được gọi khi ứng dụng khởi động
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Tải các giá trị đã lưu, nếu không có thì dùng giá trị rỗng
    sheetId = prefs.getString(_sheetIdKey) ?? '';
    geminiKey = prefs.getString(_geminiApiKey) ?? '';
    gsheetJson = prefs.getString(_gSheetJsonKey) ?? '';

    print('Đã tải cài đặt: Sheet ID - $sheetId, Gemini Key - $geminiKey');
  }

  // Hàm để lưu cài đặt mới
  static Future<void> saveSettings({
    required String newSheetId,
    required String newGeminiKey,
    required String newGsheetJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sheetIdKey, newSheetId);
    await prefs.setString(_geminiApiKey, newGeminiKey);
    await prefs.setString(_gSheetJsonKey, newGsheetJson);

    // Cập nhật ngay lập tức các biến tĩnh
    sheetId = newSheetId;
    geminiKey = newGeminiKey;

    print('Đã lưu cài đặt mới!');
  }
}