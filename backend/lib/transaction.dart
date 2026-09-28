enum TransactionStatus { pending, authorized, completed, expired, cancelled }

class Transaction {
  final String id;
  final String sessionId;
  final String stationId;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime expiresAt;
  TransactionStatus status;
  String? authCode;
  String currentToken;
  DateTime tokenExpiresAt;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'stationId': stationId,
        'amount': amount,
        'currency': currency,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'status': status.name,
        'authCode': authCode,
        'currentToken': currentToken,
        'tokenExpiresAt': tokenExpiresAt.toIso8601String(),
      };
}