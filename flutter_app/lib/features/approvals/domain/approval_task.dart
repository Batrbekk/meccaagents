class ApprovalTask {
  final String id;
  final String agentSlug;
  final String actionType;
  final String status;
  final Map<String, dynamic> payload;
  final String? notes;
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  const ApprovalTask({
    required this.id,
    required this.agentSlug,
    required this.actionType,
    required this.status,
    required this.payload,
    this.notes,
    required this.requestedAt,
    this.resolvedAt,
  });

  factory ApprovalTask.fromJson(Map<String, dynamic> json) {
    return ApprovalTask(
      id: json['id'] as String,
      agentSlug: json['agentSlug'] as String? ?? json['agent_slug'] as String,
      actionType:
          json['actionType'] as String? ?? json['action_type'] as String,
      status: json['status'] as String,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      notes: json['notes'] as String?,
      requestedAt: DateTime.parse(
        json['requestedAt'] as String? ??
            json['requested_at'] as String? ??
            json['createdAt'] as String? ??
            json['created_at'] as String,
      ),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : json['resolved_at'] != null
              ? DateTime.parse(json['resolved_at'] as String)
              : null,
    );
  }

  /// Returns a human-readable label for the action type.
  String get actionLabel {
    return switch (actionType) {
      'publish_instagram' => 'Publish to Instagram',
      'publish_tiktok' => 'Publish to TikTok',
      'publish_threads' => 'Publish to Threads',
      'send_whatsapp' => 'Send WhatsApp Message',
      'update_notion' => 'Update Notion Page',
      'send_email' => 'Send Email',
      _ => actionType.replaceAll('_', ' '),
    };
  }

  /// Returns a short preview of the payload content.
  String get payloadPreview {
    final text = payload['text'] as String? ??
        payload['content'] as String? ??
        payload['message'] as String? ??
        payload['caption'] as String? ??
        payload.toString();
    if (text.length > 100) {
      return '${text.substring(0, 100)}...';
    }
    return text;
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  ApprovalTask copyWith({
    String? id,
    String? agentSlug,
    String? actionType,
    String? status,
    Map<String, dynamic>? payload,
    String? notes,
    DateTime? requestedAt,
    DateTime? resolvedAt,
  }) {
    return ApprovalTask(
      id: id ?? this.id,
      agentSlug: agentSlug ?? this.agentSlug,
      actionType: actionType ?? this.actionType,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      notes: notes ?? this.notes,
      requestedAt: requestedAt ?? this.requestedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
