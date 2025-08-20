// Dòng này để import thư viện giao diện cơ bản của Flutter
import 'package:flutter/material.dart';
import 'package:qltinhoc/google_sheets_api.dart';
import 'package:qltinhoc/job_screen.dart';
import 'package:qltinhoc/user_management_screen.dart'; // <-- IMPORT MÀN HÌNH MỚI
import 'package:qltinhoc/password_dialog.dart';
import 'package:qltinhoc/settings_service.dart';
import 'package:qltinhoc/settings_screen.dart';
import 'package:qltinhoc/marquee_text.dart';
import 'package:qltinhoc/splash_screen.dart';
import 'package:intl/intl.dart';

// Đây là hàm "cửa ngõ", nơi ứng dụng bắt đầu chạy
void main() async { // <-- Chuyển thành async
  // Đảm bảo Flutter đã sẵn sàng trước khi chạy các tác vụ bất đồng bộ
  WidgetsFlutterBinding.ensureInitialized(); 
  await SettingsService.init();

  runApp(const MyApp());
}

// Đây là Widget (Tiện ích) gốc của toàn bộ ứng dụng của bạn
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp là một widget cung cấp rất nhiều thứ cơ bản cho ứng dụng
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Tắt cái banner "Debug"
      title: 'Quản Lý Công Việc',
      // theme dùng để định nghĩa màu sắc chung cho ứng dụng
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      // home chỉ định màn hình đầu tiên sẽ được hiển thị khi mở app
      home: const SplashScreen(),
    );
  }
}

