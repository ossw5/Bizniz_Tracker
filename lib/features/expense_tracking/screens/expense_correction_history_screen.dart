import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/expense_record.dart';
import '../services/expense_service.dart';

class ExpenseCorrectionHistoryScreen extends StatefulWidget {
  final ExpenseService service;

  const ExpenseCorrectionHistoryScreen({super.key, required this.service});

  @override
  State<ExpenseCorrectionHistoryScreen> createState() =>
      _ExpenseCorrectionHistoryScreenState();
}

class _ExpenseCorrectionHistoryScreenState
    extends State<ExpenseCorrectionHistoryScreen> {
  late Future<List<ExpenseCorrection>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.service.loadCorrections();
  }

  Future<void> _refresh() async {
    setState(() => _history = widget.service.loadCorrections());
    await _history;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Expense Correction History'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<ExpenseCorrection>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load correction history: ${snapshot.error}'),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final history = snapshot.data ?? const <ExpenseCorrection>[];
          if (history.isEmpty) {
            return const Center(child: Text('No expense changes recorded.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final record =
                    item.updatedRecord ?? item.previousRecord ?? const {};
                final description = record['description'] as String? ?? 'Expense';
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.history_rounded,
                      color: AppColors.forestGreen,
                    ),
                    title: Text('${item.action}: $description'),
                    subtitle: Text(
                      '${item.reason}\n'
                      '${MaterialLocalizations.of(context).formatMediumDate(item.changedAt)}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
