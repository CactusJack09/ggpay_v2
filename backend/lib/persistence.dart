import 'dart:convert';
import 'dart:io';

class Persistence {
  static const String _dir = 'data';
  static const String _txFile = '$_dir/transactions.json';
  static const String _usersFile = '$_dir/users.json';

  static Future<void> ensureDir() async {
    final d = Directory(_dir);
    if (!await d.exists()) await d.create(recursive: true);
  }

  static Future<List<Map<String, dynamic>>> loadTransactions() async {
    final f = File(_txFile);
    if (!await f.exists()) return [];
    try {
      final content = await f.readAsString();
      if (content.trim().isEmpty) return [];
      return (jsonDecode(content) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('⚠️ Error cargando transacciones: $e');
      return [];
    }
  }

  static Future<void> saveTransactions(List<Map<String, dynamic>> data) async {
    await ensureDir();
    await File(_txFile).writeAsString(jsonEncode(data));
  }

  static Future<List<Map<String, dynamic>>> loadUsers() async {
    final f = File(_usersFile);
    if (!await f.exists()) return [];
    try {
      final content = await f.readAsString();
      if (content.trim().isEmpty) return [];
      return (jsonDecode(content) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('⚠️ Error cargando usuarios: $e');
      return [];
    }
  }

  static Future<void> saveUsers(List<Map<String, dynamic>> data) async {
    await ensureDir();
    await File(_usersFile).writeAsString(jsonEncode(data));
  }
}