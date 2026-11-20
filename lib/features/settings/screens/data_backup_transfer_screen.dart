import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/data_transfer_service.dart';

class DataBackupTransferScreen extends StatefulWidget {
  final DataTransferService transferService;
  final Future<void> Function()? onDataImported;

  const DataBackupTransferScreen({
    super.key,
    required this.transferService,
    this.onDataImported,
  });

  @override
  State<DataBackupTransferScreen> createState() =>
      _DataBackupTransferScreenState();
}

class _DataBackupTransferScreenState extends State<DataBackupTransferScreen> {
  bool _busy = false;
  String? _status;
  bool _statusIsError = false;

  Future<void> _export(DataTransferKind kind) async {
    final password = await _requestPassword(confirm: true);
    if (password == null || !mounted) return;

    setState(() {
      _busy = true;
      _status = 'Preparing encrypted backup...';
      _statusIsError = false;
    });
    try {
      final bytes = kind == DataTransferKind.allData
          ? await widget.transferService.exportAllData(password)
          : await widget.transferService.exportProductsOnly(password);
      if (!mounted) return;
      final stem =
          '${kind == DataTransferKind.allData ? 'bizniz_tracker_all_data' : 'bizniz_tracker_products'}_'
          '${_fileTimestamp(DateTime.now())}';
      final action = await _chooseExportAction();
      if (action == null || !mounted) {
        if (mounted) _setStatus('Backup export was canceled.');
        return;
      }
      if (action == _ExportAction.share) {
        setState(() => _status = 'Opening the device share sheet...');
        final result = await SharePlus.instance.share(
          ShareParams(
            title: 'Encrypted Bizniz Tracker backup',
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'application/octet-stream',
                name: '$stem.bztbackup',
              ),
            ],
            fileNameOverrides: ['$stem.bztbackup'],
          ),
        );
        if (!mounted) return;
        setState(() {
          _status = result.status == ShareResultStatus.dismissed
              ? 'Sharing was canceled.'
              : 'Encrypted backup shared.';
        });
      } else {
        setState(() => _status = 'Choose where to save the encrypted backup.');
        final result = await FileSaver.instance.saveAs(
          name: stem,
          bytes: bytes,
          fileExtension: 'bztbackup',
          mimeType: MimeType.other,
          dialogTitle: 'Save encrypted Bizniz Tracker backup',
        );
        if (!mounted) return;
        setState(() {
          _status = result == null || result.isEmpty
              ? 'Backup export was canceled.'
              : 'Encrypted backup exported successfully.';
        });
      }
    } catch (error) {
      if (mounted) _setError('Could not export the backup: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_ExportAction?> _chooseExportAction() => showDialog<_ExportAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export encrypted backup'),
      content: const Text('Save the file or share it using another app.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, _ExportAction.share),
          icon: const Icon(Icons.share_rounded),
          label: const Text('Share'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _ExportAction.save),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Save'),
        ),
      ],
    ),
  );

  String _fileTimestamp(DateTime value) =>
      '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}_'
      '${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}';

  Future<void> _import(DataTransferKind kind) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Select an encrypted backup file...';
      _statusIsError = false;
    });
    try {
      final bytes = await _pickBackupFile();
      if (!mounted) return;
      if (bytes == null) {
        _setStatus('Import was canceled.');
        return;
      }
      final password = await _requestPassword(confirm: false);
      if (!mounted) return;
      if (password == null) {
        _setStatus('Import was canceled.');
        return;
      }

      setState(() {
        _status = 'Decrypting and validating backup...';
        _statusIsError = false;
      });
      final prepared = await widget.transferService.decryptAndValidate(
        bytes,
        password: password,
        expectedKind: kind,
      );
      if (!mounted) return;

      if (kind == DataTransferKind.allData) {
        final confirmed = await _confirmFullImport(prepared);
        if (confirmed != true || !mounted) {
          if (mounted) _setStatus('Import was canceled.');
          return;
        }
        setState(() {
          _busy = true;
          _status = 'Restoring application data...';
        });
        await widget.transferService.backupService.restoreBackup(
          prepared.payload,
        );
        await widget.onDataImported?.call();
        if (mounted) _setStatus('All backed-up application data was restored.');
      } else {
        final updateExisting = await _confirmProductImport(prepared);
        if (updateExisting == null || !mounted) {
          if (mounted) _setStatus('Import was canceled.');
          return;
        }
        setState(() {
          _busy = true;
          _status = 'Importing product catalog...';
        });
        final result = await widget.transferService.importProducts(
          prepared,
          updateExisting: updateExisting,
        );
        await widget.onDataImported?.call();
        if (mounted) {
          _setStatus(
            'Catalog imported: ${result.added} added, '
            '${result.updated} updated, ${result.skipped} skipped.',
          );
        }
      }
    } catch (error) {
      if (mounted) _setError('Could not import the backup: $error');
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<Uint8List?> _pickBackupFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['bztbackup'],
    );
    if (result.isEmpty) return null;
    final file = result.single;
    final knownLength = file.lengthSync();
    if (knownLength != null &&
        knownLength > DataTransferService.maxBackupFileBytes) {
      throw const FormatException(
        'The selected backup file exceeds the supported size limit.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (builder.length + chunk.length >
          DataTransferService.maxBackupFileBytes) {
        throw const FormatException(
          'The selected backup file exceeds the supported size limit.',
        );
      }
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw const FormatException('The selected backup file is empty.');
    }
    return bytes;
  }

  Future<String?> _requestPassword({required bool confirm}) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _BackupPasswordDialog(confirm: confirm),
    );
  }

  Future<bool?> _confirmFullImport(PreparedDataTransfer prepared) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace application data?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Import All Data replaces the current business data and '
                  'settings on this device. A recovery snapshot is kept in '
                  'memory while the restore runs.',
                ),
                const SizedBox(height: 16),
                for (final line in prepared.summaryLines) Text(line),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace and Import'),
            ),
          ],
        ),
      );

  Future<bool?> _confirmProductImport(PreparedDataTransfer prepared) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => _ProductImportConfirmationDialog(prepared: prepared),
    );
  }

  void _setStatus(String message) {
    setState(() {
      _status = message;
      _statusIsError = false;
    });
  }

  void _setError(String message) {
    setState(() {
      _status = message;
      _statusIsError = true;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Data Backup & Transfer')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Export encrypted, password-protected backups or restore data from '
          'another device.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        _TransferSection(
          title: 'EXPORT DATA',
          children: [
            _TransferAction(
              icon: Icons.backup_rounded,
              title: 'Export All Data',
              subtitle: 'Back up business records, products, and settings',
              onPressed: _busy ? null : () => _export(DataTransferKind.allData),
            ),
            const Divider(height: 1),
            _TransferAction(
              icon: Icons.inventory_2_outlined,
              title: 'Export Products Only',
              subtitle: 'Share product names, categories, and prices',
              onPressed: _busy
                  ? null
                  : () => _export(DataTransferKind.productsOnly),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TransferSection(
          title: 'IMPORT DATA',
          children: [
            _TransferAction(
              icon: Icons.restore_rounded,
              title: 'Import All Data',
              subtitle: 'Restore a complete encrypted backup',
              onPressed: _busy ? null : () => _import(DataTransferKind.allData),
            ),
            const Divider(height: 1),
            _TransferAction(
              icon: Icons.add_to_photos_outlined,
              title: 'Import Products Only',
              subtitle: 'Add or update a shared product catalog',
              onPressed: _busy
                  ? null
                  : () => _import(DataTransferKind.productsOnly),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
        ],
        if (_status != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _status!,
              style: TextStyle(
                color: _statusIsError
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _BackupPasswordDialog extends StatefulWidget {
  final bool confirm;

  const _BackupPasswordDialog({required this.confirm});

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.confirm ? 'Protect your backup' : 'Unlock backup'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _passwordController,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: widget.confirm
                  ? 'Use at least 12 characters. Keep it somewhere safe.'
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter the backup password.';
              }
              if (widget.confirm &&
                  value.length < DataTransferService.minimumPasswordLength) {
                return 'Use at least 12 characters.';
              }
              return null;
            },
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmationController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState?.validate() ?? false) {
            Navigator.pop(context, _passwordController.text);
          }
        },
        child: Text(widget.confirm ? 'Continue' : 'Unlock'),
      ),
    ],
  );
}

class _ProductImportConfirmationDialog extends StatefulWidget {
  final PreparedDataTransfer prepared;

  const _ProductImportConfirmationDialog({required this.prepared});

  @override
  State<_ProductImportConfirmationDialog> createState() =>
      _ProductImportConfirmationDialogState();
}

class _ProductImportConfirmationDialogState
    extends State<_ProductImportConfirmationDialog> {
  bool _updateExisting = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Import product catalog?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Only product catalog fields will be imported. Stock '
            'quantities, sales, expenses, customers, and settings '
            'will not be changed.',
          ),
          const SizedBox(height: 12),
          for (final line in widget.prepared.summaryLines) Text(line),
          const SizedBox(height: 12),
          const Text('When a product already exists:'),
          RadioGroup<bool>(
            groupValue: _updateExisting,
            onChanged: (value) {
              if (value != null) setState(() => _updateExisting = value);
            },
            child: Column(
              children: [
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  title: const Text('Skip existing products'),
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  title: const Text('Update catalog fields'),
                  subtitle: const Text(
                    'Keep this store’s stock quantity and minimum stock level.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _updateExisting),
        child: const Text('Import Catalog'),
      ),
    ],
  );
}

enum _ExportAction { save, share }

class _TransferSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _TransferSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _TransferAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  const _TransferAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onPressed,
  );
}
