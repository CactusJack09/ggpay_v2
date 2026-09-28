enum TransactionStatus { pending, authorized, completed, expired, cancelled }

class Transaction {
  final String id;
  final String sessionId;
  final String stationId;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime expiresAt;
  final TransactionStatus status;
  final String? authCode;
  final String currentToken;
  final DateTime tokenExpiresAt;

  Transaction({
    required this.id,
    required this.sessionId,
    required this.stationId,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.expiresAt,
    required this.currentToken,
    required this.tokenExpiresAt,
    this.status = TransactionStatus.pending,
    this.authCode,
  });

  bool get isSessionExpired => DateTime.now().isAfter(expiresAt);
  bool get isTokenExpired => DateTime.now().isAfter(tokenExpiresAt);

  Transaction copyWith({
    TransactionStatus? status,
    String? authCode,
    String? currentToken,
    DateTime? tokenExpiresAt,
  }) {
    return Transaction(
      id: id,
      sessionId: sessionId,
      stationId: stationId,
      amount: amount,
      currency: currency,
      createdAt: createdAt,
      expiresAt: expiresAt,
      currentToken: currentToken ?? this.currentToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      status: status ?? this.status,
      authCode: authCode ?? this.authCode,
    );
  }
}