import 'dart:convert';
import 'package:http/http.dart' as http;

const String backendUrl =
    'https://didactic-bassoon-vpq9vrv9jqrx2574-3000.app.github.dev';

class Api {
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$backendUrl/user/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'password': password,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al registrar');
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$backendUrl/user/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Credenciales inválidas');
    }
    return data;
  }

  static Future<Map<String, dynamic>> getHistory(String userId) async {
    final res = await http.get(
      Uri.parse('$backendUrl/user/$userId/transactions'),
    );
    if (res.statusCode != 200) {
      throw Exception('Error obteniendo historial');
    }
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> authorize({
    required String sessionId,
    required String token,
    required String userId,
    required String userName,
  }) async {
    final res = await http.post(
      Uri.parse('$backendUrl/authorize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessionId': sessionId,
        'token': token,
        'userId': userId,
        'userName': userName,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al autorizar');
    }
    return data;
  }
}