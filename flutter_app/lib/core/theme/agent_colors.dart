import 'package:flutter/material.dart';
import 'app_theme.dart';

class AgentColors {
  // Agent identity colours — from Pencil Dev design tokens
  static const Color orchestrator = Color(0xFF7B61FF); // purple
  static const Color lawyer = Color(0xFF3B82F6);       // blue
  static const Color content = Color(0xFFF97316);      // orange
  static const Color smm = Color(0xFFEC4899);          // pink
  static const Color sales = Color(0xFF10B981);        // green

  // Surface colours delegate to the central theme tokens.
  static Color get background => AppTheme.surfacePrimary; // white
  static Color get surface => AppTheme.surfacePrimary;
  static Color get card => const Color(0xFFF3F4F6); // #F3F4F6 (chip / agent bubble bg)

  // User message bubble — foreground-primary (dark)
  static const Color userBubble = AppTheme.foregroundPrimary;

  // Semantic helpers
  static const Color inputBg = Color(0xFFF3F4F6);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color placeholder = Color(0xFF9CA3AF);
  static const Color accentPrimary = AppTheme.accentPrimary;

  static Color forAgent(String slug) => forSlug(slug);

  static Color forSlug(String slug) {
    switch (slug.toLowerCase()) {
      case 'orchestrator':
        return orchestrator;
      case 'lawyer':
        return lawyer;
      case 'content':
        return content;
      case 'smm':
        return smm;
      case 'sales':
        return sales;
      default:
        return orchestrator;
    }
  }

  static String displayName(String slug) {
    switch (slug.toLowerCase()) {
      case 'orchestrator':
        return 'Orchestrator';
      case 'lawyer':
        return 'Lawyer';
      case 'content':
        return 'Content';
      case 'smm':
        return 'SMM';
      case 'sales':
        return 'Sales';
      default:
        return slug;
    }
  }

  static IconData icon(String slug) {
    switch (slug.toLowerCase()) {
      case 'orchestrator':
        return Icons.hub_outlined;
      case 'lawyer':
        return Icons.gavel_outlined;
      case 'content':
        return Icons.edit_note_outlined;
      case 'smm':
        return Icons.campaign_outlined;
      case 'sales':
        return Icons.trending_up_outlined;
      default:
        return Icons.smart_toy_outlined;
    }
  }

  /// Tinted background for agent badges / chips on light surfaces.
  static Color backgroundForSlug(String slug) =>
      forSlug(slug).withValues(alpha: 0.12);

  static const List<({String slug, String name, Color color})> allAgents = [
    (slug: 'orchestrator', name: 'Orchestrator', color: orchestrator),
    (slug: 'lawyer', name: 'Lawyer', color: lawyer),
    (slug: 'content', name: 'Content', color: content),
    (slug: 'smm', name: 'SMM', color: smm),
    (slug: 'sales', name: 'Sales', color: sales),
  ];
}
