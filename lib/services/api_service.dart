import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://ggpay-backend.onrender.com',
  );

  Future<Map<String, dynamic>> createTransaction({
    required String stationId,
    required double amount,
    String currency = 'GTQ',
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/transaction'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'stationId': stationId,
            'amount': amount,
            'currency': currency,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Error creando transacción: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getQr(String sessionId) async {
    final res = await http
        .get(Uri.parse('$baseUrl/transaction/$sessionId/qr'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Error obteniendo QR: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getStatus(String sessionId) async {
    final res = await http
        .get(Uri.parse('$baseUrl/transaction/$sessionId/status'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Error obteniendo estado: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<void> complete(String sessionId) async {
    await http
        .post(Uri.parse('$baseUrl/transaction/$sessionId/complete'))
        .timeout(const Duration(seconds: 10));
  }

  Future<List<Map<String, dynamic>>> getHistory({
    String? userId,
    String? userName,
    String? stationId,
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, String>{};
    if (userId != null && userId.isNotEmpty) params['userId'] = userId;
    if (userName != null && userName.isNotEmpty) params['userName'] = userName;
    if (stationId != null && stationId.isNotEmpty) {
      params['stationId'] = stationId;
    }
    if (from != null) {
      params['from'] = from.toIso8601String().substring(0, 10);
    }
    if (to != null) {
      params['to'] = to.toIso8601String().substring(0, 10);
    }
    final uri = Uri.parse('$baseUrl/transactions')
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Error cargando historial: ${res.body}');
    }
    final data = jsonDecode(res.body);
    return (data['transactions'] as List).cast<Map<String, dynamic>>();
  }

  String buildExportUrl({
    String? userId,
    String? userName,
    String? stationId,
    DateTime? from,
    DateTime? to,
  }) {
    final params = <String, String>{};
    if (userId != null && userId.isNotEmpty) params['userId'] = userId;
    if (userName != null && userName.isNotEmpty) params['userName'] = userName;
    if (stationId != null && stationId.isNotEmpty) {
      params['stationId'] = stationId;
    }
    if (from != null) {
      params['from'] = from.toIso8601String().substring(0, 10);
    }
    if (to != null) {
      params['to'] = to.toIso8601String().substring(0, 10);
    }
    final uri = Uri.parse('$baseUrl/transactions/export.csv')
        .replace(queryParameters: params.isEmpty ? null : params);
    return uri.toString();
  }
}
