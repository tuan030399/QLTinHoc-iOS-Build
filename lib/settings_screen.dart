import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:qltinhoc/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _sheetIdController;
  late final TextEditingController _geminiKeyController;
  bool _isLoading = false;

  // Tab hiện tại (0: cách cũ, 1: config JSON mới)
  int _currentTab = 0;

  // Biến mới để quản lý thông tin file JSON
  String _jsonFileContent = '';
  String _jsonFileName = 'Chưa chọn file';

  // Biến cho config JSON mới
  String _configJsonContent = '';
  String _configJsonFileName = 'Chưa chọn file config';

  @override
  void initState() {
    super.initState();
    // Tải cài đặt hiện có vào các ô
    _sheetIdController = TextEditingController(text: SettingsService.sheetId);
    _geminiKeyController = TextEditingController(text: SettingsService.geminiKey);

    // Kiểm tra và hiển thị trạng thái của file JSON đã lưu
    _jsonFileContent = SettingsService.gsheetJson;
    if (_jsonFileContent.isNotEmpty) {
      _jsonFileName = 'credentials.json (đã có)';
    }

    // Kiểm tra xem có config JSON không
    _checkConfigJson();
  }

  // Kiểm tra config JSON
  Future<void> _checkConfigJson() async {
    final hasConfig = await SettingsService.hasConfigJson();
    if (hasConfig) {
      setState(() {
        _configJsonFileName = 'config.json (đã có)';
        _currentTab = 1; // Chuyển sang tab config JSON nếu đã có
      });
    }
  }

  @override
  void dispose() {
    _sheetIdController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  // Hàm chọn config JSON mới (tích hợp tất cả)
  Future<void> _pickConfigJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        // Validate JSON format
        try {
          final config = json.decode(content);

          // Kiểm tra các trường bắt buộc
          if (config['google_sheet_url'] == null) {
            throw Exception('Thiếu trường "google_sheet_url"');
          }

          // Kiểm tra service account credentials (hỗ trợ 2 cấu trúc)
          bool hasCredentials = false;

          if (config['google_service_account_credentials'] != null) {
            // Cấu trúc nested
            hasCredentials = true;
          } else if (config['type'] == 'service_account' &&
                     config['project_id'] != null &&
                     config['private_key'] != null &&
                     config['client_email'] != null) {
            // Cấu trúc flat
            hasCredentials = true;
          }

          if (!hasCredentials) {
            throw Exception('Thiếu thông tin service account credentials');
          }

          setState(() {
            _configJsonContent = content;
            _configJsonFileName = result.files.single.name;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã chọn file config JSON thành công!')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File JSON không hợp lệ: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chọn file: $e')),
        );
      }
    }
  }

  // Hàm xử lý việc chọn và đọc file (cách cũ)
  Future<void> _pickJsonFile() async {
    try {
      // Mở trình chọn file, chỉ cho phép chọn file có đuôi .json
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // Nếu người dùng chọn một file
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        
        // Đọc nội dung file dưới dạng chuỗi ký tự
        final fileContent = await file.readAsString();

        // Cập nhật giao diện để hiển thị tên file và lưu nội dung
        setState(() {
          _jsonFileContent = fileContent;
          _jsonFileName = result.files.single.name;
        });
      } else {
        // Người dùng đã hủy việc chọn file
        print('Hủy chọn file.');
      }
    } catch (e) {
      print("Lỗi khi chọn file: $e");
      // Hiển thị thông báo lỗi nếu có sự cố
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đọc file: $e')),
        );
      }
    }
  }
  
  // Hàm lưu config JSON mới
  Future<void> _saveConfigJson() async {
    if (_configJsonContent.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn file config JSON!')),
        );
      }
      return;
    }

    setState(() { _isLoading = true; });

    try {
      await SettingsService.saveConfigJson(_configJsonContent);

      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu cài đặt từ config JSON! Ứng dụng sẽ sử dụng cài đặt mới.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu config: $e')),
        );
      }
    }
  }

  // Hàm lưu tất cả cài đặt (cách cũ)
  Future<void> _save() async {
    // Kiểm tra xem người dùng đã chọn file JSON chưa (nếu trước đó chưa có)
    if (_jsonFileContent.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn file credentials.json!')),
        );
       return;
    }

    setState(() { _isLoading = true; });

    // Gọi service để lưu tất cả dữ liệu
    await SettingsService.saveSettings(
      newSheetId: _sheetIdController.text.trim(),
      newGeminiKey: _geminiKeyController.text.trim(),
      newGsheetJson: _jsonFileContent.trim(),
    );

    // Cần phải khởi tạo lại Google Sheets API với thông tin mới
    // GoogleSheetsApi.init(); // <- Tạm thời vô hiệu hóa, sẽ khởi tạo khi cần

    if (mounted) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cài đặt! Ứng dụng sẽ sử dụng cài đặt mới ở lần làm mới tiếp theo.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: _currentTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cài đặt & Cấu hình'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: Icon(Icons.settings),
                text: 'Cách cũ (3 bước)',
              ),
              Tab(
                icon: Icon(Icons.file_upload),
                text: 'Config JSON (1 file)',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Tab 1: Cách cũ
                  _buildOldConfigTab(),
                  // Tab 2: Config JSON mới
                  _buildNewConfigTab(),
                ],
              ),
      ),
    );
  }

  // Widget cho tab cách cũ
  Widget _buildOldConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
                TextField(
                  controller: _sheetIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID Google Sheet',
                    border: OutlineInputBorder(),
                    hintText: 'Dán ID sheet của bạn vào đây',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _geminiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key của Gemini',
                    border: OutlineInputBorder(),
                    hintText: 'Dán API key của Gemini vào đây',
                  ),
                ),
                const SizedBox(height: 20),

                // KHỐI CHỌN FILE JSON MỚI
                Text(
                  'File Google Credentials (.json)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Hiển thị tên file, có thể bị cắt nếu quá dài
                      Expanded(
                        child: Text(
                          _jsonFileName,
                          style: TextStyle(
                            color: _jsonFileName.startsWith('Chưa') ? Colors.red : Colors.green.shade800,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Nút bấm để mở trình chọn file
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open),
                        onPressed: _pickJsonFile,
                        label: const Text('Chọn File...'),
                      )
                    ],
                  ),
                ),
                // --- KẾT THÚC KHỐI MỚI ---
                
                const SizedBox(height: 32),
                // Nút Lưu Cài Đặt
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('LƯU CÀI ĐẶT'),
                ),
              ],
            );
  }

  // Widget cho tab config JSON mới
  Widget _buildNewConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Thông tin hướng dẫn
        Card(
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Cách mới - Chỉ cần 1 file duy nhất!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tạo file JSON với một trong hai cấu trúc sau:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),

                // Cấu trúc 1: Flat (đơn giản)
                Text(
                  '📄 Cấu trúc 1: Tất cả trong 1 level (Đơn giản)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: const Text(
                    '''{\n  "google_sheet_url": "https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID/edit",\n  "gemini_api_key": "YOUR_GEMINI_API_KEY",\n  "type": "service_account",\n  "project_id": "your-project",\n  "private_key": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n",\n  "client_email": "service@project.iam.gserviceaccount.com",\n  "client_id": "...",\n  "auth_uri": "https://accounts.google.com/o/oauth2/auth",\n  "token_uri": "https://oauth2.googleapis.com/token",\n  ...\n}''',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Cấu trúc 2: Nested
                Text(
                  '📁 Cấu trúc 2: Nested (Phân cấp)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: const Text(
                    '''{\n  "google_sheet_url": "https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID/edit",\n  "gemini_api_key": "YOUR_GEMINI_API_KEY",\n  "google_service_account_credentials": {\n    "type": "service_account",\n    "project_id": "your-project",\n    "private_key": "...",\n    "client_email": "...",\n    ...\n  }\n}''',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Chọn file config
        Text(
          'Chọn file config JSON',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _configJsonFileName,
                  style: TextStyle(
                    color: _configJsonFileName.startsWith('Chưa') ? Colors.red : Colors.green.shade800,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                onPressed: _pickConfigJson,
                label: const Text('Chọn File...'),
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Nút lưu
        ElevatedButton(
          onPressed: _saveConfigJson,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          child: const Text('LƯU CONFIG JSON'),
        ),
      ],
    );
  }
}