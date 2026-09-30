import 'package:uuid/uuid.dart';
import 'user.dart';
import 'persistence.dart';

class UserStore {
  static final UserStore _instance = UserStore._internal();
  factory UserStore() => _instance;
  UserStore._internal();

  final _uuid = const Uuid();
  final Map<String, User> _users = {};
  final Map<String, String> _emailToId = {};

  Future<void> init() async {
    final list = await Persistence.loadUsers();
    for (final j in list) {
      try {
        final u = User.fromJson(j);
        _users[u.id] = u;
        _emailToId[u.email] = u.id;
      } catch (_) {}
    }
    print('📂 Cargados ${_users.length} usuarios');
  }

  Future<void> _persist() async {
    await Persistence.saveUsers(
      _users.values.map((u) => u.toJsonFull()).toList(),
    );
  }

  User? findByEmail(String email) {
    final id = _emailToId[email.toLowerCase()];
    return id == null ? null : _users[id];
  }

  User? findById(String id) => _users[id];

  Future<User?> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
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
    await _persist();
    return user;
  }

  User? login({required String email, required String password}) {
    final user = findByEmail(email);
    if (user == null) return null;
    if (!verifyPassword(password, user.passwordHash)) return null;
    return user;
  }

  List<User> getAll() => _users.values.toList();
}