import 'package:flutter/material.dart';
import 'package:qltinhoc/google_sheets_api.dart';
import 'package:qltinhoc/password_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<String> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() { _isLoading = true; });
    final users = await GoogleSheetsApi.getUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  // Hàm hiển thị dialog để thêm người dùng mới
  Future<void> _showAddUserDialog() async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm Nhân Viên Mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: "Nhập tên nhân viên",
                labelText: "Tên nhân viên",
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                hintText: "Nhập mật khẩu cho nhân viên",
                labelText: "Mật khẩu",
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final password = passwordController.text.trim();
              if (name.isNotEmpty && password.isNotEmpty) {
                Navigator.of(context).pop({
                  'name': name,
                  'password': password,
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập đầy đủ tên và mật khẩu!')),
                );
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() { _isLoading = true; });
      final success = await GoogleSheetsApi.addUserWithPassword(
        result['name']!,
        result['password']!,
      );
      if (success) {
        await _loadUsers(); // Tải lại danh sách
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã thêm nhân viên "${result['name']}" thành công!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Thêm thất bại hoặc "${result['name']}" đã tồn tại.')),
          );
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  // Hàm hiển thị dialog xác nhận xóa với xác thực mật khẩu
  Future<void> _showDeleteUserDialog(String name) async {
    // Import password_dialog để sử dụng
    final passwordVerified = await showPasswordDialog(
      context: context,
      ownerName: name,
      action: 'xóa nhân viên',
    );

    if (passwordVerified) {
      // Hiển thị dialog xác nhận cuối cùng
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác Nhận Xóa'),
          content: Text('Bạn có chắc chắn muốn xóa nhân viên "$name"?\n\nHành động này không thể hoàn tác.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() { _isLoading = true; });
        final success = await GoogleSheetsApi.deleteUser(name);
        if (success) {
          await _loadUsers();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã xóa nhân viên "$name" thành công!')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Xóa thất bại. Vui lòng thử lại.')),
            );
            setState(() { _isLoading = false; });
          }
        }
      }
    } else {
      // Mật khẩu không đúng hoặc người dùng hủy
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác thực thất bại. Không thể xóa nhân viên.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Hàm hiển thị dialog đổi mật khẩu nhân viên
  Future<void> _showChangePasswordDialog(String name) async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi Mật Khẩu - $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              decoration: const InputDecoration(
                hintText: "Nhập mật khẩu hiện tại hoặc mật khẩu Admin",
                labelText: "Mật khẩu hiện tại",
              ),
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                hintText: "Nhập mật khẩu mới",
                labelText: "Mật khẩu mới",
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                hintText: "Nhập lại mật khẩu mới",
                labelText: "Xác nhận mật khẩu mới",
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final oldPassword = oldPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin!')),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mật khẩu mới không khớp!')),
                );
                return;
              }

              // Kiểm tra mật khẩu cũ
              final isAdmin = await GoogleSheetsApi.verifyAdminPassword(oldPassword);
              final isUser = await GoogleSheetsApi.verifyUserPassword(name, oldPassword);

              if (isAdmin || isUser) {
                if (context.mounted) {
                  Navigator.of(context).pop({
                    'newPassword': newPassword,
                  });
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mật khẩu hiện tại không đúng!')),
                  );
                }
              }
            },
            child: const Text('Đổi Mật Khẩu'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() { _isLoading = true; });
      final success = await GoogleSheetsApi.updateUserPassword(name, result['newPassword']!);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã đổi mật khẩu cho "$name" thành công!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đổi mật khẩu thất bại. Vui lòng thử lại.')),
          );
        }
      }
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Nhân Viên'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(user),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.lock_reset, color: Colors.blue),
                          tooltip: 'Đổi mật khẩu',
                          onPressed: () {
                            _showChangePasswordDialog(user);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Xóa nhân viên',
                          onPressed: () {
                            _showDeleteUserDialog(user);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