// Đây là Widget màn hình chính của chúng ta
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // Danh sách công việc sẽ được tải từ Google Sheets
  List<Map<String, String>> _allJobs = [];
  List<Map<String, String>> _displayedJobs = [];
  bool _isLoading = true; // Biến để theo dõi trạng thái tải dữ liệu

  // State cho bộ lọc và tìm kiếm
  final _searchController = TextEditingController();
  String? _selectedUser;
  String? _selectedSeller;
  List<String> _userList = [];
  List<String> _sellerList = [];

  // Biến cho bộ lọc ngày tháng
  DateTime? _startDate;
  DateTime? _endDate;

  // Biến cho tổng điểm
  int _totalPoints = 0;


  @override
  void initState() {
    super.initState();
    _loadData(); // Gọi hàm tải dữ liệu khi màn hình được tạo
    _searchController.addListener(_filterJobs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Hàm để tải tất cả dữ liệu cần thiết
  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    final jobs = await GoogleSheetsApi.getAllJobs();
    final users = await GoogleSheetsApi.getUsers();
    final sellers = await GoogleSheetsApi.getSellers();
    if (mounted) {
      setState(() {
        _allJobs = jobs;
        _userList = users;
        _sellerList = sellers;
        _filterJobs(); // Áp dụng bộ lọc (ban đầu là không có)
        _isLoading = false;
      });
    }
  }

  // Hàm chuyển đổi Excel serial number thành DateTime
  DateTime? _parseExcelSerialNumber(String dateStr) {
    try {
      final serialNumber = double.parse(dateStr);
      // Excel epoch bắt đầu từ 1900-01-01, nhưng có bug leap year
      // Nên thực tế là 1899-12-30
      final excelEpoch = DateTime(1899, 12, 30);
      final days = serialNumber.floor();
      final timeFraction = serialNumber - days;
      final hours = (timeFraction * 24).floor();
      final minutes = ((timeFraction * 24 - hours) * 60).floor();
      final seconds = (((timeFraction * 24 - hours) * 60 - minutes) * 60).floor();

      return excelEpoch.add(Duration(
        days: days,
        hours: hours,
        minutes: minutes,
        seconds: seconds,
      ));
    } catch (e) {
      return null;
    }
  }

  // Hàm format ngày để hiển thị trong UI
  String _formatDateForDisplay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';

    final cleanDateStr = dateStr.trim();
    DateTime? parsedDate;

    // Thử parse Excel serial number
    if (RegExp(r'^\d+\.?\d*$').hasMatch(cleanDateStr)) {
      parsedDate = _parseExcelSerialNumber(cleanDateStr);
    }

    // Nếu không phải Excel serial, thử các format khác
    if (parsedDate == null) {
      final formats = [
        'dd/MM/yyyy HH:mm:ss', 'dd/MM/yyyy', 'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd',
        'MM/dd/yyyy HH:mm:ss', 'MM/dd/yyyy', 'dd-MM-yyyy HH:mm:ss', 'dd-MM-yyyy',
      ];

      for (final format in formats) {
        try {
          parsedDate = DateFormat(format).parse(cleanDateStr);
          break;
        } catch (e) {
          continue;
        }
      }
    }

    // Nếu parse được thì format lại, không thì hiển thị nguyên bản
    if (parsedDate != null) {
      return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
    } else {
      return cleanDateStr;
    }
  }

  // Hàm lọc và tìm kiếm trên danh sách đã tải
  void _filterJobs() {
    List<Map<String, String>> filteredList = List.from(_allJobs);

    // Lọc theo người làm
    if (_selectedUser != null) {
      filteredList = filteredList.where((job) => job['nguoi_lam'] == _selectedUser).toList();
    }

    // Lọc theo người bán
    if (_selectedSeller != null) {
      filteredList = filteredList.where((job) => job['nguoi_ban'] == _selectedSeller).toList();
    }

    // Lọc theo ngày tháng
    if (_startDate != null || _endDate != null) {
      filteredList = filteredList.where((job) {
        final dateStr = job['ngay_tao'];
        if (dateStr == null || dateStr.isEmpty) return false;

        try {
          // Làm sạch dữ liệu ngày (xóa khoảng trắng thừa)
          final cleanDateStr = dateStr.trim();

          DateTime? jobDate;

          // BƯỚC 1: Thử parse Excel serial number trước
          // Kiểm tra xem có phải là số không (Excel serial number)
          if (RegExp(r'^\d+\.?\d*$').hasMatch(cleanDateStr)) {
            jobDate = _parseExcelSerialNumber(cleanDateStr);
            // Excel serial number được chuyển đổi thành công
          }

          // BƯỚC 2: Nếu không phải Excel serial number, thử các format ngày thông thường
          if (jobDate == null) {
            final formats = [
              'dd/MM/yyyy HH:mm:ss',  // 16/08/2025 19:34:49
              'dd/MM/yyyy',           // 16/08/2025
              'yyyy-MM-dd HH:mm:ss',  // 2025-08-16 19:34:49
              'yyyy-MM-dd',           // 2025-08-16
              'MM/dd/yyyy HH:mm:ss',  // 08/16/2025 19:34:49 (US format)
              'MM/dd/yyyy',           // 08/16/2025
              'dd-MM-yyyy HH:mm:ss',  // 16-08-2025 19:34:49
              'dd-MM-yyyy',           // 16-08-2025
            ];

            // Thử parse với từng format
            for (final format in formats) {
              try {
                jobDate = DateFormat(format).parse(cleanDateStr);
                // Parse thành công với format này
                break; // Nếu parse thành công thì dừng
              } catch (e) {
                continue; // Thử format tiếp theo
              }
            }
          }

          // Nếu không parse được format nào
          if (jobDate == null) {
            // Không thể parse được ngày với bất kỳ format nào
            return false;
          }

          // Chỉ so sánh ngày, bỏ qua giờ
          final jobDateOnly = DateTime(jobDate.year, jobDate.month, jobDate.day);

          if (_startDate != null) {
            final startDateOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
            if (jobDateOnly.isBefore(startDateOnly)) {
              return false;
            }
          }

          if (_endDate != null) {
            final endDateOnly = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
            if (jobDateOnly.isAfter(endDateOnly)) {
              return false;
            }
          }

          return true;
        } catch (e) {
          return false; // Nếu có lỗi gì thì bỏ qua
        }
      }).toList();
    }

    // Lọc theo từ khóa tìm kiếm
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredList = filteredList.where((job) {
        return job.values.any((value) => value.toLowerCase().contains(searchQuery));
      }).toList();
    }

    // Tính tổng điểm
    int totalPoints = 0;
    for (final job in filteredList) {
      final rapStr = job['diem_rap'] ?? '0';
      final caiStr = job['diem_cai'] ?? '0';
      final testStr = job['diem_test'] ?? '0';
      final veSinhStr = job['diem_ve_sinh'] ?? '0';
      final ncPcStr = job['diem_nc_pc'] ?? '0';
      final ncLaptopStr = job['diem_nc_laptop'] ?? '0';

      totalPoints += (int.tryParse(rapStr) ?? 0);
      totalPoints += (int.tryParse(caiStr) ?? 0);
      totalPoints += (int.tryParse(testStr) ?? 0);
      totalPoints += (int.tryParse(veSinhStr) ?? 0);
      totalPoints += (int.tryParse(ncPcStr) ?? 0);
      totalPoints += (int.tryParse(ncLaptopStr) ?? 0);
    }

    setState(() {
      _displayedJobs = filteredList;
      _totalPoints = totalPoints;
    });
  }

  // Hàm hiển thị date picker
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterJobs(); // Gọi sau setState
    }
  }

  // Hàm xóa bộ lọc ngày
  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _filterJobs(); // Gọi sau setState
  }

  // Hàm hiển thị thông tin phiên bản
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Thông Tin Ứng Dụng'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quản Lý Công Việc',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Phiên bản: BETA APP_VERSION',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              '© 2025 Tin Học Ngôi Sao',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Phát triển bởi Tuấn Khỉ',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cảm ơn bạn đã sử dụng ứng dụng!',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // Hàm để tải lại dữ liệu từ sheet
  Future<void> _refreshData() async {
    await _loadData();
  }

  // Hàm hiển thị dialog xác nhận xóa
  Future<void> _showDeleteDialog(Map<String, String> job) async {
  final jobId = job['id'];
  final ownerName = job['nguoi_lam'];
  // Tạo biến an toàn
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  if (jobId == null || ownerName == null || ownerName.isEmpty) {
     scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Công việc không có người làm, không thể xóa.')),
    );
    return;
  }

  // BƯỚC 1: HỎI MẬT KHẨU TRƯỚC
  final passwordCorrect = await showPasswordDialog(
      context: context, ownerName: ownerName, action: 'xóa');

  // BƯỚC 2: NẾU PASS ĐÚNG MỚI HIỂN THỊ HỘP THOẠI XÁC NHẬN XÓA
  if (passwordCorrect) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác Nhận Xóa'),
        content:
            Text('Bạn chắc chắn muốn xóa vĩnh viễn công việc của "${job['ten_kh']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('XÓA')),

        ],
      ),
    );

    if (confirmed == true) {
      setState(() { _isLoading = true; });
      final success = await GoogleSheetsApi.deleteJob(jobId);
      if (success) {
        await _refreshData(); // Đảm bảo dùng await ở đây
      } else {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Xóa thất bại. Vui lòng thử lại.')));
        if(mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    // Scaffold là cấu trúc cơ bản của một màn hình (có appbar, body,...)
    return Scaffold(
      // AppBar là thanh tiêu đề màu xanh ở trên cùng
      appBar: AppBar(
        title: const Text('Danh Sách Công Việc'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [ // Thêm nút refresh
          IconButton(
        icon: const Icon(Icons.settings),
        tooltip: 'Cài đặt',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
          IconButton(
            icon: const Icon(Icons.manage_accounts), // Icon quản lý user
            tooltip: 'Quản lý nhân viên',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Thông tin ứng dụng',
            onPressed: _showAboutDialog,
          ),
        ],
      ),
      // body là phần thân chính của màn hình
      body: Column(
        children: [
          // KHUNG TÌM KIẾM VÀ BỘ LỌC
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Tìm kiếm...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildFilterDropdown(_userList, 'Người làm', _selectedUser, (val) => setState(() { _selectedUser = val; _filterJobs(); }))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFilterDropdown(_sellerList, 'Người bán', _selectedSeller, (val) => setState(() { _selectedSeller = val; _filterJobs(); }))),
                  ],
                ),
                const SizedBox(height: 8),
                // BỘ LỌC NGÀY THÁNG
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(_startDate != null && _endDate != null
                          ? '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                          : 'Chọn khoảng ngày'),
                      ),
                    ),
                    if (_startDate != null || _endDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _clearDateFilter,
                        icon: const Icon(Icons.clear),
                        tooltip: 'Xóa bộ lọc ngày',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // HIỂN THỊ TỔNG ĐIỂM
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng số công việc: ${_displayedJobs.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tổng điểm: $_totalPoints',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // DANH SÁCH CÔNG VIỆC
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayedJobs.isEmpty
                    ? const Center(child: Text('Không có công việc nào phù hợp.'))
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        child: ListView.builder(
                          itemCount: _displayedJobs.length,
                          itemBuilder: (context, index) {
                            final job = _displayedJobs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 3,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Colors.indigo.shade50],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.indigo.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        job['id'] ?? '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: MarqueeText(
                                    text: job['ten_kh'] ?? 'Không có tên',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.receipt, size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text('Mã: ${job['ma_phieu'] ?? 'N/A'}'),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text('Người làm: ${job['nguoi_lam'] ?? 'N/A'}'),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(_formatDateForDisplay(job['ngay_tao'])),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.indigo.shade400,
                                    size: 16,
                                  ),
                                onTap: () async {
  final ownerName = job['nguoi_lam'];
  
  // Tạo một bản sao an toàn của các biến cần thiết TRƯỚC KHI gọi await
  final BuildContext currentContext = context;
  final Function refreshCallback = _refreshData;
  final List<String> currentUserList = _userList;
  final List<String> currentSellerList = _sellerList;
  final Map<String, String> currentJob = job;

  if (ownerName == null || ownerName.isEmpty) {
    ScaffoldMessenger.of(currentContext).showSnackBar(
      const SnackBar(content: Text('Công việc không có người làm, không thể sửa.')),
    );
    return;
  }

  // Bước 1: Gọi dialog hỏi mật khẩu
  final passwordCorrect = await showPasswordDialog(
    context: currentContext, // Dùng context an toàn
    ownerName: ownerName,
    action: 'sửa',
  );

  // Bước 2: Nếu mật khẩu đúng và widget vẫn còn tồn tại (mounted)
  if (passwordCorrect && currentContext.mounted) {
    // Sử dụng các biến an toàn đã lưu từ trước
    Navigator.of(currentContext).push(
      MaterialPageRoute(
        builder: (_) => JobScreen(
          job: currentJob,
          onSave: () => refreshCallback(),
          userList: currentUserList,
          sellerList: currentSellerList,
        ),
      ),
    );
  }
},
                                onLongPress: () {
                                  _showDeleteDialog(job);
                                },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobScreen( // Mở màn hình thêm mới
          onSave: _refreshData,
          userList: _userList,     // TRUYỀN DANH SÁCH NGƯỜI LÀM
          sellerList: _sellerList, // TRUYỀN DANH SÁCH NGƯỜI BÁN
        ),
      ),
    );
  },
  backgroundColor: Colors.indigo,
  foregroundColor: Colors.white,
  child: const Icon(Icons.add),
),
    );
  }

  // Widget trợ giúp để tạo Dropdown
  Widget _buildFilterDropdown(List<String> items, String hint, String? selectedValue, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      value: selectedValue,
      hint: Text(hint),
      isExpanded: true,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Tất cả ${hint.toLowerCase()}'),
        ),
        ...items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}