import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart'; // Import để định dạng ngày giờ
import 'dart:convert'; // Để mã hóa
import 'package:crypto/crypto.dart'; // Thư viện mã hóa
import 'package:qltinhoc/settings_service.dart';

class GoogleSheetsApi {
  // CREDENTIALS ĐÃ ĐƯỢC CHUYỂN VÀO SETTINGS SERVICE
  // Không cần hardcode credentials ở đây nữa


  // Thêm danh sách header để đảm bảo thứ tự cột là chính xác
  static const List<String> JOBS_HEADER = [
    'id', 'ma_phieu', 'ten_kh', 'dien_thoai', 'nguoi_lam', 'nguoi_ban', 
    'diem_rap', 'diem_cai', 'diem_test', 'diem_ve_sinh', 'diem_nc_pc', 
    'diem_nc_laptop', 'ghi_chu', 'ngay_tao'
  ];
  // Thêm header cho sheet Users
  static const List<String> USERS_HEADER = ['id', 'name', 'password', 'role'];
  // Thêm header cho sheet Notes (theo thứ tự thực tế: A, B, C, D, E, F, G, H)
  static const List<String> NOTES_HEADER = ['id', 'ngay_tao_note', 'ma_phieu', 'dien_thoai', 'ten_kh', 'noi_dung_note', 'nguoi_tao_note', 'trang_thai'];

  static GSheets? _gsheets;
  static Worksheet? _jobsWorksheet;
  static Worksheet? _usersWorksheet; // <-- Thêm worksheet cho Users
  static Worksheet? _settingsWorksheet;
  static Worksheet? _notesWorksheet; // <-- Thêm worksheet cho Notes

  // Hàm khởi tạo kết nối
  static Future<void> init() async {
  // Kiểm tra xem đã có ID và file JSON chưa
  if (SettingsService.sheetId.isEmpty || SettingsService.gsheetJson.isEmpty) {
      print('Chưa có ID Google Sheet hoặc file JSON credentials, bỏ qua khởi tạo.');
      _gsheets = null;
      return;
  }
  try {
      // DÙNG JSON TỪ BỘ NHỚ
      _gsheets = GSheets(SettingsService.gsheetJson);
      
      final ss = await _gsheets!.spreadsheet(SettingsService.sheetId);
      _jobsWorksheet = ss.worksheetByTitle('Jobs');
      _usersWorksheet = ss.worksheetByTitle('Users');
      _settingsWorksheet = ss.worksheetByTitle('Settings');
      _notesWorksheet = ss.worksheetByTitle('Notes');
  } catch (e) {
    print('Lỗi khởi tạo Google Sheets: $e');
    _gsheets = null;
  }
}

