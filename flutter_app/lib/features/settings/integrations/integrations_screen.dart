import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/settings_providers.dart';
import '../data/settings_repository.dart';
import '../domain/integration_info.dart';

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  // Service icon config: background color and icon color per service
  static const _serviceStyles = <String, ({Color bg, Color iconColor, IconData icon})>{
    'openrouter': (bg: Color(0xFFEDE9FE), iconColor: AppTheme.accentPrimary, icon: Icons.smart_toy_outlined),
    'whatsapp': (bg: Color(0xFFD1FAE5), iconColor: Color(0xFF16A34A), icon: Icons.chat_bubble_outline),
    'instagram': (bg: Color(0xFFFCE7F3), iconColor: Color(0xFFEC4899), icon: Icons.camera_alt_outlined),
    'tiktok': (bg: Color(0xFF1A1A1A), iconColor: Colors.white, icon: Icons.video_library_outlined),
    'threads': (bg: Color(0xFFF3F4F6), iconColor: Color(0xFF1A1A1A), icon: Icons.alternate_email),
    'notion': (bg: Color(0xFFF3F4F6), iconColor: Color(0xFF1A1A1A), icon: Icons.menu_book_outlined),
  };

  static ({Color bg, Color iconColor, IconData icon}) _styleFor(String service) {
    return _serviceStyles[service.toLowerCase()] ??
        (bg: const Color(0xFFF3F4F6), iconColor: AppTheme.foregroundSecondary, icon: Icons.extension_outlined);
  }

  // Service subtitles
  static const _serviceSubtitles = <String, String>{
    'openrouter': 'AI model provider',
    'whatsapp': 'Business messaging',
    'instagram': 'Social media platform',
    'tiktok': 'Short-form video',
    'threads': 'Text-based social',
    'notion': 'Knowledge base',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrationsAsync = ref.watch(integrationListProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 28,
                      color: AppTheme.foregroundPrimary,
                    ),
                  ),
                  Text(
                    'INTEGRATIONS',
                    style: GoogleFonts.anton(
                      fontSize: 22,
                      color: AppTheme.foregroundPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: integrationsAsync.when(
                data: (integrations) {
                  if (integrations.isEmpty) {
                    return const Center(
                        child: Text('No integrations available'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: integrations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final info = integrations[index];
                      if (info.multiAccount) {
                        return _MultiAccountCard(
                          info: info,
                          onAddAccount: () =>
                              _showAddAccountSheet(context, ref, info),
                          onEditAccount: (account) =>
                              _showEditAccountSheet(
                                  context, ref, info, account),
                          onTestAccount: (account) =>
                              _testAccount(context, ref, account.id),
                          onDeleteAccount: (account) =>
                              _deleteAccount(context, ref, account.id),
                        );
                      }
                      return _IntegrationCard(
                        info: info,
                        onTap: () => _showSetupSheet(context, ref, info),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text('Failed to load integrations: $error'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(integrationListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetupSheet(
      BuildContext context, WidgetRef ref, IntegrationInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IntegrationSetupSheet(info: info, ref: ref),
    );
  }

  void _showAddAccountSheet(
      BuildContext context, WidgetRef ref, IntegrationInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AccountSetupSheet(
          service: info.service, fields: info.requiredFields, ref: ref),
    );
  }

  void _showEditAccountSheet(BuildContext context, WidgetRef ref,
      IntegrationInfo info, IntegrationAccount account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AccountSetupSheet(
        service: info.service,
        fields: info.requiredFields,
        ref: ref,
        account: account,
      ),
    );
  }

  Future<void> _testAccount(
      BuildContext context, WidgetRef ref, String accountId) async {
    final repo = ref.read(settingsRepositoryProvider);
    final result = await repo.testAccount(accountId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result ? 'Connection successful' : 'Connection failed'),
          backgroundColor: result ? AppTheme.success : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteAccount(
      BuildContext context, WidgetRef ref, String accountId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content:
            const Text('This will permanently remove this WhatsApp account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.deleteAccount(accountId);
      ref.invalidate(integrationListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted')),
        );
      }
    }
  }
}

// ==========================================================================
// Single-account card (OpenRouter, Notion, etc.)
// ==========================================================================

class _IntegrationCard extends StatelessWidget {
  final IntegrationInfo info;
  final VoidCallback onTap;

  const _IntegrationCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = IntegrationsScreen._styleFor(info.service);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            // Service icon
            _ServiceIconCircle(
              bgColor: style.bg,
              iconColor: style.iconColor,
              icon: style.icon,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.foregroundPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    IntegrationsScreen._serviceSubtitles[
                            info.service.toLowerCase()] ??
                        info.service,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.foregroundSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Badge
            _ConnectionBadge(isConnected: info.isConnected),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// Multi-account card (WhatsApp)
// ==========================================================================

class _MultiAccountCard extends StatelessWidget {
  final IntegrationInfo info;
  final VoidCallback onAddAccount;
  final void Function(IntegrationAccount) onEditAccount;
  final void Function(IntegrationAccount) onTestAccount;
  final void Function(IntegrationAccount) onDeleteAccount;

  const _MultiAccountCard({
    required this.info,
    required this.onAddAccount,
    required this.onEditAccount,
    required this.onTestAccount,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final style = IntegrationsScreen._styleFor(info.service);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _ServiceIconCircle(
                  bgColor: style.bg,
                  iconColor: style.iconColor,
                  icon: style.icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.foregroundPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${info.accounts.length} account(s)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.foregroundSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chevron-right for multi-account
                GestureDetector(
                  onTap: onAddAccount,
                  child: const Icon(
                    Icons.chevron_right,
                    color: AppTheme.foregroundSecondary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Account list
          if (info.accounts.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            ...info.accounts.map((account) => _AccountTile(
                  account: account,
                  onEdit: () => onEditAccount(account),
                  onTest: () => onTestAccount(account),
                  onDelete: () => onDeleteAccount(account),
                )),
          ],

          // Add account button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: GestureDetector(
              onTap: onAddAccount,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 18, color: AppTheme.accentPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Add Account',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IntegrationAccount account;
  final VoidCallback onEdit;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  const _AccountTile({
    required this.account,
    required this.onEdit,
    required this.onTest,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_android,
                size: 18, color: Color(0xFF16A34A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.label ?? 'Unnamed Account',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.foregroundPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                _ConnectionBadge(isConnected: account.isConnected),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.science_outlined, size: 20),
            tooltip: 'Test',
            onPressed: onTest,
            color: AppTheme.foregroundSecondary,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit',
            onPressed: onEdit,
            color: AppTheme.foregroundSecondary,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: Color(0xFFDC2626)),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// Shared widgets
// ==========================================================================

class _ServiceIconCircle extends StatelessWidget {
  final Color bgColor;
  final Color iconColor;
  final IconData icon;

  const _ServiceIconCircle({
    required this.bgColor,
    required this.iconColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool isConnected;
  const _ConnectionBadge({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final bgColor = isConnected
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEE2E2);
    final textColor = isConnected
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final label = isConnected ? 'Connected' : 'Disconnected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// ==========================================================================
// Single-account setup sheet (OpenRouter, Notion, etc.)
// ==========================================================================

class _IntegrationSetupSheet extends StatefulWidget {
  final IntegrationInfo info;
  final WidgetRef ref;

  const _IntegrationSetupSheet({required this.info, required this.ref});

  @override
  State<_IntegrationSetupSheet> createState() =>
      _IntegrationSetupSheetState();
}

class _IntegrationSetupSheetState extends State<_IntegrationSetupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _isSaving = false;
  bool _isTesting = false;
  bool? _testResult;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.info.requiredFields)
        field: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = IntegrationsScreen._styleFor(widget.info.service);

    return _SheetWrapper(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const SizedBox(height: 16),
            Row(
              children: [
                _ServiceIconCircle(
                  bgColor: style.bg,
                  iconColor: style.iconColor,
                  icon: style.icon,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.info.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foregroundPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._controllers.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: entry.value,
                    obscureText: _isSecret(entry.key),
                    decoration: InputDecoration(
                        labelText: _formatFieldName(entry.key)),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '${_formatFieldName(entry.key)} is required';
                      }
                      return null;
                    },
                  ),
                )),
            if (_testResult != null) ...[
              _TestResultBanner(success: _testResult!),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isTesting ? null : _testConnection,
                    child: _isTesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Test Connection'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveCredentials,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    try {
      if (_formKey.currentState!.validate()) {
        final credentials = {
          for (final e in _controllers.entries) e.key: e.value.text.trim(),
        };
        await widget.ref
            .read(settingsRepositoryProvider)
            .saveIntegration(widget.info.service, credentials);
        final result = await widget.ref
            .read(settingsRepositoryProvider)
            .testIntegration(widget.info.service);
        setState(() => _testResult = result);
      }
    } catch (_) {
      setState(() => _testResult = false);
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final credentials = {
        for (final e in _controllers.entries) e.key: e.value.text.trim(),
      };
      await widget.ref
          .read(settingsRepositoryProvider)
          .saveIntegration(widget.info.service, credentials);
      widget.ref.invalidate(integrationListProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${widget.info.displayName} credentials saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ==========================================================================
// Multi-account setup sheet (WhatsApp add/edit account)
// ==========================================================================

class _AccountSetupSheet extends StatefulWidget {
  final String service;
  final List<String> fields;
  final WidgetRef ref;
  final IntegrationAccount? account; // null = add new

  const _AccountSetupSheet({
    required this.service,
    required this.fields,
    required this.ref,
    this.account,
  });

  @override
  State<_AccountSetupSheet> createState() => _AccountSetupSheetState();
}

class _AccountSetupSheetState extends State<_AccountSetupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final Map<String, TextEditingController> _controllers;
  bool _isSaving = false;

  bool get isEdit => widget.account != null;

  @override
  void initState() {
    super.initState();
    _labelController =
        TextEditingController(text: widget.account?.label ?? '');
    _controllers = {
      for (final field in widget.fields) field: TextEditingController(),
    };
  }

  @override
  void dispose() {
    _labelController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetWrapper(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Edit Account' : 'Add WhatsApp Account',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.foregroundPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Label field
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g. Mecca Cola Almaty',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Account name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Credential fields
            ..._controllers.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: entry.value,
                    obscureText: _isSecret(entry.key),
                    decoration: InputDecoration(
                        labelText: _formatFieldName(entry.key)),
                    validator: isEdit
                        ? null // optional on edit (keep existing if empty)
                        : (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '${_formatFieldName(entry.key)} is required';
                            }
                            return null;
                          },
                  ),
                )),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Update' : 'Add Account'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repo = widget.ref.read(settingsRepositoryProvider);
      final label = _labelController.text.trim();

      if (isEdit) {
        // Only send credentials if user typed something
        final creds = <String, dynamic>{};
        for (final e in _controllers.entries) {
          final v = e.value.text.trim();
          if (v.isNotEmpty) creds[e.key] = v;
        }
        await repo.updateAccount(
          widget.account!.id,
          label: label,
          credentials: creds.isNotEmpty ? creds : null,
        );
      } else {
        final creds = {
          for (final e in _controllers.entries)
            e.key: e.value.text.trim(),
        };
        await repo.addAccount(
          widget.service,
          label: label,
          credentials: creds,
        );
      }

      widget.ref.invalidate(integrationListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Account updated' : 'Account added'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ==========================================================================
// Shared helpers
// ==========================================================================

class _SheetWrapper extends StatelessWidget {
  final Widget child;
  const _SheetWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.borderDefault,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _TestResultBanner extends StatelessWidget {
  final bool success;
  const _TestResultBanner({required this.success});

  @override
  Widget build(BuildContext context) {
    final color = success ? AppTheme.success : AppTheme.error;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle : Icons.error,
              color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            success ? 'Connection successful' : 'Connection failed',
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

String _formatFieldName(String field) {
  final result = field.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (m) => '${m.group(1)} ${m.group(2)}',
  );
  return result[0].toUpperCase() + result.substring(1);
}

bool _isSecret(String field) {
  final lower = field.toLowerCase();
  return lower.contains('token') ||
      lower.contains('secret') ||
      lower.contains('key');
}
