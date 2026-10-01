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

String _csvEscape(String? v) {
  if (v == null) return '';
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

List<Map<String, dynamic>> _applyFilters(Request req) {
  final q = req.url.queryParameters;
  DateTime? from;
  DateTime? to;
  if (q['from'] != null && q['from']!.isNotEmpty) {
    from = DateTime.tryParse(q['from']!);
  }
  if (q['to'] != null && q['to']!.isNotEmpty) {
    to = DateTime.tryParse(q['to']!);
  }
  final txs = _store.getHistory(
    userId: q['userId'],
    userName: q['userName'],
    stationId: q['stationId'],
    from: from,
    to: to,
  );
  return txs.map((t) => t.toJson()).toList();
}

Future<void> main() async {
  await _store.init();
  await _users.init();

  final router = Router()

    ..get('/health', (Request r) => _json({'status': 'ok'}))

    // ============ USUARIOS ============
    ..post('/user/register', (Request req) async {
      final body = jsonDecode(await req.readAsString());
      final name = body['fullName'] as String?;
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      if (name == null || email == null || password == null) {
        return _json({'error': 'Faltan datos'}, status: 400);
      }
      final user = await _users.register(
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

    ..get('/users', (Request req) {
      return _json({
        'users': _users.getAll().map((u) => u.toJson()).toList(),
      });
    })

    // ============ TRANSACCIONES ============
    ..post('/transaction', (Request req) async {
      final body = jsonDecode(await req.readAsString());
      final tx = await _store.create(
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
          ? await _store.authorizeWithUser(
              sessionId, token, userId, userName ?? 'Anónimo')
          : await _store.authorize(sessionId, token);

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
        (Request req, String sessionId) async {
      await _store.complete(sessionId);
      return _json({'ok': true});
    })

    ..get('/transactions', (Request req) {
      final txs = _applyFilters(req);
      return _json({'transactions': txs});
    })

    ..get('/transactions/export.csv', (Request req) {
      final txs = _applyFilters(req);
      final buf = StringBuffer();
      buf.writeln(
          'Fecha,Usuario ID,Nombre Usuario,Monto,Moneda,Estacion,Codigo Autorizacion,Estado');
      for (final t in txs) {
        final date =
            (t['createdAt'] as String).substring(0, 19).replaceAll('T', ' ');
        buf.writeln([
          date,
          _csvEscape(t['userId'] as String?),
          _csvEscape(t['userName'] as String?),
          t['amount'],
          t['currency'],
          _csvEscape(t['stationId'] as String?),
          _csvEscape(t['authCode'] as String?),
          t['status'],
        ].join(','));
      }

      // 👇 Genera nombre del archivo con fecha del día
      final now = DateTime.now();
      final dia = now.day.toString().padLeft(2, '0');
      final mes = now.month.toString().padLeft(2, '0');
      final anio = now.year;
      final hora = now.hour.toString().padLeft(2, '0');
      final min = now.minute.toString().padLeft(2, '0');
      final nombreArchivo =
          'transacciones_${dia}-${mes}-${anio}_${hora}${min}.csv';

      return Response.ok(
        buf.toString(),
        headers: {
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': 'attachment; filename="$nombreArchivo"',
        },
      );
    });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 3000);
  print(
      '✅ Backend GGPay corriendo en http://${server.address.host}:${server.port}');
}
