import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = ApiService();
  final _userNameCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();

  DateTime? _from;
  DateTime? _to;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userNameCtrl.dispose();
    _stationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getHistory(
        userName: _userNameCtrl.text.trim(),
        stationId: _stationCtrl.text.trim(),
        from: _from,
        to: _to,
      );
      setState(() => _results = list);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_from ?? now) : (_to ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  Future<void> _exportExcel() async {
    final url = _api.buildExportUrl(
      userName: _userNameCtrl.text.trim(),
      stationId: _stationCtrl.text.trim(),
      from: _from,
      to: _to,
    );
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la descarga')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Transacciones'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text('Filtros',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _userNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de usuario',
                        hintText: 'Ej: Juan, Test, María...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _stationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Estación / Bomba',
                        hintText: 'Ej: PUMP-01',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.local_gas_station),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_from == null
                                ? 'Desde'
                                : _from!.toIso8601String().substring(0, 10)),
                            onPressed: () => _pickDate(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(_to == null
                                ? 'Hasta'
                                : _to!.toIso8601String().substring(0, 10)),
                            onPressed: () => _pickDate(false),
                          ),
                        ),
                      ],
                    ),
                    if (_from != null || _to != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                        child: const Text('Limpiar fechas'),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.search),
                            label: const Text('BUSCAR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _load,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.download),
                            label: const Text('EXCEL'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _exportExcel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Error: $_error'),
                ),
              )
            else if (_results.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Sin resultados',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${_results.length} transacciones encontradas',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      MaterialStateProperty.all(Colors.green.shade100),
                  columns: const [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Usuario')),
                    DataColumn(label: Text('Estación')),
                    DataColumn(label: Text('Monto')),
                    DataColumn(label: Text('Código')),
                    DataColumn(label: Text('Estado')),
                  ],
                  rows: _results.map((t) {
                    final date = (t['createdAt'] as String)
                        .substring(0, 16)
                        .replaceAll('T', ' ');
                    return DataRow(cells: [
                      DataCell(Text(date)),
                      DataCell(Text(t['userName'] ?? '—')),
                      DataCell(Text(t['stationId'] ?? '—')),
                      DataCell(Text('Q ${t['amount']}')),
                      DataCell(Text(t['authCode'] ?? '—')),
                      DataCell(Text(t['status'] ?? '—')),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}