import 'package:flutter/material.dart';

class IntegrationInfo {
  final String service;
  final String displayName;
  final bool isConnected;
  final List<String> requiredFields;

  const IntegrationInfo({
    required this.service,
    required this.displayName,
    required this.isConnected,
    required this.requiredFields,
  });

  factory IntegrationInfo.fromJson(Map<String, dynamic> json) {
    return IntegrationInfo(
      service: json['service'] as String,
      displayName: json['displayName'] as String? ??
          json['display_name'] as String? ??
          json['service'] as String,
      isConnected: json['isConnected'] as bool? ??
          json['connected'] as bool? ??
          json['is_connected'] as bool? ??
          json['isActive'] as bool? ??
          false,
      requiredFields: (json['requiredFields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          _defaultFields(json['service'] as String),
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

  /// Default credential fields for known services.
  static List<String> _defaultFields(String service) => switch (service) {
        'openrouter' => ['apiKey'],
        'whatsapp' => ['phoneNumberId', 'accessToken'],
        'instagram' => ['accessToken', 'accountId'],
        'tiktok' => ['accessToken'],
        'threads' => ['accessToken'],
        'notion' => ['integrationToken'],
        _ => ['apiKey'],
      };
}
