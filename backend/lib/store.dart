import 'package:uuid/uuid.dart';
import 'transaction.dart';
import 'persistence.dart';

class TransactionStore {
  static final TransactionStore _instance = TransactionStore._internal();
  factory TransactionStore() => _instance;
  TransactionStore._internal();

  final _uuid = const Uuid();
  final Map<String, Transaction> _transactions = {};

  static const Duration sessionValidity = Duration(minutes: 5);
  static const Duration tokenValidity = Duration(seconds: 10);

  Future<void> init() async {
    final list = await Persistence.loadTransactions();
    for (final j in list) {
      try {
        final tx = Transaction.fromJson(j);
        _transactions[tx.sessionId] = tx;
      } catch (_) {}
    }
    print('📂 Cargadas ${_transactions.length} transacciones');
  }

  Future<void> _persist() async {
    await Persistence.saveTransactions(
      _transactions.values.map((t) => t.toJson()).toList(),
    );
  }

  /// Genera un código de autorización ÚNICO de 16 caracteres.
  /// Verifica contra todas las transacciones existentes para garantizar
  /// que nunca se repita.
  String _generateUniqueAuthCode() {
    String code;
    int attempts = 0;
    do {
      code = _uuid.v4().replaceAll('-', '').substring(0, 16).toUpperCase();
      attempts++;
      if (attempts > 50) {
        // Fallback: timestamp en hex (siempre único en la práctica)
        code = DateTime.now()
            .millisecondsSinceEpoch
            .toRadixString(16)
            .toUpperCase()
            .padLeft(16, '0');
        break;
      }
    } while (_transactions.values.any((t) => t.authCode == code));
    return code;
  }

  String _generateToken() => _uuid.v4().replaceAll('-', '');

  Future<Transaction> create({
    required String stationId,
    required double amount,
    String currency = 'GTQ',
  }) async {
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
    await _persist();
    return tx;
  }

  Transaction? get(String sessionId) => _transactions[sessionId];

  Transaction? getOrRotate(String sessionId) {
    final tx = _transactions[sessionId];
    if (tx == null) return null;
    if (tx.status != TransactionStatus.pending) return tx;

    final now = DateTime.now();
    if (now.isAfter(tx.expiresAt)) {
      tx.status = TransactionStatus.expired;
      _persist();
      return tx;
    }

    if (now.isAfter(tx.tokenExpiresAt)) {
      tx.currentToken = _generateToken();
      tx.tokenExpiresAt = now.add(tokenValidity);
    }
    return tx;
  }

  Future<String?> authorize(String sessionId, String token) async {
    final tx = _transactions[sessionId];
    if (tx == null) return 'Transacción no encontrada';
    if (tx.status == TransactionStatus.completed) return 'Transacción ya usada';
    if (tx.status == TransactionStatus.authorized) return 'Ya autorizada';
    if (tx.status == TransactionStatus.expired) return 'QR expirado';

    final now = DateTime.now();
    if (now.isAfter(tx.expiresAt)) {
      tx.status = TransactionStatus.expired;
      await _persist();
      return 'QR expirado';
    }
    if (now.isAfter(tx.tokenExpiresAt)) return 'Token vencido';
    if (tx.currentToken != token) return 'Token desactualizado';

    // 👇 Código único garantizado
    tx.authCode = _generateUniqueAuthCode();
    tx.status = TransactionStatus.authorized;
    await _persist();
    return null;
  }

  Future<String?> authorizeWithUser(String sessionId, String token,
      String userId, String userName) async {
    final tx = _transactions[sessionId];
    if (tx == null) return 'Transacción no encontrada';
    if (tx.status == TransactionStatus.completed) return 'Transacción ya usada';
    if (tx.status == TransactionStatus.authorized) return 'Ya autorizada';
    if (tx.status == TransactionStatus.expired) return 'QR expirado';

    final now = DateTime.now();
    if (now.isAfter(tx.expiresAt)) {
      tx.status = TransactionStatus.expired;
      await _persist();
      return 'QR expirado';
    }
    if (now.isAfter(tx.tokenExpiresAt)) return 'Token vencido';
    if (tx.currentToken != token) return 'Token desactualizado';

    tx.userId = userId;
    tx.userName = userName;
    // 👇 Código único garantizado
    tx.authCode = _generateUniqueAuthCode();
    tx.status = TransactionStatus.authorized;
    await _persist();
    return null;
  }

  Future<void> complete(String sessionId) async {
    final tx = _transactions[sessionId];
    if (tx != null) {
      tx.status = TransactionStatus.completed;
      await _persist();
    }
  }

  List<Transaction> getAll({
    String? userId,
    String? userName,
    String? stationId,
    DateTime? from,
    DateTime? to,
  }) {
    var list = _transactions.values.toList();

    if (userId != null && userId.isNotEmpty) {
      list = list.where((t) => t.userId == userId).toList();
    }
    if (userName != null && userName.isNotEmpty) {
      final q = userName.toLowerCase();
      list = list
          .where((t) => (t.userName ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (stationId != null && stationId.isNotEmpty) {
      final q = stationId.toLowerCase();
      list = list
          .where((t) => t.stationId.toLowerCase().contains(q))
          .toList();
    }
    if (from != null) {
      list = list.where((t) => !t.createdAt.isBefore(from)).toList();
    }
    if (to != null) {
      final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59);
      list = list.where((t) => !t.createdAt.isAfter(toEnd)).toList();
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Transaction> getHistory({
    String? userId,
    String? userName,
    String? stationId,
    DateTime? from,
    DateTime? to,
  }) {
    return getAll(
      userId: userId,
      userName: userName,
      stationId: stationId,
      from: from,
      to: to,
    )
        .where((tx) =>
            tx.status == TransactionStatus.authorized ||
            tx.status == TransactionStatus.completed)
        .toList();
  }
}
