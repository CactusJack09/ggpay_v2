import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../lib/store.dart';

final _store = TransactionStore();

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
      });
    })

    ..post('/authorize', (Request req) async {
      final body = jsonDecode(await req.readAsString());
      final sessionId = body['sessionId'] as String?;
      final token = body['token'] as String?;
      if (sessionId == null || token == null) {
        return _json({'error': 'faltan datos'}, status: 400);
      }
      final error = _store.authorize(sessionId, token);
      if (error != null) return _json({'error': error}, status: 400);
      final tx = _store.get(sessionId)!;
      return _json({
        'status': 'authorized',
        'authCode': tx.authCode,
        'amount': tx.amount,
        'currency': tx.currency,
        'stationId': tx.stationId,
      });
    })

    ..post('/transaction/<sessionId>/complete', (Request req, String sessionId) {
      _store.complete(sessionId);
      return _json({'ok': true});
    });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 3000);
  print('✅ Backend GGPay corriendo en http://${server.address.host}:${server.port}');
}