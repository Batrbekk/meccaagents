import 'package:flutter/material.dart';

class AgentColors {
  static const Color orchestrator = Color(0xFF9E9E9E);
  static const Color lawyer = Color(0xFF2196F3);
  static const Color content = Color(0xFF009688);
  static const Color smm = Color(0xFFFF7043);
  static const Color sales = Color(0xFFFFC107);

  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color card = Color(0xFF1C2333);
  static const Color userBubble = Color(0xFF2979FF);

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
