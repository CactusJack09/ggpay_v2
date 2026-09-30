import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

void main() {
  runApp(const MobileApp());
}

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GGPay Móvil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// SPLASH: decide si mostrar Login o Scanner según sesión guardada
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userName = prefs.getString('userName');
    if (!mounted) return;
    if (userId != null && userName != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(userId: userId, userName: userName),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ============================================================
// LOGIN / REGISTRO
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      Map<String, dynamic> user;
      if (_isRegister) {
        user = await Api.register(
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        user = await Api.login(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user['id']);
      await prefs.setString('userName', user['fullName']);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            userId: user['id'],
            userName: user['fullName'],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegister ? 'Crear cuenta' : 'Iniciar sesión'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.local_gas_station,
                size: 80, color: Colors.green),
            const SizedBox(height: 20),
            if (_isRegister) ...[
              TextField(
                controller: _fullName,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isRegister ? 'REGISTRARSE' : 'ENTRAR',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(_isRegister
                  ? '¿Ya tienes cuenta? Inicia sesión'
                  : '¿No tienes cuenta? Regístrate'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOME: menú principal del usuario
// ============================================================
class HomeScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, $userName'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_gas_station,
                  size: 100, color: Colors.green),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('ESCANEAR QR',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScannerScreen(
                          userId: userId,
                          userName: userName,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('MI HISTORIAL',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryScreen(
                          userId: userId,
                          userName: userName,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SCANNER
// ============================================================
class ScannerScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const ScannerScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  DateTime _lastScan = DateTime.fromMillisecondsSinceEpoch(0);
  String _status = 'Apunta al QR de la estación';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleQr(String payload) async {
    final now = DateTime.now();
    if (_processing || now.difference(_lastScan).inSeconds < 3) return;
    _lastScan = now;
    setState(() {
      _processing = true;
      _status = 'Procesando...';
    });

    try {
      final uri = Uri.parse(payload);
      final sessionId = uri.queryParameters['session'];
      final token = uri.queryParameters['token'];
      final stationId = uri.queryParameters['station'];

      if (sessionId == null || token == null) {
        throw Exception('QR no válido');
      }

      final data = await Api.authorize(
        sessionId: sessionId,
        token: token,
        userId: widget.userId,
        userName: widget.userName,
      );

      if (!mounted) return;
      await _controller.stop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SuccessScreen(
            authCode: data['authCode'] ?? '------',
            amount: (data['amount'] as num).toDouble(),
            stationId: stationId ?? data['stationId'] ?? '---',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error: $e';
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final code = capture.barcodes.first.rawValue;
              if (code != null) _handleQr(code);
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 4),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.black54,
              child: Text(
                _status,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// ÉXITO
// ============================================================
class SuccessScreen extends StatelessWidget {
  final String authCode;
  final double amount;
  final String stationId;

  const SuccessScreen({
    super.key,
    required this.authCode,
    required this.amount,
    required this.stationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago Autorizado'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              const Text('¡PAGO AUTORIZADO!',
                  style:
                      TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _row('Bomba', stationId),
                      const Divider(),
                      _row('Monto', 'Q ${amount.toStringAsFixed(2)}'),
                      const Divider(),
                      _row('Código', authCode),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('VOLVER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

// ============================================================
// HISTORIAL
// ============================================================
class HistoryScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const HistoryScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.getHistory(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Historial'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final txs = (snap.data!['transactions'] as List?) ?? [];
          if (txs.isEmpty) {
            return const Center(
              child: Text('Aún no tienes transacciones',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: txs.length,
            itemBuilder: (context, i) {
              final tx = txs[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Q ${tx['amount']}'),
                  subtitle: Text(
                    '${tx['stationId']} • ${tx['authCode'] ?? "---"}',
                  ),
                  trailing: Text(
                    (tx['createdAt'] as String).substring(0, 10),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}