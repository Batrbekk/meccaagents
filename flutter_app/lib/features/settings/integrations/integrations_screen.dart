import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/settings_providers.dart';
import '../data/settings_repository.dart';
import '../domain/integration_info.dart';

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrationsAsync = ref.watch(integrationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrations'),
      ),
      body: integrationsAsync.when(
        data: (integrations) {
          if (integrations.isEmpty) {
            return const Center(child: Text('No integrations available'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: integrations.length,
            itemBuilder: (context, index) {
              return _IntegrationCard(
                info: integrations[index],
                onTap: () => _showSetupSheet(
                  context,
                  ref,
                  integrations[index],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load integrations: $error'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(integrationListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetupSheet(
    BuildContext context,
    WidgetRef ref,
    IntegrationInfo info,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IntegrationSetupSheet(info: info, ref: ref),
    );
  }
}

class _IntegrationCard extends StatelessWidget {
  final IntegrationInfo info;
  final VoidCallback onTap;

  const _IntegrationCard({
    required this.info,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Icon(info.icon, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    _ConnectionBadge(isConnected: info.isConnected),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool isConnected;

  const _ConnectionBadge({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppTheme.success : AppTheme.textSecondary;
    final label = isConnected ? 'Connected' : 'Not Connected';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _IntegrationSetupSheet extends StatefulWidget {
  final IntegrationInfo info;
  final WidgetRef ref;

  const _IntegrationSetupSheet({
    required this.info,
    required this.ref,
  });

  @override
  State<_IntegrationSetupSheet> createState() => _IntegrationSetupSheetState();
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Icon(widget.info.icon, size: 24),
                const SizedBox(width: 10),
                Text(
                  widget.info.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Credential fields
            ..._controllers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: entry.value,
                  obscureText: entry.key.toLowerCase().contains('token') ||
                      entry.key.toLowerCase().contains('secret') ||
                      entry.key.toLowerCase().contains('key'),
                  decoration: InputDecoration(
                    labelText: _formatFieldName(entry.key),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '${_formatFieldName(entry.key)} is required';
                    }
                    return null;
                  },
                ),
              );
            }),

            // Test result
            if (_testResult != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_testResult!
                          ? AppTheme.success
                          : Theme.of(context).colorScheme.error)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testResult!
                          ? Icons.check_circle
                          : Icons.error,
                      color: _testResult!
                          ? AppTheme.success
                          : Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _testResult!
                          ? 'Connection successful'
                          : 'Connection failed',
                      style: TextStyle(
                        color: _testResult!
                            ? AppTheme.success
                            : Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isTesting ? null : _testConnection,
                    child: _isTesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
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

  String _formatFieldName(String field) {
    // Convert camelCase to Title Case
    final result = field.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    return result[0].toUpperCase() + result.substring(1);
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      // Save first, then test
      if (_formKey.currentState!.validate()) {
        final credentials = {
          for (final entry in _controllers.entries)
            entry.key: entry.value.text.trim(),
        };
        await widget.ref
            .read(settingsRepositoryProvider)
            .saveIntegration(widget.info.service, credentials);

        final result = await widget.ref
            .read(settingsRepositoryProvider)
            .testIntegration(widget.info.service);
        setState(() => _testResult = result);
      }
    } catch (e) {
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
        for (final entry in _controllers.entries)
          entry.key: entry.value.text.trim(),
      };
      await widget.ref
          .read(settingsRepositoryProvider)
          .saveIntegration(widget.info.service, credentials);

      widget.ref.invalidate(integrationListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.info.displayName} credentials saved'),
          ),
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
