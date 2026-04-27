class MessagingCredentialBundle {
  const MessagingCredentialBundle({
    required this.schoolName,
    required this.credential,
    required this.webhooks,
  });

  final String? schoolName;
  final MessagingCredential? credential;
  final MessagingWebhookUrls webhooks;

  factory MessagingCredentialBundle.fromJson(Map<String, dynamic> json) {
    final school = json['school'];
    final data = json['data'];
    final webhooks = json['webhooks'];

    return MessagingCredentialBundle(
      schoolName: school is Map<String, dynamic>
          ? _toNullableString(school['name'])
          : null,
      credential: data is Map<String, dynamic>
          ? MessagingCredential.fromJson(data)
          : null,
      webhooks: webhooks is Map<String, dynamic>
          ? MessagingWebhookUrls.fromJson(webhooks)
          : const MessagingWebhookUrls(
              incoming: '',
              status: '',
            ),
    );
  }
}

class MessagingCredential {
  const MessagingCredential({
    required this.id,
    required this.twilioAccountSid,
    required this.smsFromNumber,
    required this.whatsappFromNumber,
    required this.isActive,
    required this.hasAuthToken,
    required this.lastTestedAt,
  });

  final int id;
  final String twilioAccountSid;
  final String? smsFromNumber;
  final String? whatsappFromNumber;
  final bool isActive;
  final bool hasAuthToken;
  final String? lastTestedAt;

  factory MessagingCredential.fromJson(Map<String, dynamic> json) {
    return MessagingCredential(
      id: _toInt(json['id']),
      twilioAccountSid: '${json['twilio_account_sid'] ?? ''}'.trim(),
      smsFromNumber: _toNullableString(json['sms_from_number']),
      whatsappFromNumber: _toNullableString(json['whatsapp_from_number']),
      isActive: json['is_active'] == true,
      hasAuthToken: json['has_auth_token'] == true,
      lastTestedAt: _toNullableString(json['last_tested_at']),
    );
  }
}

class MessagingWebhookUrls {
  const MessagingWebhookUrls({
    required this.incoming,
    required this.status,
  });

  final String incoming;
  final String status;

  factory MessagingWebhookUrls.fromJson(Map<String, dynamic> json) {
    return MessagingWebhookUrls(
      incoming: '${json['incoming'] ?? ''}'.trim(),
      status: '${json['status'] ?? ''}'.trim(),
    );
  }
}

class MessageTemplateItem {
  const MessageTemplateItem({
    required this.id,
    required this.name,
    required this.channel,
    required this.content,
    required this.whatsappTemplateName,
    required this.whatsappLanguage,
    required this.isActive,
  });

  final int id;
  final String name;
  final String channel;
  final String content;
  final String? whatsappTemplateName;
  final String? whatsappLanguage;
  final bool isActive;

  factory MessageTemplateItem.fromJson(Map<String, dynamic> json) {
    return MessageTemplateItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      channel: '${json['channel'] ?? ''}'.trim(),
      content: '${json['content'] ?? ''}'.trim(),
      whatsappTemplateName: _toNullableString(json['whatsapp_template_name']),
      whatsappLanguage: _toNullableString(json['whatsapp_language']),
      isActive: json['is_active'] == true,
    );
  }
}

class MessagingInboxPayload {
  const MessagingInboxPayload({
    required this.items,
    required this.templates,
    required this.hasCredentials,
  });

  final List<MessageLogItem> items;
  final List<MessageTemplateChoice> templates;
  final bool hasCredentials;

  factory MessagingInboxPayload.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MessageLogItem.fromJson)
        .toList();
    final templates = (json['templates'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MessageTemplateChoice.fromJson)
        .toList();

    return MessagingInboxPayload(
      items: items,
      templates: templates,
      hasCredentials: json['has_credentials'] == true,
    );
  }
}

class MessageTemplateChoice {
  const MessageTemplateChoice({
    required this.id,
    required this.name,
    required this.channel,
    required this.content,
  });

  final int id;
  final String name;
  final String channel;
  final String content;

  factory MessageTemplateChoice.fromJson(Map<String, dynamic> json) {
    return MessageTemplateChoice(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      channel: '${json['channel'] ?? ''}'.trim(),
      content: '${json['content'] ?? ''}'.trim(),
    );
  }
}

class MessageLogItem {
  const MessageLogItem({
    required this.id,
    required this.direction,
    required this.channel,
    required this.recipientNumber,
    required this.senderNumber,
    required this.contactName,
    required this.body,
    required this.status,
    required this.errorMessage,
    required this.sentAt,
    required this.receivedAt,
    required this.templateName,
    required this.createdByName,
  });

  final int id;
  final String direction;
  final String channel;
  final String? recipientNumber;
  final String? senderNumber;
  final String? contactName;
  final String body;
  final String? status;
  final String? errorMessage;
  final String? sentAt;
  final String? receivedAt;
  final String? templateName;
  final String? createdByName;

  factory MessageLogItem.fromJson(Map<String, dynamic> json) {
    final template = json['template'];
    final createdBy = json['created_by'];

    return MessageLogItem(
      id: _toInt(json['id']),
      direction: '${json['direction'] ?? ''}'.trim(),
      channel: '${json['channel'] ?? ''}'.trim(),
      recipientNumber: _toNullableString(json['recipient_number']),
      senderNumber: _toNullableString(json['sender_number']),
      contactName: _toNullableString(json['contact_name']),
      body: '${json['body'] ?? ''}'.trim(),
      status: _toNullableString(json['status']),
      errorMessage: _toNullableString(json['error_message']),
      sentAt: _toNullableString(json['sent_at']),
      receivedAt: _toNullableString(json['received_at']),
      templateName: template is Map<String, dynamic>
          ? _toNullableString(template['name'])
          : null,
      createdByName: createdBy is Map<String, dynamic>
          ? _toNullableString(createdBy['name'])
          : null,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? 0;
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
