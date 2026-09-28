import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class StationScreen extends StatefulWidget {
  const StationScreen({super.key});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  final _amountController = TextEditingController();
  final _api = ApiService();
  final _stationId = 'PUMP-01';

  String? _sessionId;
  String? _qrPayload;
  double _amount = 0;
  String _status = 'idle'; // idle | waiting | paid | expired
  String? _authCode;
  int _secondsLeft = 10;

  Timer? _qrPollTimer;
  Timer? _statusPollTimer;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _stopAllTimers();
    _amountController.dispose();
    super.dispose();
  }

  void _stopAllTimers() {
    _qrPollTimer?.cancel();
    _statusPollTimer?.cancel();
    _countdownTimer?.cancel();
  }

  Future<void> _generateQr() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    setState(() {
      _status = 'waiting';
      _amount = amount;
      _authCode = null;
      _qrPayload = null;
    });

    try {
      final tx = await _api.createTransaction(
        stationId: _stationId,
        amount: amount,
      );
      setState(() => _sessionId = tx['sessionId']);

      _startPolling();
    } catch (e) {
      setState(() => _status = 'idle');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _startPolling() {
    _stopAllTimers();
    _secondsLeft = 10;

    // Cada 2s consultamos el QR (para que el backend rote el token)
    _qrPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_sessionId == null) return;
      try {
        final qr = await _api.getQr(_sessionId!);
        final payload = 'spay://pay?session=${qr['sessionId']}'
            '&station=${qr['stationId']}'
            '&token=${qr['token']}';
        setState(() => _qrPayload = payload);
      } catch (_) {}
    });

    // Cada 2s consultamos el estado (para detectar el pago)
    _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_sessionId == null) return;
      try {
        final st = await _api.getStatus(_sessionId!);
        if (st['status'] == 'authorized' || st['status'] == 'completed') {
          _stopAllTimers();
          setState(() {
            _status = 'paid';
            _authCode = st['authCode'];
          });
        } else if (st['status'] == 'expired') {
          _stopAllTimers();
          setState(() => _status = 'expired');
        }
      } catch (_) {}
    });

    // Cuenta regresiva visual de 10s por cada token
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) _secondsLeft = 10;
      });
    });
  }

  Future<void> _completePayment() async {
    if (_sessionId != null) {
      try {
        await _api.complete(_sessionId!);
      } catch (_) {}
    }
    _reset();
  }

  void _reset() {
    _stopAllTimers();
    setState(() {
      _sessionId = null;
      _qrPayload = null;
      _status = 'idle';
      _authCode = null;
      _amount = 0;
      _amountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estación - Cobro'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.local_gas_station, color: Colors.green),
                title: Text('Bomba: $_stationId'),
                subtitle: const Text('Estado: Disponible'),
              ),
            ),
            const SizedBox(height: 20),
            if (_status == 'idle') _buildAmountInput(),
            if (_status == 'waiting') _buildQrDisplay(),
            if (_status == 'paid') _buildPaidDisplay(),
            if (_status == 'expired') _buildExpiredDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      children: [
        const Text('Ingresa el monto a cobrar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            prefixText: 'Q ',
            prefixStyle:
                TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            hintText: '0.00',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_2),
            label: const Text('GENERAR QR DE PAGO',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: _generateQr,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'El cliente deberá escanear este código para autorizar el pago.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildQrDisplay() {
    final color = _secondsLeft > 5
        ? Colors.green
        : _secondsLeft > 3
            ? Colors.orange
            : Colors.red;

    return Column(
      children: [
        Text('Monto a pagar',
            style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        Text(
          NumberFormat.currency(locale: 'es_GT', symbol: 'Q ')
              .format(_amount),
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1), blurRadius: 10),
            ],
          ),
          child: _qrPayload == null
              ? const SizedBox(
                  width: 260,
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              : QrImageView(
                  key: ValueKey(_qrPayload),
                  data: _qrPayload!,
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
                ),
        ),
        const SizedBox(height: 20),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: _secondsLeft / 10,
                strokeWidth: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '${_secondsLeft}s',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Esperando escaneo del cliente...',
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        const Text(
          'El código QR se actualiza automáticamente cada 10 segundos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.cancel),
            label: const Text('Cancelar transacción'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _reset,
          ),
        ),
      ],
    );
  }

  Widget _buildPaidDisplay() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 100),
        const SizedBox(height: 20),
        const Text('¡PAGO CONFIRMADO!',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.green)),
        const SizedBox(height: 30),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _row('Bomba', _stationId),
                const Divider(),
                _row('Monto',
                    NumberFormat.currency(locale: 'es_GT', symbol: 'Q ')
                        .format(_amount)),
                const Divider(),
                _row('Código de autorización', _authCode ?? '------'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.done_all),
            label: const Text('NUEVA TRANSACCIÓN',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: _completePayment,
          ),
        ),
      ],
    );
  }

  Widget _buildExpiredDisplay() {
    return Column(
      children: [
        const Icon(Icons.timer_off, color: Colors.orange, size: 100),
        const SizedBox(height: 20),
        const Text('QR Expirado',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange)),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('INTENTAR DE NUEVO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: _reset,
          ),
        ),
      ],
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