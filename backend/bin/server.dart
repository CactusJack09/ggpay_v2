import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../lib/store.dart';
import '../lib/user_store.dart';

final _store = TransactionStore();
final _users = UserStore();

Middleware _cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization, X-Requested-With',
    'Access-Control-Max-Age': '86400',
  };
  return (inner) => (req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: headers);
        }
        final res = await inner(req);
        return res.change(headers: headers);
      };
}

Response _json(Object data, {int status = 200}) => Response(
      status,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );

Future<void> main() async {
  final router = Router()

    ..get('/health', (Request r) => _json({'status': 'ok'}))

    // ============================
    // USUARIOS
    // ============================

    ..post('/user/register', (Request req) async {
      final body = jsonDecode(await req.readAsString());
      final name = body['fullName'] as String?;
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      if (name == null || email == null || password == null) {
        return _json({'error': 'Faltan datos'}, status: 400);
      }
      final user = _users.register(
        fullName: name,
        email: email,
        password: password,
      );
      if (user == null) {
        return _json({'error': 'El email ya está registrado'}, status: 400);
      }
      return _json(user.toJson());
    })

    ..post('/user/login', (Request req) async {
      final body = jsonDecode(await req.readAsString());
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      if (email == null || password == null) {
        return _json({'error': 'Faltan datos'}, status: 400);
      }
      final user = _users.login(email: email, password: password);
      if (user == null) {
        return _json({'error': 'Credenciales inválidas'}, status: 401);
      }
      return _json(user.toJson());
    })

    ..get('/user/<id>/transactions', (Request req, String id) {
      final user = _users.findById(id);
      if (user == null) return _json({'error': 'No encontrado'}, status: 404);
      final history = _store.getHistory(userId: id);
      return _json({
        'user': user.toJson(),
        'transactions': history.map((t) => t.toJson()).toList(),
      });
    })

    // ============================
    // TRANSACCIONES
    // ============================

    ..post('/transaction', (Request req) async {
      final body = jsonDecode(await req.readAsString());
      final tx = _store.create(
        stationId: body['stationId'] ?? 'PUMP-01',
        amount: (body['amount'] as num).toDouble(),
        currency: body['currency'] ?? 'GTQ',
      );
      return _json({
        'sessionId': tx.sessionId,
        'amount': tx.amount,
        'currency': tx.currency,
        'stationId': tx.stationId,
        'expiresAt': tx.expiresAt.toIso8601String(),
      });
    })

    ..get('/transaction/<sessionId>/qr', (Request req, String sessionId) {
      final tx = _store.getOrRotate(sessionId);
      if (tx == null) return _json({'error': 'not found'}, status: 404);
      return _json({
        'sessionId': tx.sessionId,
        'token': tx.currentToken,
        'tokenExpiresAt': tx.tokenExpiresAt.toIso8601String(),
        'status': tx.status.name,
        'amount': tx.amount,
        'currency': tx.currency,
        'stationId': tx.stationId,
        'expiresAt': tx.expiresAt.toIso8601String(),
      });
    })

    ..get('/transaction/<sessionId>/status', (Request req, String sessionId) {
      final tx = _store.get(sessionId);
      if (tx == null) return _json({'error': 'not found'}, status: 404);
      return _json({
        'status': tx.status.name,
        'authCode': tx.authCode,
        'amount': tx.amount,
        'userName': tx.userName,
      });
    })

    // Autorizar (ahora acepta userId opcional)
    ..post('/authorize', (Request req) async {
      final body = jsonDecode(await req.readAsString());
      final sessionId = body['sessionId'] as String?;
      final token = body['token'] as String?;
      final userId = body['userId'] as String?;
      final userName = body['userName'] as String?;

      if (sessionId == null || token == null) {
        return _json({'error': 'Faltan datos'}, status: 400);
      }

      final error = userId != null
          ? _store.authorizeWithUser(
              sessionId, token, userId, userName ?? 'Anónimo')
          : _store.authorize(sessionId, token);

      if (error != null) return _json({'error': error}, status: 400);
      final tx = _store.get(sessionId)!;
      return _json({
        'status': 'authorized',
        'authCode': tx.authCode,
        'amount': tx.amount,
        'currency': tx.currency,
        'stationId': tx.stationId,
        'userName': tx.userName,
      });
    })

    ..post('/transaction/<sessionId>/complete',
        (Request req, String sessionId) {
      _store.complete(sessionId);
      return _json({'ok': true});
    })

    // Historial global (para la terminal web)
    ..get('/transactions', (Request req) {
      final history = _store.getHistory();
      return _json({
        'transactions': history.map((t) => t.toJson()).toList(),
      });
    });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 3000);
  print(
      '✅ Backend GGPay corriendo en http://${server.address.host}:${server.port}');
}