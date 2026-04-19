import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Tool descriptions for the UI
  static const _toolDescriptions = <String, String>{
    'web_search': 'Search the internet for information',
    'file_upload': 'Upload and process files',
    'code_exec': 'Execute code snippets',
    'notion_read': 'Read data from Notion pages',
    'notion_write': 'Write content to Notion',
    'whatsapp_send': 'Send WhatsApp messages',
    'instagram_post': 'Post content to Instagram',
    'tiktok_upload': 'Upload videos to TikTok',
    'threads_post': 'Post to Threads',
    'calendar': 'Manage calendar events',
    'email': 'Send and read emails',
  };

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
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
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
                    'EDIT AGENT',
                    style: GoogleFonts.anton(
                      fontSize: 22,
                      color: AppTheme.foregroundPrimary,
                    ),
                  ),
                  const Spacer(),
                  configAsync.whenOrNull(
                        data: (_) => GestureDetector(
                          onTap: _isSaving ? null : _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPrimary,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Save',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ) ??
                      const SizedBox.shrink(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Body
            Expanded(
              child: configAsync.when(
                data: (config) {
                  _initFromConfig(config);
                  return _buildForm(context, config, agentColor);
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AgentConfig config,
    Color agentColor,
  ) {
    final displayName = AgentColors.displayName(widget.slug);
    final initial = displayName.isNotEmpty ? displayName[0] : '?';

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Agent header banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: agentColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0x55FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: GoogleFonts.anton(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _roleDescription(widget.slug),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xCCFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Form fields
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // System Prompt
                Text(
                  'System Prompt',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foregroundPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _promptController,
                  maxLines: null,
                  minLines: 6,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.foregroundPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter system prompt for this agent...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.foregroundTertiary,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    constraints: const BoxConstraints(minHeight: 140),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(
                        color: Color(0xFFD1D5DB),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(
                        color: Color(0xFFD1D5DB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(
                        color: AppTheme.accentPrimary,
                        width: 2,
                      ),
                    ),
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foregroundPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _availableModels.contains(_selectedModel)
                        ? _selectedModel
                        : _availableModels.first,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    dropdownColor: Colors.white,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.foregroundSecondary,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.foregroundPrimary,
                    ),
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
                ),

                const SizedBox(height: 24),

                // Temperature
                Row(
                  children: [
                    Text(
                      'Temperature',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foregroundPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _temperature.toStringAsFixed(2),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    activeTrackColor: AppTheme.accentPrimary,
                    inactiveTrackColor: const Color(0xFFE5E7EB),
                    thumbColor: AppTheme.accentPrimary,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: _temperature,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (value) {
                      setState(() => _temperature = value);
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Tools
                Text(
                  'Tools',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foregroundPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (_toolToggles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No tools configured for this agent',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.foregroundSecondary,
                      ),
                    ),
                  )
                else
                  ...(_toolToggles.entries.toList().asMap().entries.map(
                    (entry) {
                      final idx = entry.key;
                      final toolEntry = entry.value;
                      final isLast =
                          idx == _toolToggles.length - 1;
                      return _ToolItem(
                        name: toolEntry.key,
                        description: _toolDescriptions[toolEntry.key] ??
                            'Agent tool',
                        isEnabled: toolEntry.value,
                        showDivider: !isLast,
                        onChanged: (value) {
                          setState(() {
                            _toolToggles[toolEntry.key] = value;
                          });
                        },
                      );
                    },
                  )),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleDescription(String slug) {
    return switch (slug.toLowerCase()) {
      'orchestrator' => 'Coordinates all agent activities',
      'lawyer' => 'Legal compliance and review',
      'content' => 'Content creation and editing',
      'smm' => 'Social media management',
      'sales' => 'Sales and customer outreach',
      _ => 'AI Agent',
    };
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

class _ToolItem extends StatelessWidget {
  final String name;
  final String description;
  final bool isEnabled;
  final bool showDivider;
  final ValueChanged<bool> onChanged;

  const _ToolItem({
    required this.name,
    required this.description,
    required this.isEnabled,
    required this.showDivider,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.foregroundPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.foregroundSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CustomToggle(
                value: isEnabled,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }
}

class _CustomToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: value ? AppTheme.accentPrimary : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
