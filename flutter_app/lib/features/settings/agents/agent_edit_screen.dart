import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/agent_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/settings_providers.dart';
import '../data/settings_repository.dart';
import '../domain/agent_config.dart';

class AgentEditScreen extends ConsumerStatefulWidget {
  final String slug;

  const AgentEditScreen({super.key, required this.slug});

  @override
  ConsumerState<AgentEditScreen> createState() => _AgentEditScreenState();
}

class _AgentEditScreenState extends ConsumerState<AgentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _promptController = TextEditingController();

  String _selectedModel = 'anthropic/claude-sonnet-4-5';
  double _temperature = 0.7;
  Map<String, bool> _toolToggles = {};
  bool _isSaving = false;
  bool _initialized = false;

  static const _availableModels = [
    'anthropic/claude-opus-4',
    'anthropic/claude-sonnet-4-5',
    'anthropic/claude-haiku-4-5',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _initFromConfig(AgentConfig config) {
    if (_initialized) return;
    _initialized = true;
    _promptController.text = config.systemPrompt;
    _selectedModel = config.model;
    _temperature = config.temperature;
    _toolToggles = {for (final tool in config.tools) tool: true};
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(agentConfigProvider(widget.slug));
    final agentColor = AgentColors.forSlug(widget.slug);

    return Scaffold(
      appBar: AppBar(
        title: Text(AgentColors.displayName(widget.slug)),
        actions: [
          configAsync.whenOrNull(
                data: (_) => IconButton(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  tooltip: 'Save',
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: configAsync.when(
        data: (config) {
          _initFromConfig(config);
          return _buildForm(context, config, agentColor);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load config: $error'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(agentConfigProvider(widget.slug)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AgentConfig config,
    Color agentColor,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Agent header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: agentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: agentColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  AgentColors.icon(widget.slug),
                  color: agentColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  AgentColors.displayName(widget.slug),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: agentColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // System Prompt
          Text(
            'System Prompt',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _promptController,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Enter system prompt for this agent...',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'System prompt is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Model
          Text(
            'Model',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _availableModels.contains(_selectedModel)
                ? _selectedModel
                : _availableModels.first,
            decoration: const InputDecoration(),
            dropdownColor: AppTheme.card,
            items: _availableModels.map((model) {
              final shortName = model.split('/').last;
              return DropdownMenuItem(
                value: model,
                child: Text(shortName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedModel = value);
              }
            },
          ),
          const SizedBox(height: 24),

          // Temperature
          Row(
            children: [
              Text(
                'Temperature',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                _temperature.toStringAsFixed(2),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _temperature,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: _temperature.toStringAsFixed(2),
            onChanged: (value) {
              setState(() => _temperature = value);
            },
          ),
          const SizedBox(height: 24),

          // Tools
          Text(
            'Tools',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (_toolToggles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No tools configured for this agent',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: _toolToggles.entries.map((entry) {
                  return SwitchListTile(
                    title: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    value: entry.value,
                    onChanged: (value) {
                      setState(() {
                        _toolToggles[entry.key] = value;
                      });
                    },
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 32),

          // Save button (alternative to AppBar action)
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final enabledTools = _toolToggles.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await ref.read(settingsRepositoryProvider).updateAgentConfig(
            widget.slug,
            systemPrompt: _promptController.text.trim(),
            model: _selectedModel,
            temperature: _temperature,
            tools: enabledTools,
          );

      ref.invalidate(agentConfigProvider(widget.slug));
      ref.invalidate(agentListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent configuration saved')),
        );
        Navigator.of(context).pop();
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
