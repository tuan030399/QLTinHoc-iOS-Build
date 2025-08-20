import 'package:flutter/material.dart';
import 'package:qltinhoc/google_sheets_api.dart';
import 'package:qltinhoc/ocr_helper.dart' as ocr;

class JobScreen extends StatefulWidget {
  final Map<String, String>? job;
  final VoidCallback onSave;
  final List<String> userList; // <-- THÊM
  final List<String> sellerList; // <-- THÊM

  const JobScreen({
    super.key,
    this.job,
    required this.onSave,
    this.userList = const [], // <-- THÊM
    this.sellerList = const [], // <-- THÊM
  });

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;
  bool _isOcrLoading = false;

  // State cho dropdown
  String? _selectedNguoiLam;
  String? _selectedNguoiBan;

  // State cho AI suggestion
  String? _aiSuggestion;
  bool _isAiLoading = false;

  // Cấu hình các trường dữ liệu
  final List<Map<String, String>> _fieldConfigs = [
    {'key': 'ma_phieu', 'label': 'Mã Phiếu', 'type': 'text'},
    {'key': 'ten_kh', 'label': 'Tên Khách Hàng', 'type': 'text'},
    {'key': 'dien_thoai', 'label': 'Điện Thoại', 'type': 'phone'},
    {'key': 'nguoi_lam', 'label': 'Người Làm', 'type': 'dropdown_user'},
    {'key': 'nguoi_ban', 'label': 'Người Bán', 'type': 'dropdown_seller'},
    {'key': 'diem_rap', 'label': 'Điểm Ráp', 'type': 'number'},
    {'key': 'diem_cai', 'label': 'Điểm Cài', 'type': 'number'},
    {'key': 'diem_test', 'label': 'Điểm Test', 'type': 'number'},
    {'key': 'diem_ve_sinh', 'label': 'Điểm Vệ Sinh', 'type': 'number'},
    {'key': 'diem_nc_pc', 'label': 'Điểm NC PC', 'type': 'number'},
    {'key': 'diem_nc_laptop', 'label': 'Điểm NC Laptop', 'type': 'number'},
    {'key': 'ghi_chu', 'label': 'Ghi Chú', 'type': 'multiline'},
  ];

  @override
  void initState() {
    super.initState();
    
    // Tạo các controller cho trường text
    for (var config in _fieldConfigs) {
      final key = config['key']!;
      final type = config['type']!;
      if (type != 'dropdown_user' && type != 'dropdown_seller') {
         _controllers[key] = TextEditingController(text: widget.job?[key] ?? '');
      }
    }
    
    // Khởi tạo giá trị ban đầu cho Dropdown
    _selectedNguoiLam = widget.job?['nguoi_lam'];
    _selectedNguoiBan = widget.job?['nguoi_ban'];
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _scanWithOcr() async {
  setState(() { _isOcrLoading = true; });

  // Lưu lại context một cách an toàn
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  // Gọi hàm quét ảnh
  final result = await ocr.OcrHelper.pickAndScanImage();

  if (result.isNotEmpty && mounted) {
    final data = result[ocr.OCR_RESULT_DATA] as Map<String, String>;
    final method = result[ocr.OCR_RESULT_METHOD] as String;
    
    setState(() {
      _controllers['ma_phieu']?.text = data['ma_phieu'] ?? '';
      _controllers['ten_kh']?.text = data['ten_kh'] ?? '';
      _controllers['dien_thoai']?.text = data['dien_thoai'] ?? '';
    });

    // Hiển thị thông báo về phương pháp đã dùng
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Đã quét thành công bằng: $method'),
        backgroundColor: Colors.green, // Màu xanh cho thành công
      ),
    );
  
  } else if (mounted) {
    // Thông báo nếu quét thất bại
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Không thể nhận dạng được thông tin từ ảnh.'),
        backgroundColor: Colors.orange, // Màu cam cho cảnh báo
      ),
    );
  }

  // Đảm bảo loading được tắt dù thành công hay thất bại
  if(mounted) {
    setState(() { _isOcrLoading = false; });
  }
}

