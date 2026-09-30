import 'package:uuid/uuid.dart';
import 'user.dart';

class UserStore {
  static final UserStore _instance = UserStore._internal();
  factory UserStore() => _instance;
  UserStore._internal();

  final _uuid = const Uuid();
  final Map<String, User> _users = {}; // id -> User
  final Map<String, String> _emailToId = {}; // email -> id

  User? findByEmail(String email) {
    final id = _emailToId[email.toLowerCase()];
    return id == null ? null : _users[id];
  }

  User? findById(String id) => _users[id];

  /// Devuelve el User creado, o null si el email ya existe
  User? register({
    required String fullName,
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.toLowerCase().trim();
    if (_emailToId.containsKey(normalizedEmail)) return null;

    final user = User(
      id: _uuid.v4(),
      fullName: fullName.trim(),
      email: normalizedEmail,
      passwordHash: simpleHash(password),
      createdAt: DateTime.now(),
    );
    _users[user.id] = user;
    _emailToId[normalizedEmail] = user.id;
    return user;
  }

  /// Devuelve el User si las credenciales son correctas, o null
  User? login({required String email, required String password}) {
    final user = findByEmail(email);
    if (user == null) return null;
    if (!verifyPassword(password, user.passwordHash)) return null;
    return user;
  }

  List<User> getAll() => _users.values.toList();
}