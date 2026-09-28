import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/transaction_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();

  bool _processing = false;
  bool _useCamera = true; // Cambia a false para entrada manual

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _handlePayload(String payload) {
    if (_processing) return;
    _processing = true;

    final service = context.read<TransactionService>();
    final error = service.authorizeTransaction(payload);

    if (!mounted) return;

    if (error == null) {
      // Éxito
      final uri = Uri.parse(payload);
      final sessionId = uri.queryParameters['session'];
      final tx = service.getBySession(sessionId!);

      _controller.stop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _SuccessScreen(
            authCode: tx?.authCode ?? '------',
            amount: tx?.amount ?? 0,
            stationId: tx?.stationId ?? '---',
          ),
        ),
      );
    } else {
      // Error: muestra y permite reintentar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
      _processing = false;
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
            tooltip: _useCamera ? 'Entrada manual' : 'Usar cámara',
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
            if (code != null) _handlePayload(code);
          },
        ),
        // Marco visual
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Text(
            'Apunta al código QR de la estación',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Modo manual (para pruebas)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pega aquí el payload del QR:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _manualController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'spay://pay?session=...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Validar'),
              onPressed: () => _handlePayload(_manualController.text.trim()),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Pantalla de éxito (comprobante)
// ============================================================
class _SuccessScreen extends StatelessWidget {
  final String authCode;
  final double amount;
  final String stationId;

  const _SuccessScreen({
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
              const Text(
                '¡Transacción Autorizada!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _row('Bomba', stationId),
                      const Divider(),
                      _row('Monto', 'Q ${amount.toStringAsFixed(2)}'),
                      const Divider(),
                      _row('Código de autorización', authCode),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text('Volver al inicio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}