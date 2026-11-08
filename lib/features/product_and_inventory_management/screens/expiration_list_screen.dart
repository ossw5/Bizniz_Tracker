import 'package:flutter/material.dart';

import '../../products/presentation/controllers.dart';
import '../models/expiration_model.dart';
import '../services/expiration_service.dart';
import '../widgets/expiration_list_item.dart';
import 'add_expiration_screen.dart';
import 'expiration_history_screen.dart';
import 'edit_expiration_screen.dart';
import 'product_batch_details_screen.dart';
import 'update_stock_screen.dart';

class ExpirationListScreen extends StatefulWidget {
  final ProductController? productController;
  final ExpirationService service;

  const ExpirationListScreen({
    super.key,
    this.productController,
    this.service = const ExpirationService(),
  });

  @override
  State<ExpirationListScreen> createState() => _ExpirationListScreenState();
}

class _ExpirationListScreenState extends State<ExpirationListScreen> {
  final TextEditingController _searchController = TextEditingController();
  ExpirationStatus? _selectedStatus;
  List<ExpirationModel> _allRecords = const <ExpirationModel>[];
  List<ExpirationModel> _records = const <ExpirationModel>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = widget.productController?.state.products ?? const [];
    final allRecords = await widget.service.loadAll(products: products);
    final records = await widget.service.searchAndFilter(
      query: _searchController.text,
      status: _selectedStatus,
      products: products,
    );
    if (!mounted) return;
    setState(() {
      _allRecords = allRecords;
      _records = records;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, int> _summaryFrom(List<ExpirationModel> records) {
    return {
      'total': records.length,
      'normal': records
          .where((record) => record.status == ExpirationStatus.normal)
          .length,
      'nearing': records
          .where(
            (record) => record.status == ExpirationStatus.nearingExpiration,
          )
          .length,
      'expired': records
          .where((record) => record.status == ExpirationStatus.expired)
          .length,
      'depleted': records
          .where((record) => record.status == ExpirationStatus.depleted)
          .length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summaryFrom(_allRecords);
    final statusOptions = [
      'All',
      'Normal',
      'Nearing Expiration',
      'Expired',
      'Depleted',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PRODUCT EXPIRATION MANAGEMENT',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by product, ID, or batch',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _load(),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: statusOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final label = statusOptions[index];
                final selected = index == _selectedStatusIndex();
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) async {
                    setState(() {
                      _selectedStatus = switch (index) {
                        1 => ExpirationStatus.normal,
                        2 => ExpirationStatus.nearingExpiration,
                        3 => ExpirationStatus.expired,
                        4 => ExpirationStatus.depleted,
                        _ => null,
                      };
                    });
                    await _load();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                _SummaryCard(title: 'Total', value: summary['total']!),
                _SummaryCard(title: 'Normal', value: summary['normal']!),
                _SummaryCard(title: 'Nearing', value: summary['nearing']!),
                _SummaryCard(title: 'Expired', value: summary['expired']!),
                _SummaryCard(title: 'Depleted', value: summary['depleted']!),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _records.isEmpty
                ? const Center(child: Text('No expiration records found.'))
                : ListView(
                    children: [
                      for (final record in _records)
                        ExpirationListItem(
                          record: record,
                          onViewDetails: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductBatchDetailsScreen(
                                      productId: record.productId,
                                      productController:
                                          widget.productController,
                                      service: widget.service,
                                    ),
                                  ),
                                )
                                .then((_) {
                                  _load();
                                });
                          },
                          onEdit: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => EditExpirationScreen(
                                      record: record,
                                      productController:
                                          widget.productController,
                                      service: widget.service,
                                    ),
                                  ),
                                )
                                .then((_) => _load());
                          },
                          onUpdateStock: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => UpdateStockScreen(
                                      productController:
                                          widget.productController,
                                      service: widget.service,
                                      defaultProductId: record.productId,
                                      defaultRecordId: record.id,
                                    ),
                                  ),
                                )
                                .then((_) => _load());
                          },
                          onViewHistory: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ExpirationHistoryScreen(
                                  service: widget.service,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => AddExpirationScreen(
                    productController: widget.productController,
                    service: widget.service,
                  ),
                ),
              )
              .then((_) => _load());
        },
        icon: const Icon(Icons.add_circle_rounded),
        label: const Text('Add Product Expiration'),
      ),
    );
  }

  int _selectedStatusIndex() {
    switch (_selectedStatus) {
      case ExpirationStatus.normal:
        return 1;
      case ExpirationStatus.nearingExpiration:
        return 2;
      case ExpirationStatus.expired:
        return 3;
      case ExpirationStatus.depleted:
        return 4;
      case null:
        return 0;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int value;

  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
