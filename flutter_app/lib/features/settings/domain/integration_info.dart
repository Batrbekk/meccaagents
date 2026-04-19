import 'package:flutter/material.dart';

/// A single account within an integration (used for multi-account services like WhatsApp).
class IntegrationAccount {
  final String id;
  final String? label;
  final bool isActive;
  final bool isConnected;
  final DateTime? updatedAt;

  const IntegrationAccount({
    required this.id,
    this.label,
    this.isActive = false,
    this.isConnected = false,
    this.updatedAt,
  });

  factory IntegrationAccount.fromJson(Map<String, dynamic> json) {
    return IntegrationAccount(
      id: json['id'] as String,
      label: json['label'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      isConnected: json['connected'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

class IntegrationInfo {
  final String service;
  final String displayName;
  final bool isConnected;
  final bool multiAccount;
  final String? id; // for single-account services
  final List<IntegrationAccount> accounts; // for multi-account services
  final List<String> requiredFields;

  const IntegrationInfo({
    required this.service,
    required this.displayName,
    required this.isConnected,
    this.multiAccount = false,
    this.id,
    this.accounts = const [],
    required this.requiredFields,
  });

  factory IntegrationInfo.fromJson(Map<String, dynamic> json) {
    final service = json['service'] as String;
    final isMulti = json['multiAccount'] as bool? ?? false;

    List<IntegrationAccount> accounts = [];
    if (isMulti && json['accounts'] is List) {
      accounts = (json['accounts'] as List)
          .map((e) => IntegrationAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return IntegrationInfo(
      service: service,
      displayName: json['displayName'] as String? ??
          json['display_name'] as String? ??
          _displayName(service),
      isConnected: json['connected'] as bool? ??
          json['isActive'] as bool? ??
          false,
      multiAccount: isMulti,
      id: json['id'] as String?,
      accounts: accounts,
      requiredFields: (json['requiredFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          _defaultFields(service),
    );
  }

  /// Returns the icon for a given service.
  IconData get icon => switch (service) {
        'openrouter' => Icons.auto_awesome,
        'whatsapp' => Icons.chat,
        'instagram' => Icons.camera_alt_outlined,
        'tiktok' => Icons.music_video_outlined,
        'threads' => Icons.forum_outlined,
        'notion' => Icons.description_outlined,
        _ => Icons.extension_outlined,
      };

  static String _displayName(String service) => switch (service) {
        'openrouter' => 'OpenRouter',
        'whatsapp' => 'WhatsApp',
        'instagram' => 'Instagram',
        'tiktok' => 'TikTok',
        'threads' => 'Threads',
        'notion' => 'Notion',
        _ => service,
      };

  /// Default credential fields for known services.
  static List<String> _defaultFields(String service) => switch (service) {
        'openrouter' => ['apiKey'],
        'whatsapp' => ['apiKey'],
        'instagram' => ['accessToken', 'accountId'],
        'tiktok' => ['accessToken'],
        'threads' => ['accessToken'],
        'notion' => ['integrationToken'],
        _ => ['apiKey'],
      };
}
