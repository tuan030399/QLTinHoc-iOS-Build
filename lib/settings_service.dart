import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsService {
  // Các "khóa" để lưu trữ
  static const _configJsonKey = 'config_json'; // Key mới cho config tổng hợp
  static const _sheetIdKey = 'google_sheet_id'; // Legacy key
  static const _geminiApiKey = 'gemini_api_key'; // Legacy key
  static const _gSheetJsonKey = 'gsheet_credentials_json'; // Legacy key

  // Các biến tĩnh để truy cập nhanh từ mọi nơi trong ứng dụng
  static String sheetId = '';
  static String geminiKey = '';
  static String gsheetJson = '';

  // Hàm này phải được gọi khi ứng dụng khởi động
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Thử load từ config JSON mới trước
    final configJson = prefs.getString(_configJsonKey);
    if (configJson != null && configJson.isNotEmpty) {
      await _loadFromConfigJson(configJson);
      return;
    }

    // Fallback: Tải từ cách cũ (tương thích ngược)
    sheetId = prefs.getString(_sheetIdKey) ?? '';
    geminiKey = prefs.getString(_geminiApiKey) ?? '';
    gsheetJson = prefs.getString(_gSheetJsonKey) ?? '';

    print('Đã tải cài đặt: Sheet ID - $sheetId, Gemini Key - $geminiKey');
  }

  // Hàm load từ config JSON mới
  static Future<void> _loadFromConfigJson(String configJson) async {
    try {
      final config = json.decode(configJson);

      // Extract Google Sheet URL và chuyển thành Sheet ID
      final googleSheetUrl = config['google_sheet_url'] ?? '';
      sheetId = _extractSheetIdFromUrl(googleSheetUrl);

      // Extract Gemini API Key
      geminiKey = config['gemini_api_key'] ?? '';

      // Extract Google Service Account Credentials
      // Hỗ trợ 2 cấu trúc:
      // 1. Cấu trúc nested: {"google_service_account_credentials": {...}}
      // 2. Cấu trúc flat: {"type": "service_account", "project_id": "...", ...}

      Map<String, dynamic>? credentials;

      if (config['google_service_account_credentials'] != null) {
        // Cấu trúc nested
        credentials = config['google_service_account_credentials'];
      } else if (config['type'] == 'service_account') {
        // Cấu trúc flat - tạo credentials từ config hiện tại
        credentials = Map<String, dynamic>.from(config);
        // Loại bỏ các trường không phải của service account
        credentials.remove('google_sheet_url');
        credentials.remove('gemini_api_key');
      }

      if (credentials != null) {
        gsheetJson = json.encode(credentials);
      }

      print('Đã tải cài đặt từ config JSON: Sheet ID - $sheetId, Gemini Key - $geminiKey');
    } catch (e) {
      print('Lỗi khi parse config JSON: $e');
    }
  }

  // Hàm extract Sheet ID từ Google Sheet URL
  static String _extractSheetIdFromUrl(String url) {
    if (url.isEmpty) return '';

    // Pattern: https://docs.google.com/spreadsheets/d/SHEET_ID/edit
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? url; // Nếu không match, trả về nguyên bản
  }

  // Hàm lưu config JSON mới (phương thức chính)
  static Future<void> saveConfigJson(String configJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configJsonKey, configJson);

    // Load lại settings từ config mới
    await _loadFromConfigJson(configJson);

    print('Đã lưu config JSON mới!');
  }

  // Hàm để lưu cài đặt theo cách cũ (tương thích ngược)
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

    print('Đã lưu cài đặt theo cách cũ!');
  }

  // Hàm kiểm tra xem có config JSON không
  static Future<bool> hasConfigJson() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_configJsonKey);
    return configJson != null && configJson.isNotEmpty;
  }
}