  // Hàm lấy danh sách công việc
  static Future<List<Map<String, String>>> getAllJobs() async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_jobsWorksheet == null) await init();
    if (_jobsWorksheet == null) return [];

    try {
      // Lấy tất cả các hàng dưới dạng danh sách các danh sách
      final allRows = await _jobsWorksheet!.values.allRows();
      if (allRows.length < 2) return []; // Không có dữ liệu nếu chỉ có header

      final headers = allRows.first; // Dòng đầu tiên là header
      final jobs = <Map<String, String>>[];

      // Bỏ qua dòng header (i=1)
      for (var i = 1; i < allRows.length; i++) {
        final row = allRows[i];
        final job = <String, String>{};
        for (var j = 0; j < headers.length; j++) {
          if (j < row.length) {
            job[headers[j]] = row[j];
          }
        }
        jobs.add(job);
      }
      
      // Sắp xếp theo ngày tạo (giả sử cột 'ngay_tao' tồn tại)
      // Phần này cần xử lý ngày tháng phức tạp hơn, tạm thời bỏ qua để đơn giản
      jobs.sort((a, b) => (b['id'] ?? '0').compareTo(a['id'] ?? '0'));

      return jobs;
    } catch (e) {
      print('Lỗi khi lấy dữ liệu công việc: $e');
      return [];
    }
  }

  // Hàm thêm công việc mới
  static Future<bool> addJob(Map<String, String> jobData) async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_jobsWorksheet == null) return false;

    try {
      // Lấy tất cả ID hiện có để tìm ra ID lớn nhất
      final idColumn = await _jobsWorksheet!.values.column(1, fromRow: 2);
      int maxId = 0;
      for (final idStr in idColumn) {
        final id = int.tryParse(idStr);
        if (id != null && id > maxId) {
          maxId = id;
        }
      }
      final newId = maxId + 1;

      final newJob = Map<String, dynamic>.from(jobData);
      newJob['id'] = newId.toString();
      newJob['ngay_tao'] = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
      // Đảm bảo các trường điểm số là số 0 nếu rỗng
      ['diem_rap', 'diem_cai', 'diem_test', 'diem_ve_sinh', 'diem_nc_pc', 'diem_nc_laptop'].forEach((key) {
        newJob.putIfAbsent(key, () => '0');
      });

      final newRow = JOBS_HEADER.map((header) => newJob[header]?.toString() ?? '').toList();

      return await _jobsWorksheet!.values.appendRow(newRow);
    } catch (e) {
      print('Lỗi khi thêm công việc: $e');
      return false;
    }
  }

  // Hàm cập nhật công việc
  static Future<bool> updateJob(String id, Map<String, String> jobData) async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_jobsWorksheet == null) return false;
    try {
      // Tìm hàng dựa trên ID
      // Tìm hàng dựa trên ID bằng cách tìm trong cột ID
      final idColumn = await _jobsWorksheet!.values.column(1, fromRow: 2);
      int? rowIndex;
      for (var i = 0; i < idColumn.length; i++) {
        if (idColumn[i] == id) {
          rowIndex = i + 2; // +2 vì fromRow:2 và index bắt đầu từ 0
          break;
        }
      }

      // Nếu không tìm thấy rowIndex, không thể cập nhật
      if (rowIndex == null) return false;

      // Lấy ngày tạo gốc để không bị ghi đè
      final originalDate = await _jobsWorksheet!.values.value(column: JOBS_HEADER.indexOf('ngay_tao') + 1, row: rowIndex);

      final updatedJob = Map<String, dynamic>.from(jobData);
      updatedJob['id'] = id;
      updatedJob['ngay_tao'] = originalDate;
      // Đảm bảo các trường điểm số là số 0 nếu rỗng
      ['diem_rap', 'diem_cai', 'diem_test', 'diem_ve_sinh', 'diem_nc_pc', 'diem_nc_laptop'].forEach((key) {
        updatedJob.putIfAbsent(key, () => '0');
      });

      final updatedRow = JOBS_HEADER.map((header) => updatedJob[header]?.toString() ?? '').toList();
      
      // Cập nhật toàn bộ hàng
      // Gói gsheets có lỗi khi cập nhật, nên ta xóa hàng cũ và thêm hàng mới
      await _jobsWorksheet!.deleteRow(rowIndex);
      return await _jobsWorksheet!.values.insertRow(rowIndex, updatedRow);
    } catch (e) {
      print('Lỗi khi cập nhật công việc: $e');
      return false;
    }
  }

  // Hàm mã hóa mật khẩu (giống hệt bên Python)
static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
}

