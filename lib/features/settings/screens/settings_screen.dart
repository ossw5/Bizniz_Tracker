import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/app_settings_controller.dart';
import '../models/activity_record.dart';
import '../models/app_settings.dart';
import '../services/activity_log_service.dart';
import '../services/local_backup_service.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettingsController controller;
  final ActivityLogService activityLog;
  final LocalBackupService backupService;

  const SettingsScreen({
    super.key,
    required this.controller,
    this.activityLog = const ActivityLogService(),
    this.backupService = const LocalBackupService(),
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<ActivityRecord>> _recentActivities;
  bool _backupInProgress = false;
  String? _backupStatus;

  @override
  void initState() {
    super.initState();
    _recentActivities = widget.activityLog.loadRecent(limit: 5);
  }

  Future<void> _refreshActivities() async {
    setState(() {
      _recentActivities = widget.activityLog.loadRecent(limit: 5);
    });
    await _recentActivities;
  }

  Future<void> _editProfile() async {
    final current = widget.controller.profile;
    final profile = await showDialog<StoreProfile>(
      context: context,
      builder: (context) => _StoreProfileDialog(profile: current),
    );
    if (profile == null) return;
    try {
      await widget.controller.saveProfile(profile);
      if (!mounted) return;
      _showMessage('Store profile saved on this device.');
    } catch (error) {
      if (mounted) _showMessage('Could not save store profile: $error');
    }
  }

  Future<void> _updatePreferences(AppPreferences updated) async {
    try {
      await widget.controller.updatePreferences(updated);
    } catch (error) {
      if (mounted) _showMessage('Could not save app preferences: $error');
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _backupInProgress = true;
      _backupStatus = 'Preparing backup...';
    });
    try {
      final path = await widget.backupService.exportBackup();
      if (!mounted) return;
      if (path == null || path.isEmpty) {
        setState(() => _backupStatus = 'Backup export was canceled.');
        return;
      }
      final now = DateTime.now();
      await widget.controller.markLocalBackup(now);
      await widget.activityLog.record(
        description: 'Created a local data backup',
        category: 'Backup',
        occurredAt: now,
      );
      await _refreshActivities();
      if (!mounted) return;
      setState(() => _backupStatus = 'Backup exported successfully: $path');
    } catch (error) {
      if (mounted) {
        setState(() => _backupStatus = 'Backup failed: $error');
      }
    } finally {
      if (mounted) setState(() => _backupInProgress = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() {
      _backupInProgress = true;
      _backupStatus = 'Select and validate a backup file...';
    });
    try {
      final backup = await widget.backupService.pickAndValidateBackup();
      if (backup == null) {
        if (mounted) setState(() => _backupStatus = 'Restore was canceled.');
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore application data?'),
          content: const Text(
            'Restoring this backup replaces current business records, '
            'including products, sales, expenses, credits, and preferences. '
            'A failed restore will attempt to put the current data back.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        if (mounted) setState(() => _backupStatus = 'Restore was canceled.');
        return;
      }
      await widget.backupService.restoreBackup(backup);
      await widget.controller.load();
      await widget.activityLog.record(
        description: 'Restored application data from a local backup',
        category: 'Backup',
      );
      await _refreshActivities();
      if (mounted) {
        setState(() => _backupStatus = 'Backup restored successfully.');
      }
    } catch (error) {
      if (mounted) setState(() => _backupStatus = 'Restore failed: $error');
    } finally {
      if (mounted) setState(() => _backupInProgress = false);
    }
  }

  Future<void> _showDriveSetup() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Drive setup required'),
        content: const SingleChildScrollView(
          child: Text(
            'Drive backup is not connected because this project does not yet '
            'contain Google OAuth client configuration or a Drive API '
            'integration. To enable it, configure OAuth client IDs for the '
            'target platforms, enable the Google Drive API in the matching '
            'Google Cloud project, configure Android signing fingerprints and '
            'iOS URL schemes where applicable, and provide a least-privilege '
            'Drive app-data authorization flow. No Google password should be '
            'collected by Bizniz Tracker. Local backup and offline app use '
            'remain available without Drive.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAboutAction(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final preferences = controller.preferences;
    final notifications = preferences.notifications;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            icon: Icons.storefront_rounded,
            title: 'Store Profile',
            description: 'Business information stored on this device',
            children: [
              _ProfileSummary(profile: controller.profile),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _editProfile,
                icon: const Icon(Icons.edit_rounded),
                label: Text(
                  controller.profile.storeName.isEmpty
                      ? 'Add Store Information'
                      : 'Edit Store Information',
                ),
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.tune_rounded,
            title: 'App Preferences',
            description: 'Appearance, currency, and date format',
            children: [
              DropdownButtonFormField<ThemeMode>(
                initialValue: preferences.themeMode,
                decoration: const InputDecoration(labelText: 'Appearance'),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light Mode'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark Mode'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _updatePreferences(preferences.copyWith(themeMode: value));
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: preferences.currencyCode,
                decoration: const InputDecoration(labelText: 'Currency Format'),
                items: const [
                  DropdownMenuItem(
                    value: 'PHP',
                    child: Text('Philippine Peso (₱)'),
                  ),
                  DropdownMenuItem(value: 'USD', child: Text('US Dollar (\$)')),
                  DropdownMenuItem(value: 'EUR', child: Text('Euro (€)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _updatePreferences(
                      preferences.copyWith(currencyCode: value),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: preferences.datePattern,
                decoration: const InputDecoration(labelText: 'Date Format'),
                items: const [
                  DropdownMenuItem(
                    value: 'MMM d, yyyy',
                    child: Text('Nov 8, 2026'),
                  ),
                  DropdownMenuItem(
                    value: 'dd/MM/yyyy',
                    child: Text('08/11/2026'),
                  ),
                  DropdownMenuItem(
                    value: 'MM/dd/yyyy',
                    child: Text('11/08/2026'),
                  ),
                  DropdownMenuItem(
                    value: 'yyyy-MM-dd',
                    child: Text('2026-11-08'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _updatePreferences(
                      preferences.copyWith(datePattern: value),
                    );
                  }
                },
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.notifications_active_outlined,
            title: 'Notification Settings',
            description:
                'Save your alert preferences for supported app notifications',
            children: [
              _PreferenceSwitch(
                title: 'Low Stock Notifications',
                value: notifications.lowStock,
                onChanged: (value) => _updatePreferences(
                  preferences.copyWith(
                    notifications: notifications.copyWith(lowStock: value),
                  ),
                ),
              ),
              _PreferenceSwitch(
                title: 'Product Expiration Notifications',
                value: notifications.expiration,
                onChanged: (value) => _updatePreferences(
                  preferences.copyWith(
                    notifications: notifications.copyWith(expiration: value),
                  ),
                ),
              ),
              _PreferenceSwitch(
                title: 'Sales Notifications',
                value: notifications.sales,
                onChanged: (value) => _updatePreferences(
                  preferences.copyWith(
                    notifications: notifications.copyWith(sales: value),
                  ),
                ),
              ),
              _PreferenceSwitch(
                title: 'Expense Reminders',
                value: notifications.expenseReminders,
                onChanged: (value) => _updatePreferences(
                  preferences.copyWith(
                    notifications: notifications.copyWith(
                      expenseReminders: value,
                    ),
                  ),
                ),
              ),
              Text(
                'This project currently has no local or push notification '
                'delivery service. These switches are saved for preferences; '
                'they do not schedule operating-system notifications.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.history_rounded,
            title: 'Recent Activities',
            description: 'Changes recorded in this app',
            children: [
              FutureBuilder<List<ActivityRecord>>(
                future: _recentActivities,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'Could not load recent activities: ${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Text(
                      'Activities will appear here as you use the app.',
                    );
                  }
                  return Column(
                    children: [
                      for (final activity in snapshot.data!)
                        _ActivityTile(activity: activity),
                    ],
                  );
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _AllActivitiesScreen(activityLog: widget.activityLog),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('View All Activities'),
                ),
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.backup_outlined,
            title: 'Local Data Backup',
            description: 'Export or restore this device’s business data',
            children: [
              Text(
                controller.lastLocalBackup == null
                    ? 'Last successful backup: Not yet created'
                    : 'Last successful backup: '
                          '${formatAppDate(controller.lastLocalBackup!)} '
                          '${_formatTime(controller.lastLocalBackup!)}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _backupInProgress ? null : _createBackup,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Create Backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _backupInProgress ? null : _restoreBackup,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore Backup'),
                  ),
                ],
              ),
              if (_backupInProgress) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_backupStatus != null) ...[
                const SizedBox(height: 8),
                Text(_backupStatus!),
              ],
            ],
          ),
          _SettingsSection(
            icon: Icons.cloud_outlined,
            title: 'Google Drive Backup',
            description: 'Optional online backup; local data remains primary',
            children: [
              const _StatusRow(
                label: 'Connection status',
                value: 'Not connected',
              ),
              const SizedBox(height: 8),
              Text(
                'Google OAuth and Drive API configuration are not present in '
                'this project. No account is connected and no cloud backup is '
                'being performed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _showDriveSetup,
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('View Required Setup'),
              ),
              const SizedBox(height: 8),
              const _StatusRow(
                label: 'Automatic Backup',
                value: 'Unavailable until Drive is configured',
              ),
              const _StatusRow(
                label: 'Restore from Drive',
                value: 'Unavailable until Drive is configured',
              ),
            ],
          ),
          _SettingsSection(
            icon: Icons.info_outline_rounded,
            title: 'About Bizniz Tracker',
            description: 'App information and help',
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.forestGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bizniz Tracker',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text('Offline Inventory & Sales Manager · 1.0.0+1'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Manage products, inventory, sales, expenses, and customer '
                'credit records in one offline-first business app.',
              ),
              const SizedBox(height: 8),
              _AboutAction(
                title: 'User Guide',
                onTap: () => _showAboutAction(
                  'User Guide',
                  'Use Inventory to manage products and batches, Sales to '
                      'record transactions, and Reports to review sales, expenses, '
                      'and customer credit. Settings stores your profile and '
                      'preferences and provides local backup and restore.',
                ),
              ),
              _AboutAction(
                title: 'Help and Support',
                onTap: () => _showAboutAction(
                  'Help and Support',
                  'No support email address or service link is configured in '
                      'this application.',
                ),
              ),
              _AboutAction(
                title: 'Privacy Policy',
                onTap: () => _showAboutAction(
                  'Privacy Policy',
                  'A privacy policy has not been added to this application.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      leading: Icon(icon, color: AppColors.forestGreen),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(description),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _ProfileSummary extends StatelessWidget {
  final StoreProfile profile;

  const _ProfileSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    final fields = <(String, String)>[
      ('Store Name', profile.storeName),
      ('Owner Name', profile.ownerName),
      ('Store Address', profile.address),
      ('Contact Number', profile.contactNumber),
    ];
    if (fields.every((field) => field.$2.isEmpty)) {
      return const Text('No store profile has been saved yet.');
    }
    return Column(
      children: [
        for (final field in fields)
          if (field.$2.isNotEmpty) _StatusRow(label: field.$1, value: field.$2),
      ],
    );
  }
}

class _StoreProfileDialog extends StatefulWidget {
  final StoreProfile profile;

  const _StoreProfileDialog({required this.profile});

  @override
  State<_StoreProfileDialog> createState() => _StoreProfileDialogState();
}

class _StoreProfileDialogState extends State<_StoreProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _storeName;
  late final TextEditingController _ownerName;
  late final TextEditingController _address;
  late final TextEditingController _contact;

  @override
  void initState() {
    super.initState();
    _storeName = TextEditingController(text: widget.profile.storeName);
    _ownerName = TextEditingController(text: widget.profile.ownerName);
    _address = TextEditingController(text: widget.profile.address);
    _contact = TextEditingController(text: widget.profile.contactNumber);
  }

  @override
  void dispose() {
    _storeName.dispose();
    _ownerName.dispose();
    _address.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      StoreProfile(
        storeName: _storeName.text.trim(),
        ownerName: _ownerName.text.trim(),
        address: _address.text.trim(),
        contactNumber: _contact.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Store Profile'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _requiredField(_storeName, 'Store Name'),
            const SizedBox(height: 10),
            _requiredField(_ownerName, 'Owner Name'),
            const SizedBox(height: 10),
            _requiredField(_address, 'Store Address'),
            const SizedBox(height: 10),
            _requiredField(
              _contact,
              'Contact Number',
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save Changes')),
    ],
  );

  Widget _requiredField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: '$label *'),
    validator: (value) =>
        value == null || value.trim().isEmpty ? 'Enter $label.' : null,
  );
}

class _PreferenceSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: value,
    onChanged: onChanged,
  );
}

class _ActivityTile extends StatelessWidget {
  final ActivityRecord activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(
      _activityIcon(activity.category),
      color: AppColors.forestGreen,
    ),
    title: Text(activity.description),
    subtitle: Text(
      '${activity.category} · ${formatAppDate(activity.occurredAt)} '
      '${_formatTime(activity.occurredAt)}',
    ),
  );
}

class _AllActivitiesScreen extends StatefulWidget {
  final ActivityLogService activityLog;

  const _AllActivitiesScreen({required this.activityLog});

  @override
  State<_AllActivitiesScreen> createState() => _AllActivitiesScreenState();
}

class _AllActivitiesScreenState extends State<_AllActivitiesScreen> {
  late Future<List<ActivityRecord>> _activities;

  @override
  void initState() {
    super.initState();
    _activities = widget.activityLog.loadRecent();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Recent Activities')),
    body: FutureBuilder<List<ActivityRecord>>(
      future: _activities,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load activities: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('No activities have been recorded.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _ActivityTile(activity: snapshot.data![index]),
        );
      },
    ),
  );
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _AboutAction extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _AboutAction({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

IconData _activityIcon(String category) => switch (category) {
  'Sales' => Icons.point_of_sale_rounded,
  'Expense' => Icons.receipt_long_rounded,
  'Credit' || 'Customer' => Icons.account_balance_wallet_rounded,
  'Backup' => Icons.backup_rounded,
  _ => Icons.inventory_2_rounded,
};

String _formatTime(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:'
    '${dateTime.minute.toString().padLeft(2, '0')}';
