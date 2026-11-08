import 'package:flutter/material.dart';

import '../models/expiration_model.dart';
import '../services/expiration_service.dart';

class ExpirationHistoryScreen extends StatefulWidget {
  final ExpirationService service;

  const ExpirationHistoryScreen({
    super.key,
    this.service = const ExpirationService(),
  });

  @override
  State<ExpirationHistoryScreen> createState() =>
      _ExpirationHistoryScreenState();
}

class _ExpirationHistoryScreenState extends State<ExpirationHistoryScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<ExpirationHistoryEntry> _history = const <ExpirationHistoryEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await widget.service.getHistory(
      start: _startDate,
      end: _endDate,
    );
    if (!mounted) return;
    setState(() => _history = history);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expiration History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                        await _load();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _startDate.toLocal().toString().split(' ').first,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                        await _load();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _endDate.toLocal().toString().split(' ').first,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _history.isEmpty
                ? const Center(
                    child: Text('No stock movement history available.'),
                  )
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final entry = _history[index];
                      return ListTile(
                        title: Text(
                          '${entry.productName} · ${entry.batchIdentifier}',
                        ),
                        subtitle: Text(
                          '${entry.movementType.label} · ${entry.previousQuantity} → ${entry.updatedQuantity}\n'
                          'Date: ${entry.movementDate.toLocal().toString().split(' ').first}',
                        ),
                        trailing: Text(entry.status.label),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
