import 'dart:convert';
import 'dart:math';

class User {
  final String id;
  final String fullName;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toJsonFull() => {
        ...toJson(),
        'passwordHash': passwordHash,
      };

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        email: j['email'] as String,
        passwordHash: j['passwordHash'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

String simpleHash(String input) {
  final bytes = utf8.encode(input);
  var hash = 0;
  for (final b in bytes) {
    hash = (hash * 31 + b) & 0x7fffffff;
  }
  final rnd = Random(hash);
  final salt = List.generate(8, (_) => rnd.nextInt(256));
  return base64Url.encode([...salt, ...bytes]);
}

bool verifyPassword(String input, String storedHash) {
  try {
    final decoded = base64Url.decode(storedHash);
    final passBytes = decoded.sublist(8);
    return String.fromCharCodes(passBytes) == input;
  } catch (_) {
    return false;
  }
}