// Kiểm tra mật khẩu Admin
static Future<bool> verifyAdminPassword(String passwordToCheck) async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_settingsWorksheet == null) await init();
    if (_settingsWorksheet == null) return false;
    try {
        // -- BẮT ĐẦU SỬA LỖI --
        // Lấy cột đầu tiên (chứa 'key') từ sheet Settings
        final keyColumn = await _settingsWorksheet!.values.column(1, fromRow: 2);
        for (var i = 0; i < keyColumn.length; i++) {
            if (keyColumn[i] == 'admin_password') {
                final rowIndex = i + 2; // +2 vì index từ 0 và bắt đầu từ hàng 2
                // Lấy mật khẩu đã mã hóa ở cột 2 cùng hàng
                final storedHashedPassword = await _settingsWorksheet!.values.value(column: 2, row: rowIndex);
                return storedHashedPassword == hashPassword(passwordToCheck);
            }
        }
        // -- KẾT THÚC SỬA LỖI --
        return false; // Không tìm thấy key 'admin_password'
    } catch(e) {
        print("Lỗi khi kiểm tra pass admin: $e");
        return false;
    }
}

// Kiểm tra mật khẩu của một user
static Future<bool> verifyUserPassword(String name, String passwordToCheck) async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_usersWorksheet == null) await init();
    if (_usersWorksheet == null) return false;
    try {
        // -- BẮT ĐẦU SỬA LỖI --
        final nameColumnIndex = USERS_HEADER.indexOf('name');
        final passwordColumnIndex = USERS_HEADER.indexOf('password');
        // Lấy tất cả các hàng từ sheet Users
        final allRows = await _usersWorksheet!.values.allRows(fromRow: 2);
        
        for (final row in allRows) {
            if (row.length > nameColumnIndex && row[nameColumnIndex] == name) {
                // Nếu tìm thấy đúng tên, lấy mật khẩu ở cột password
                if (row.length > passwordColumnIndex) {
                    final storedHashedPassword = row[passwordColumnIndex];
                    return storedHashedPassword.isNotEmpty && storedHashedPassword == hashPassword(passwordToCheck);
                }
                // Nếu tìm thấy tên nhưng không có cột password
                break;
            }
        }
        // -- KẾT THÚC SỬA LỖI --
        return false; // Không tìm thấy user hoặc password sai
    } catch(e) {
        print("Lỗi khi kiểm tra pass user: $e");
        return false;
    }
}

  // Hàm xóa công việc
  static Future<bool> deleteJob(String id) async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_jobsWorksheet == null) await init();
    if (_jobsWorksheet == null) return false;
    try {
      // Tìm hàng dựa trên ID bằng cách tìm trong cột ID
      final idColumn = await _jobsWorksheet!.values.column(1, fromRow: 2);
      int? rowIndex;
      for (var i = 0; i < idColumn.length; i++) {
        if (idColumn[i] == id) {
          rowIndex = i + 2; // +2 vì fromRow:2 và index bắt đầu từ 0
          break;
        }
      }
      // Gsheets package dùng index từ 1
      if (rowIndex != null) {
        return await _jobsWorksheet!.deleteRow(rowIndex);
      }
      return false;
    } catch (e) {
      print('Lỗi khi xóa công việc: $e');
      return false;
    }
  }

  // Lấy danh sách người làm duy nhất từ sheet Users
  static Future<List<String>> getUsers() async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_usersWorksheet == null) await init();
    if (_usersWorksheet == null) return [];
    try {
      // Lấy cột 'name' (cột thứ 2) từ sheet 'Users', bỏ qua header
      final users = await _usersWorksheet!.values.column(2, fromRow: 2); 
      return users.where((user) => user.isNotEmpty).toList()..sort();
    } catch (e) {
      print('Lỗi khi lấy danh sách người làm: $e');
      return [];
    }
  }

  // Lấy danh sách người bán duy nhất từ sheet Users
  static Future<List<String>> getSellers() async {
  if (_gsheets == null || _jobsWorksheet == null) await init();
  if (_usersWorksheet == null) await init();
  if (_usersWorksheet == null) return [];
  try {
    // SỬA Ở ĐÂY: Cột 'Người bán' của bạn là cột thứ 4 (D).
    // Chúng ta sẽ lấy tất cả giá trị từ cột 4, bỏ qua hàng tiêu đề (fromRow: 2)
    final sellers = await _usersWorksheet!.values.column(4, fromRow: 2);
    
    // Lọc ra các ô có dữ liệu (không lấy ô trống) và sắp xếp lại
    return sellers.where((seller) => seller.isNotEmpty).toList()..sort();
  } catch (e) {
    print('Lỗi khi lấy danh sách người bán: $e');
    return [];
  }
}

  // Hàm thêm người dùng mới vào sheet Users
  static Future<bool> addUser(String name) async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_usersWorksheet == null) await init();
    if (_usersWorksheet == null) return false;
    try {
      // Kiểm tra xem user đã tồn tại chưa
      final existingUsers = await getUsers();
      if (existingUsers.any((user) => user.toLowerCase() == name.toLowerCase())) {
        print('Người dùng đã tồn tại');
        return false;
      }

      // Lấy ID lớn nhất và +1
      final idColumn = await _usersWorksheet!.values.column(1, fromRow: 2);
      int maxId = 0;
      for (final idStr in idColumn) {
        final id = int.tryParse(idStr);
        if (id != null && id > maxId) {
          maxId = id;
        }
      }
      final newId = maxId + 1;

      // Thêm người dùng mới với id, name. Password và role để trống
      return await _usersWorksheet!.values.appendRow([newId.toString(), name, '', '']);
    } catch (e) {
      print('Lỗi khi thêm người dùng: $e');
      return false;
    }
  }

  // Hàm thêm người dùng mới với mật khẩu
  static Future<bool> addUserWithPassword(String name, String password) async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_usersWorksheet == null) await init();
    if (_usersWorksheet == null) return false;
    try {
      // Kiểm tra xem user đã tồn tại chưa
      final existingUsers = await getUsers();
      if (existingUsers.any((user) => user.toLowerCase() == name.toLowerCase())) {
        print('Người dùng đã tồn tại');
        return false;
      }

      // Lấy ID lớn nhất và +1
      final idColumn = await _usersWorksheet!.values.column(1, fromRow: 2);
      int maxId = 0;
      for (final idStr in idColumn) {
        final id = int.tryParse(idStr);
        if (id != null && id > maxId) {
          maxId = id;
        }
      }
      final newId = maxId + 1;

      // Mã hóa mật khẩu trước khi lưu
      final hashedPassword = hashPassword(password);

      // Thêm người dùng mới với id, name, password đã mã hóa, role để trống
      return await _usersWorksheet!.values.appendRow([newId.toString(), name, hashedPassword, '']);
    } catch (e) {
      print('Lỗi khi thêm người dùng: $e');
      return false;
    }
  }

  // Hàm cập nhật mật khẩu của người dùng
  static Future<bool> updateUserPassword(String name, String newPassword) async {
    if (_gsheets == null || _jobsWorksheet == null) await init();
    if (_usersWorksheet == null) await init();
    if (_usersWorksheet == null) return false;
    try {
      // Lấy tất cả các hàng từ sheet Users
      final allRows = await _usersWorksheet!.values.allRows(fromRow: 2);
      final nameColumnIndex = USERS_HEADER.indexOf('name');
      final passwordColumnIndex = USERS_HEADER.indexOf('password');

      // Tìm kiếm hàng có tên người dùng cần cập nhật
      for (var i = 0; i < allRows.length; i++) {
        if (allRows[i].length > nameColumnIndex && allRows[i][nameColumnIndex] == name) {
          // Nếu tìm thấy, cập nhật mật khẩu
          final rowIndex = i + 2; // +2 vì bắt đầu từ hàng 2 và index từ 0
          final hashedPassword = hashPassword(newPassword);
          return await _usersWorksheet!.values.insertValue(hashedPassword, column: passwordColumnIndex + 1, row: rowIndex);
        }
      }

      // Nếu không tìm thấy người dùng
      print('Không tìm thấy người dùng để cập nhật mật khẩu');
      return false;
    } catch (e) {
      print('Lỗi khi cập nhật mật khẩu: $e');
      return false;
    }
  }

  // Hàm xóa người dùng khỏi sheet Users
