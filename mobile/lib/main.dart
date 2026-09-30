import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

const String backendUrl =
    'https://didactic-bassoon-vpq9vrv9jqrx2574-3000.app.github.dev';

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
      home: const ScannerScreen(),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();

  bool _processing = false;
  bool _useCamera = true;
  DateTime _lastScan = DateTime.fromMillisecondsSinceEpoch(0);

  String _lastStatus = 'Esperando...';

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _handleQr(String payload) async {
    final now = DateTime.now();
    if (_processing || now.difference(_lastScan).inSeconds < 3) return;
    _lastScan = now;
    setState(() => _processing = true);

    try {
      final uri = Uri.parse(payload);
      final sessionId = uri.queryParameters['session'];
      final token = uri.queryParameters['token'];
      final stationId = uri.queryParameters['station'];

      final msg = 'session=$sessionId\ntoken=$token';
      debugPrint('📱 ' + msg);
      if (mounted) setState(() => _lastStatus = 'Enviado:\n$msg');

      if (sessionId == null || token == null) {
        throw Exception('QR no válido');
      }

      final res = await http
          .post(
            Uri.parse('$backendUrl/authorize'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'sessionId': sessionId, 'token': token}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      debugPrint('📥 ' + res.body);

      if (res.statusCode != 200) {
        throw Exception(data['error'] ?? 'Error al autorizar');
      }

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
        _lastStatus = 'ERROR: $e';
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR - Cliente'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_useCamera ? Icons.keyboard : Icons.camera_alt),
            tooltip: _useCamera ? 'Modo manual' : 'Usar cámara',
            onPressed: () => setState(() => _useCamera = !_useCamera),
          ),
        ],
      ),
      body: _useCamera ? _buildCameraView() : _buildManualView(),
    );
  }

  Widget _buildCameraView() {
    return Stack(
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
          bottom: 20,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _lastStatus,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              maxLines: 5,
            ),
          ),
        ),
        if (_processing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildManualView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Modo manual (para pruebas)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pega el payload del QR:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualController,
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'spay://pay?session=...&station=...&token=...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Validar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50),
            ),
            onPressed: () =>
                _handleQr(_manualController.text.trim()),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const Text('Último resultado:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _lastStatus,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
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
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Escanear otro QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScannerScreen()),
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}