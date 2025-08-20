import 'package:flutter/material.dart';
import 'package:qltinhoc/google_sheets_api.dart';

// Hàm helper để tạo message phù hợp
String _getDialogMessage(String action, String ownerName) {
  if (action.contains('xóa nhân viên')) {
    return 'Để $action "$ownerName", vui lòng nhập mật khẩu Admin hoặc mật khẩu của nhân viên "$ownerName".';
  } else {
    return 'Để $action công việc của "$ownerName", vui lòng nhập mật khẩu của bạn hoặc mật khẩu Admin.';
  }
}

// Hàm này sẽ hiển thị dialog và trả về true nếu pass đúng, false nếu sai/hủy
Future<bool> showPasswordDialog({
  required BuildContext context,
  required String ownerName, // Tên người sở hữu công việc
  required String action, // Hành động (ví dụ: "xóa", "sửa")
}) async {

  final passwordController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Yêu Cầu Xác Thực'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getDialogMessage(action, ownerName)),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              final enteredPassword = passwordController.text;
              if (enteredPassword.isEmpty) return;

              // Kiểm tra cả 2 loại mật khẩu
              final isAdmin = await GoogleSheetsApi.verifyAdminPassword(enteredPassword);
              if (isAdmin && context.mounted) {
                Navigator.of(context).pop(true);
                return;
              }

              final isUser = await GoogleSheetsApi.verifyUserPassword(ownerName, enteredPassword);
              if(isUser && context.mounted) {
                Navigator.of(context).pop(true);
                return;
              }

              // Nếu cả 2 đều sai
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mật khẩu không đúng!'), backgroundColor: Colors.red),
                );
                Navigator.of(context).pop(false);
              }
            },
            child: const Text('Xác Nhận'),
          ),
        ],
      );
    },
  );
  return result ?? false; // Trả về false nếu dialog bị đóng
}