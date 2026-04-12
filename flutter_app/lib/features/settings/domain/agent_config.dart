class AgentConfig {
  final String slug;
  final String displayName;
  final String systemPrompt;
  final String model;
  final double temperature;
  final List<String> tools;
  final bool isActive;

  const AgentConfig({
    required this.slug,
    required this.displayName,
    required this.systemPrompt,
    required this.model,
    required this.temperature,
    required this.tools,
    required this.isActive,
  });

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    return AgentConfig(
      slug: json['slug'] as String,
      displayName: json['displayName'] as String? ??
          json['display_name'] as String? ??
          json['name'] as String? ??
          json['slug'] as String,
      systemPrompt: json['systemPrompt'] as String? ??
          json['system_prompt'] as String? ??
          '',
      model: json['model'] as String? ?? 'anthropic/claude-sonnet-4-5',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      tools: (json['tools'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isActive:
          json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
    );
  }

  AgentConfig copyWith({
    String? slug,
    String? displayName,
    String? systemPrompt,
    String? model,
    double? temperature,
    List<String>? tools,
    bool? isActive,
  }) {
    return AgentConfig(
      slug: slug ?? this.slug,
      displayName: displayName ?? this.displayName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      tools: tools ?? this.tools,
      isActive: isActive ?? this.isActive,
    );
  }
}