// Hàm tạo AI suggestion cho ghi chú
Future<void> _generateAiSuggestion() async {
  setState(() { _isAiLoading = true; });

  try {
    // Gọi AI để tạo suggestion (giả lập)
    // Trong thực tế, bạn sẽ gọi API Gemini ở đây
    await Future.delayed(const Duration(seconds: 2)); // Giả lập thời gian xử lý

    final customerName = _controllers['ten_kh']?.text ?? '';
    final phone = _controllers['dien_thoai']?.text ?? '';
    final suggestion = '''Diễn Giải: Máy tính của khách hàng $customerName (SĐT: $phone) được tiếp nhận với tình trạng chạy chậm, có nhiều phần mềm không cần thiết. Sau khi kiểm tra và thực hiện các bước sửa chữa cơ bản, máy đã hoạt động ổn định trở lại. Khuyến nghị khách hàng thường xuyên bảo trì định kỳ để đảm bảo hiệu suất tối ưu.''';

    if (mounted) {
      setState(() {
        _aiSuggestion = suggestion;
        _isAiLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() { _isAiLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tạo gợi ý AI. Vui lòng thử lại.')),
      );
    }
  }
}

// Hàm áp dụng AI suggestion vào ô ghi chú
void _applyAiSuggestion() {
  if (_aiSuggestion != null) {
    _controllers['ghi_chu']?.text = _aiSuggestion!;
    setState(() {
      _aiSuggestion = null; // Xóa suggestion sau khi áp dụng
    });
  }
}

// Hàm check thông tin liên quan từ Notes
Future<List<Map<String, String>>> _checkRelatedNotes() async {
  final phone = _controllers['dien_thoai']?.text.trim() ?? '';
  final customerName = _controllers['ten_kh']?.text.trim() ?? '';

  if (phone.isEmpty && customerName.isEmpty) return [];

  final allNotes = await GoogleSheetsApi.getAllNotes();
  // Tìm Notes liên quan từ Google Sheets
  // Kiểm tra Notes từ tab Notes trong Google Sheets
  final duplicateNotes = allNotes.where((note) {
    final notePhone = note['dien_thoai'] ?? '';
    final noteName = note['ten_kh'] ?? '';

    // Đếm số điều kiện trùng khớp (phải trùng 100%, không phân biệt hoa thường)
    int matchCount = 0;

    // Kiểm tra tên khách hàng (trùng 100%)
    if (customerName.isNotEmpty && noteName.isNotEmpty) {
      if (customerName.toLowerCase() == noteName.toLowerCase()) {
        matchCount++;
      }
    }

    // Kiểm tra số điện thoại (trùng 100%)
    if (phone.isNotEmpty && notePhone.isNotEmpty) {
      if (phone.toLowerCase() == notePhone.toLowerCase()) {
        matchCount++;
      }
    }

    // Tìm thấy Notes liên quan

    // Với Notes, chỉ cần 1 trong 2 điều kiện trùng khớp (vì Notes không có mã phiếu)
    return matchCount >= 1;
  }).toList();

  return duplicateNotes;
}

// Hàm check trùng lặp với Jobs đã có
Future<List<Map<String, String>>> _checkDuplicateJobs() async {
  final phone = _controllers['dien_thoai']?.text.trim() ?? '';
  final customerName = _controllers['ten_kh']?.text.trim() ?? '';
  final maPhieu = _controllers['ma_phieu']?.text.trim() ?? '';

  if (phone.isEmpty && customerName.isEmpty && maPhieu.isEmpty) return [];

  final allJobs = await GoogleSheetsApi.getAllJobs();
  final duplicateJobs = allJobs.where((job) {
    final jobPhone = job['dien_thoai'] ?? '';
    final jobName = job['ten_kh'] ?? '';
    final jobMaPhieu = job['ma_phieu'] ?? '';

    // Bỏ qua job hiện tại nếu đang edit
    if (widget.job != null && job['id'] == widget.job!['id']) {
      return false;
    }

    // Đếm số điều kiện trùng khớp (phải trùng 100%, không phân biệt hoa thường)
    int matchCount = 0;

    // Kiểm tra tên khách hàng (trùng 100%)
    if (customerName.isNotEmpty && jobName.isNotEmpty) {
      if (customerName.toLowerCase() == jobName.toLowerCase()) {
        matchCount++;
      }
    }

    // Kiểm tra số điện thoại (trùng 100%)
    if (phone.isNotEmpty && jobPhone.isNotEmpty) {
      if (phone.toLowerCase() == jobPhone.toLowerCase()) {
        matchCount++;
      }
    }

    // Kiểm tra mã phiếu (trùng 100%)
    if (maPhieu.isNotEmpty && jobMaPhieu.isNotEmpty) {
      if (maPhieu.toLowerCase() == jobMaPhieu.toLowerCase()) {
        matchCount++;
      }
    }

    // Cần đủ 2/3 điều kiện trùng khớp
    return matchCount >= 2;
  }).toList();

  return duplicateJobs;
}

// Hàm hiển thị dialog thông tin liên quan
Future<bool> _showInfoDialog(
  List<Map<String, String>> relatedNotes,
  List<Map<String, String>> duplicateJobs,
) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            relatedNotes.isNotEmpty && duplicateJobs.isNotEmpty
              ? Icons.info
              : duplicateJobs.isNotEmpty
                ? Icons.warning
                : Icons.info_outline,
            color: duplicateJobs.isNotEmpty ? Colors.orange : Colors.blue
          ),
          const SizedBox(width: 8),
          Text(duplicateJobs.isNotEmpty ? 'Phát hiện trùng lặp' : 'Thông tin tham khảo'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (relatedNotes.isNotEmpty) ...[
              const Text(
                'Thông tin liên quan từ Notes:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 8),
              ...relatedNotes.map((note) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${note['ten_kh']} - ${note['dien_thoai']}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💬 Ghi chú:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            note['noi_dung_note'] ?? 'Không có nội dung',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📅 ${note['ngay_tao_note']} - 👤 ${note['nguoi_tao_note']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],
            if (duplicateJobs.isNotEmpty) ...[
              const Text(
                'Đơn trùng khớp (≥2/3 điều kiện):',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 8),
              ...duplicateJobs.map((job) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎫 ${job['ma_phieu']} - ${job['ten_kh']}'),
                    Text('📞 ${job['dien_thoai']}'),
                    Text('📅 ${job['ngay_tao']}'),
                    Text('👤 ${job['nguoi_lam']}'),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(duplicateJobs.isNotEmpty ? 'Hủy' : 'Đóng'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: duplicateJobs.isNotEmpty ? Colors.orange : Colors.blue
          ),
          child: Text(duplicateJobs.isNotEmpty ? 'Vẫn tiếp tục' : 'Tiếp tục'),
        ),
      ],
    ),
  ) ?? false;
}

  Future<void> _saveJob() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final data = <String, String>{};
      // Lấy dữ liệu từ các ô text
      _controllers.forEach((key, controller) {
        data[key] = controller.text;
      });
      // Lấy dữ liệu từ các ô dropdown
      data['nguoi_lam'] = _selectedNguoiLam ?? '';
      data['nguoi_ban'] = _selectedNguoiBan ?? '';

      final pointFields = ['diem_rap', 'diem_cai', 'diem_test', 'diem_ve_sinh', 'diem_nc_pc', 'diem_nc_laptop'];
      for (var field in pointFields) {
          if (data[field] == null || data[field]!.isEmpty) {
              data[field] = '0';
          }
      }

      // Kiểm tra các trường bắt buộc
      if(data['nguoi_lam']!.isEmpty || data['ma_phieu']!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mã phiếu và Người làm là bắt buộc!')),
          );
          setState(() { _isLoading = false; });
          return;
      }

      // Check thông tin liên quan trước khi save (chỉ khi tạo mới)
      if (widget.job == null) {
        final relatedNotes = await _checkRelatedNotes();
        final duplicateJobs = await _checkDuplicateJobs();

        if (relatedNotes.isNotEmpty || duplicateJobs.isNotEmpty) {
          setState(() { _isLoading = false; });
          final shouldContinue = await _showInfoDialog(relatedNotes, duplicateJobs);
          if (!shouldContinue) return;
          setState(() { _isLoading = true; });
        }
      }

      bool success;
      if (widget.job != null) {
        success = await GoogleSheetsApi.updateJob(widget.job!['id']!, data);
      } else {
        success = await GoogleSheetsApi.addJob(data);
      }

      if (mounted) {
        setState(() { _isLoading = false; });
        if (success) {
            widget.onSave();
            Navigator.of(context).pop();
        } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lưu thất bại. Vui lòng thử lại.')),
            );
        }
      }
    }
  }
  
  // Widget xây dựng các widget đầu vào
  Widget _buildFormField(Map<String, String> config) {
    final key = config['key']!;
    final label = config['label']!;
    final type = config['type']!;

    switch(type) {
      case 'dropdown_user':
        final selectedValueExists = widget.userList.contains(_selectedNguoiLam);
        return DropdownButtonFormField<String>(
          value: selectedValueExists ? _selectedNguoiLam : null,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: widget.userList.map((user) => DropdownMenuItem(value: user, child: Text(user))).toList(),
          onChanged: (value) => setState(() => _selectedNguoiLam = value),
          validator: (value) {
            if (value == null || value.isEmpty) { return 'Người làm là bắt buộc'; }
            return null;
          },
        );
      
      case 'dropdown_seller':
        final selectedValueExists = widget.sellerList.contains(_selectedNguoiBan);
        return DropdownButtonFormField<String>(
          value: selectedValueExists ? _selectedNguoiBan : null,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: widget.sellerList.toSet().toList().map((seller) => DropdownMenuItem(value: seller, child: Text(seller))).toList(),
          onChanged: (value) => setState(() => _selectedNguoiBan = value),
        );

      case 'multiline':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _controllers[key],
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: _isAiLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                  onPressed: _isAiLoading ? null : _generateAiSuggestion,
                  tooltip: 'Tạo gợi ý AI',
                ),
              ),
              maxLines: 3,
            ),
            if (_aiSuggestion != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.blue.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Gợi ý AI:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiSuggestion!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _aiSuggestion = null),
                          child: const Text('Bỏ qua'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _applyAiSuggestion,
                          child: const Text('Áp dụng'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      
      case 'phone':
      case 'number':
        return TextFormField(
          controller: _controllers[key],
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          keyboardType: TextInputType.number,
        );

      default: // text
        return TextFormField(
          controller: _controllers[key],
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          keyboardType: TextInputType.text,
          validator: (value) {
            if (key == 'ma_phieu' && (value == null || value.isEmpty)) { return 'Mã phiếu là bắt buộc'; }
            return null;
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job != null ? 'Sửa Công Việc' : 'Thêm Công Việc Mới'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (widget.job == null)
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: (_isLoading || _isOcrLoading) ? null : _scanWithOcr,
              tooltip: 'Quét từ ảnh',
            ),
        ],
      ),
      body: _isLoading || _isOcrLoading
          ? Center(child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ const CircularProgressIndicator(), const SizedBox(height: 10), Text(_isOcrLoading ? 'Đang xử lý ảnh...' : 'Đang lưu...'), ],))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  ..._fieldConfigs.map((config) => Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildFormField(config),
                      )),
                  ElevatedButton(
                    onPressed: _saveJob,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: const Text('LƯU LẠI'),
                  ),
                ],
              ),
            ),
    );
  }
}