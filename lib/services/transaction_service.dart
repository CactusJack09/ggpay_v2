import 'package:uuid/uuid.dart';
import '../models/transaction.dart';

class TransactionService {
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  final _uuid = const Uuid();
  final Map<String, Transaction> _transactions = {};

  static const Duration sessionValidity = Duration(minutes: 5);
  static const Duration tokenValidity = Duration(seconds: 10);

  Transaction createTransaction({
    required String stationId,
    required double amount,
    String currency = 'GTQ',
  }) {
    final sessionId = _uuid.v4();
    final now = DateTime.now();
    final tx = Transaction(
      id: _uuid.v4(),
      sessionId: sessionId,
      stationId: stationId,
      amount: amount,
      currency: currency,
      createdAt: now,
      expiresAt: now.add(sessionValidity),
      currentToken: _generateToken(),
      tokenExpiresAt: now.add(tokenValidity),
    );
    _transactions[sessionId] = tx;
    return tx;
  }

  String _generateToken() => _uuid.v4().replaceAll('-', '');

  Transaction? rotateToken(String sessionId) {
    final tx = _transactions[sessionId];
    if (tx == null) return null;
    if (tx.status != TransactionStatus.pending) return tx;

    if (tx.isSessionExpired) {
      final expired = tx.copyWith(status: TransactionStatus.expired);
      _transactions[sessionId] = expired;
      return expired;
    }

    final rotated = tx.copyWith(
      currentToken: _generateToken(),
      tokenExpiresAt: DateTime.now().add(tokenValidity),
    );
    _transactions[sessionId] = rotated;
    return rotated;
  }

  String buildQrPayload(Transaction tx) {
    return 'spay://pay?session=${tx.sessionId}'
        '&station=${tx.stationId}'
        '&token=${tx.currentToken}';
  }

  String? authorizeTransaction(String qrPayload) {
    final uri = Uri.tryParse(qrPayload);
    if (uri == null || uri.scheme != 'spay' || uri.host != 'pay') {
      return 'QR no válido';
    }

    final sessionId = uri.queryParameters['session'];
    final token = uri.queryParameters['token'];
    if (sessionId == null || token == null) return 'QR inválido';

    final tx = _transactions[sessionId];
    if (tx == null) return 'Transacción no encontrada';
    if (tx.status == TransactionStatus.completed) return 'Transacción ya usada';
    if (tx.status == TransactionStatus.authorized) return 'Ya autorizada';
    if (tx.status == TransactionStatus.expired) return 'QR expirado';
    if (tx.isSessionExpired) {
      _transactions[sessionId] =
          tx.copyWith(status: TransactionStatus.expired);
      return 'QR expirado';
    }
    if (tx.isTokenExpired) return 'Token vencido, espera el siguiente';
    if (tx.currentToken != token) {
      return 'Token desactualizado. Escanea el QR actual.';
    }

    final authCode = _uuid.v4().substring(0, 8).toUpperCase();
    _transactions[sessionId] = tx.copyWith(
      status: TransactionStatus.authorized,
      authCode: authCode,
    );
    return null;
  }

  Transaction? getBySession(String sessionId) => _transactions[sessionId];

  void completeTransaction(String sessionId) {
    final tx = _transactions[sessionId];
    if (tx != null) {
      _transactions[sessionId] =
          tx.copyWith(status: TransactionStatus.completed);
    }
  }
}