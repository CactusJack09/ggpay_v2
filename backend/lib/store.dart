import 'package:uuid/uuid.dart';
import 'transaction.dart';

class TransactionStore {
  static final TransactionStore _instance = TransactionStore._internal();
  factory TransactionStore() => _instance;
  TransactionStore._internal();

  final _uuid = const Uuid();
  final Map<String, Transaction> _transactions = {};

  static const Duration sessionValidity = Duration(minutes: 5);
  static const Duration tokenValidity = Duration(seconds: 10);

  Transaction create({
    required String stationId,
    required double amount,
    String currency = 'GTQ',
  }) {
    final now = DateTime.now();
    final tx = Transaction(
      id: _uuid.v4(),
      sessionId: _uuid.v4(),
      stationId: stationId,
      amount: amount,
      currency: currency,
      createdAt: now,
      expiresAt: now.add(sessionValidity),
      currentToken: _generateToken(),
      tokenExpiresAt: now.add(tokenValidity),
    );
    _transactions[tx.sessionId] = tx;
    return tx;
  }

  String _generateToken() => _uuid.v4().replaceAll('-', '');

  Transaction? get(String sessionId) => _transactions[sessionId];

  Transaction? getOrRotate(String sessionId) {
    final tx = _transactions[sessionId];
    if (tx == null) return null;
    if (tx.status != TransactionStatus.pending) return tx;

    final now = DateTime.now();
    if (now.isAfter(tx.expiresAt)) {
      tx.status = TransactionStatus.expired;
      return tx;
    }

    if (now.isAfter(tx.tokenExpiresAt)) {
      tx.currentToken = _generateToken();
      tx.tokenExpiresAt = now.add(tokenValidity);
    }
    return tx;
  }

  String? authorize(String sessionId, String token) {
    final tx = _transactions[sessionId];
    if (tx == null) return 'Transacción no encontrada';
    if (tx.status == TransactionStatus.completed) return 'Transacción ya usada';
    if (tx.status == TransactionStatus.authorized) return 'Ya autorizada';
    if (tx.status == TransactionStatus.expired) return 'QR expirado';

    final now = DateTime.now();
    if (now.isAfter(tx.expiresAt)) {
      tx.status = TransactionStatus.expired;
      return 'QR expirado';
    }
    if (now.isAfter(tx.tokenExpiresAt)) return 'Token vencido';
    if (tx.currentToken != token) return 'Token desactualizado';

    tx.authCode = _uuid.v4().substring(0, 8).toUpperCase();
    tx.status = TransactionStatus.authorized;
    return null;
  }

  void complete(String sessionId) {
    final tx = _transactions[sessionId];
    if (tx != null) tx.status = TransactionStatus.completed;
  }
}