static Future<bool> deleteUser(String name) async {
  if (_gsheets == null || _jobsWorksheet == null) await init();
  if (_usersWorksheet == null) await init();
  if (_usersWorksheet == null) return false;
  try {
    // --- BẮT ĐẦU PHẦN SỬA LỖI ---
    // Lấy tất cả các hàng trong sheet Users, bắt đầu từ hàng 2 để bỏ qua header
    final allRows = await _usersWorksheet!.values.allRows(fromRow: 2);
    final nameColumnIndex = USERS_HEADER.indexOf('name');
    
    // Tìm kiếm hàng có tên người dùng cần xóa
    for (var i = 0; i < allRows.length; i++) {
        // Kiểm tra xem hàng có đủ cột không và tên có khớp không
        if (allRows[i].length > nameColumnIndex && allRows[i][nameColumnIndex] == name) {
            // Nếu tìm thấy, xóa hàng đó đi.
            // rowIndex = i + 2 (vì bắt đầu từ hàng 2 và index từ 0)
            return await _usersWorksheet!.deleteRow(i + 2);
        }
    }
    
    // Nếu không tìm thấy người dùng, trả về false
    print('Không tìm thấy người dùng để xóa');
    return false;
    // --- KẾT THÚC PHẦN SỬA LỖI ---
  } catch (e) {
    print('Lỗi khi xóa người dùng: $e');
    return false;
  }
}

  // ==================== NOTES API ====================

  // Lấy tất cả notes
  static Future<List<Map<String, String>>> getAllNotes() async {
    if (_gsheets == null || _notesWorksheet == null) await init();
    if (_notesWorksheet == null) return [];
    try {
      final allRows = await _notesWorksheet!.values.allRows(fromRow: 2);
      final notes = <Map<String, String>>[];

      for (final row in allRows) {
        final note = <String, String>{};
        for (int i = 0; i < NOTES_HEADER.length && i < row.length; i++) {
          note[NOTES_HEADER[i]] = row[i];
        }
        if (note['id']?.isNotEmpty == true) {
          notes.add(note);
        }
      }
      // Notes đã được load thành công
      return notes;
    } catch (e) {
      print('Lỗi khi lấy dữ liệu notes: $e');
      return [];
    }
  }

  // Tìm notes theo số điện thoại
  static Future<List<Map<String, String>>> getNotesByPhone(String phone) async {
    final allNotes = await getAllNotes();
    return allNotes.where((note) => note['dien_thoai'] == phone).toList();
  }

  // Tìm notes theo tên khách hàng (trùng 100%)
  static Future<List<Map<String, String>>> getNotesByCustomerName(String customerName) async {
    final allNotes = await getAllNotes();
    return allNotes.where((note) =>
      note['ten_kh']?.toLowerCase() == customerName.toLowerCase()
    ).toList();
  }

  // Thêm note mới
  static Future<bool> addNote({
    required String phone,
    required String customerName,
    required String content,
    required String creator,
    String status = 'active',
  }) async {
    if (_gsheets == null || _notesWorksheet == null) await init();
    if (_notesWorksheet == null) return false;
    try {
      // Lấy ID lớn nhất và +1
      final idColumn = await _notesWorksheet!.values.column(1, fromRow: 2);
      int maxId = 0;
      for (final idStr in idColumn) {
        final id = int.tryParse(idStr);
        if (id != null && id > maxId) {
          maxId = id;
        }
      }
      final newId = maxId + 1;

      final newNote = [
        newId.toString(),
        DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
        '', // ma_phieu - để trống
        phone,
        customerName,
        content,
        creator,
        status,
      ];

      return await _notesWorksheet!.values.appendRow(newNote);
    } catch (e) {
      print('Lỗi khi thêm note: $e');
      return false;
    }
  }
}