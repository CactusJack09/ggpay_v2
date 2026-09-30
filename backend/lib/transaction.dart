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
  String? userId;
  String? userName;

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
    this.userId,
    this.userName,
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
        'userId': userId,
        'userName': userName,
      };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        sessionId: j['sessionId'] as String,
        stationId: j['stationId'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        status: TransactionStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => TransactionStatus.completed,
        ),
        authCode: j['authCode'] as String?,
        currentToken: j['currentToken'] as String? ?? '',
        tokenExpiresAt:
            DateTime.tryParse(j['tokenExpiresAt'] as String? ?? '') ??
                DateTime.now(),
        userId: j['userId'] as String?,
        userName: j['userName'] as String?,
      );
}