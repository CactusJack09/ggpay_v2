import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://didactic-bassoon-vpq9vrv9jqrx2574-3000.app.github.dev';

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
}