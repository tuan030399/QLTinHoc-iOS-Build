import 'dart:io';
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

  // Biến mới để quản lý thông tin file JSON
  String _jsonFileContent = '';
  String _jsonFileName = 'Chưa chọn file';

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
  }

  @override
  void dispose() {
    _sheetIdController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  // Hàm xử lý việc chọn và đọc file
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
  
  // Hàm lưu tất cả cài đặt
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt & Cấu hình'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
            ),
    );
  }
}