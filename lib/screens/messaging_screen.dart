import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/messaging_models.dart';
import '../services/laravel_api.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _searchController = TextEditingController();

  MessagingInboxPayload? _inbox;
  MessagingCredentialBundle? _credentialBundle;
  List<MessageTemplateItem> _templates = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String _channelFilter = '';
  String _directionFilter = '';

  bool get _isSchoolAdmin =>
      widget.session.roles.any((role) => role.toLowerCase() == 'school_admin');

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final inbox = await widget.api.messagingInbox(
        token: widget.token,
        channel: _channelFilter,
        direction: _directionFilter,
        search: _searchController.text.trim(),
      );

      MessagingCredentialBundle? credentialBundle;
      List<MessageTemplateItem> templates = const [];

      if (_isSchoolAdmin) {
        credentialBundle = await widget.api.messagingCredential(
          token: widget.token,
        );
        templates = await widget.api.messageTemplates(
          token: widget.token,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _inbox = inbox;
        _credentialBundle = credentialBundle;
        _templates = templates;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load messaging data.';
      });
    }
  }

  MessageTemplateChoice? _findTemplateChoice(
    List<MessageTemplateChoice> templates,
    int? templateId,
  ) {
    for (final item in templates) {
      if (item.id == templateId) {
        return item;
      }
    }

    return null;
  }

  Future<void> _openSendDialog() async {
    final inbox = _inbox;
    if (inbox == null) {
      return;
    }

    final recipientController = TextEditingController();
    final contactController = TextEditingController();
    final bodyController = TextEditingController();
    String channel = 'sms';
    int? templateId;
    String? dialogError;
    bool localSending = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Send Message'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: channel,
                    items: const [
                      DropdownMenuItem(value: 'sms', child: Text('SMS')),
                      DropdownMenuItem(
                        value: 'whatsapp',
                        child: Text('WhatsApp'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Channel',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: localSending
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }

                            setDialogState(() {
                              channel = value;
                              if (templateId != null) {
                                final selected = _findTemplateChoice(
                                  inbox.templates,
                                  templateId,
                                );
                                if (selected?.channel != channel) {
                                  templateId = null;
                                  bodyController.clear();
                                }
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: recipientController,
                    decoration: const InputDecoration(
                      labelText: 'Recipient number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: templateId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No template'),
                      ),
                      ...inbox.templates
                          .where((item) => item.channel == channel)
                          .map(
                            (item) => DropdownMenuItem<int?>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Template',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: localSending
                        ? null
                        : (value) {
                            setDialogState(() {
                              templateId = value;
                              final selected = _findTemplateChoice(
                                inbox.templates,
                                value,
                              );
                              if (selected != null) {
                                bodyController.text = selected.content;
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Message body',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB42318),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: localSending ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: localSending
                    ? null
                    : () async {
                        final recipient = recipientController.text.trim();
                        final body = bodyController.text.trim();

                        if (recipient.isEmpty) {
                          setDialogState(() {
                            dialogError = 'Recipient number is required.';
                          });
                          return;
                        }

                        if (templateId == null && body.isEmpty) {
                          setDialogState(() {
                            dialogError =
                                'Message body is required when no template is selected.';
                          });
                          return;
                        }

                        setDialogState(() {
                          localSending = true;
                          dialogError = null;
                        });

                        setState(() {
                          _sending = true;
                        });

                        try {
                          await widget.api.sendMessage(
                            token: widget.token,
                            payload: {
                              'message_template_id': templateId,
                              'channel': channel,
                              'recipient_number': recipient,
                              'contact_name': contactController.text.trim(),
                              'body': body,
                            },
                          );

                          if (!mounted) {
                            return;
                          }

                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Message sent successfully.'),
                              ),
                            );
                          await _loadAll();
                        } on ApiException catch (error) {
                          setDialogState(() {
                            localSending = false;
                            dialogError = error.message;
                          });
                        } catch (_) {
                          setDialogState(() {
                            localSending = false;
                            dialogError = 'Unable to send message.';
                          });
                        } finally {
                          if (mounted) {
                            setState(() {
                              _sending = false;
                            });
                          }
                        }
                      },
                child: Text(localSending ? 'Sending...' : 'Send'),
              ),
            ],
          ),
        );
      },
    );

    recipientController.dispose();
    contactController.dispose();
    bodyController.dispose();
  }

  Future<void> _openTemplateDialog({MessageTemplateItem? template}) async {
    final nameController = TextEditingController(text: template?.name ?? '');
    final contentController =
        TextEditingController(text: template?.content ?? '');
    final whatsappNameController = TextEditingController(
      text: template?.whatsappTemplateName ?? '',
    );
    final whatsappLanguageController = TextEditingController(
      text: template?.whatsappLanguage ?? '',
    );
    String channel = template?.channel.isNotEmpty == true
        ? template!.channel
        : 'sms';
    bool isActive = template?.isActive ?? true;
    String? dialogError;
    bool localSaving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(template == null ? 'New Template' : 'Edit Template'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Template name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: channel,
                    items: const [
                      DropdownMenuItem(value: 'sms', child: Text('SMS')),
                      DropdownMenuItem(
                        value: 'whatsapp',
                        child: Text('WhatsApp'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Channel',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: localSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              channel = value;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (channel == 'whatsapp') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: whatsappNameController,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp template name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: whatsappLanguageController,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp language',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: localSaving
                        ? null
                        : (value) {
                            setDialogState(() {
                              isActive = value;
                            });
                          },
                  ),
                  if (dialogError != null)
                    Text(
                      dialogError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB42318),
                          ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: localSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: localSaving
                    ? null
                    : () async {
                        final payload = <String, dynamic>{
                          'name': nameController.text.trim(),
                          'channel': channel,
                          'content': contentController.text.trim(),
                          'whatsapp_template_name':
                              whatsappNameController.text.trim(),
                          'whatsapp_language':
                              whatsappLanguageController.text.trim(),
                          'is_active': isActive,
                        };

                        setDialogState(() {
                          localSaving = true;
                          dialogError = null;
                        });

                        try {
                          if (template == null) {
                            await widget.api.createMessageTemplate(
                              token: widget.token,
                              payload: payload,
                            );
                          } else {
                            await widget.api.updateMessageTemplate(
                              token: widget.token,
                              templateId: template.id,
                              payload: payload,
                            );
                          }

                          if (!mounted) {
                            return;
                          }

                          Navigator.of(context).pop();
                          await _loadAll();
                        } on ApiException catch (error) {
                          setDialogState(() {
                            localSaving = false;
                            dialogError = error.message;
                          });
                        } catch (_) {
                          setDialogState(() {
                            localSaving = false;
                            dialogError = 'Unable to save template.';
                          });
                        }
                      },
                child: Text(localSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    contentController.dispose();
    whatsappNameController.dispose();
    whatsappLanguageController.dispose();
  }

  Future<void> _deleteTemplate(MessageTemplateItem template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete template "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.api.deleteMessageTemplate(
        token: widget.token,
        templateId: template.id,
      );

      if (!mounted) {
        return;
      }

      await _loadAll();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to delete template.';
      });
    }
  }

  Future<void> _openCredentialDialog() async {
    final existing = _credentialBundle?.credential;
    final sidController = TextEditingController(
      text: existing?.twilioAccountSid ?? '',
    );
    final tokenController = TextEditingController();
    final smsController = TextEditingController(
      text: existing?.smsFromNumber ?? '',
    );
    final whatsappController = TextEditingController(
      text: existing?.whatsappFromNumber ?? '',
    );
    bool isActive = existing?.isActive ?? true;
    String? dialogError;
    bool localSaving = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              existing == null ? 'Add Twilio Credentials' : 'Edit Twilio Credentials',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: sidController,
                    decoration: const InputDecoration(
                      labelText: 'Twilio account SID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tokenController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? 'Twilio auth token'
                          : 'Twilio auth token (leave blank to keep current)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: smsController,
                    decoration: const InputDecoration(
                      labelText: 'SMS from number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: whatsappController,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp from number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: localSaving
                        ? null
                        : (value) {
                            setDialogState(() {
                              isActive = value;
                            });
                          },
                  ),
                  if (dialogError != null)
                    Text(
                      dialogError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB42318),
                          ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: localSaving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: localSaving
                    ? null
                    : () async {
                        setDialogState(() {
                          localSaving = true;
                          dialogError = null;
                        });

                        try {
                          final payload = <String, dynamic>{
                            'twilio_account_sid': sidController.text.trim(),
                            'twilio_auth_token': tokenController.text.trim(),
                            'sms_from_number': smsController.text.trim(),
                            'whatsapp_from_number': whatsappController.text.trim(),
                            'is_active': isActive,
                          };

                          if (existing == null) {
                            await widget.api.createMessagingCredential(
                              token: widget.token,
                              payload: payload,
                            );
                          } else {
                            await widget.api.updateMessagingCredential(
                              token: widget.token,
                              credentialId: existing.id,
                              payload: payload,
                            );
                          }

                          if (!mounted) {
                            return;
                          }

                          Navigator.of(context).pop();
                          await _loadAll();
                        } on ApiException catch (error) {
                          setDialogState(() {
                            localSaving = false;
                            dialogError = error.message;
                          });
                        } catch (_) {
                          setDialogState(() {
                            localSaving = false;
                            dialogError = 'Unable to save credentials.';
                          });
                        }
                      },
                child: Text(localSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        );
      },
    );

    sidController.dispose();
    tokenController.dispose();
    smsController.dispose();
    whatsappController.dispose();
  }

  Future<void> _testCredentials() async {
    final existing = _credentialBundle?.credential;
    if (existing == null) {
      setState(() {
        _error = 'Add credentials before running a connection test.';
      });
      return;
    }

    final tokenController = TextEditingController();
    String? dialogError;
    bool localTesting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Test Twilio Credentials'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Auth token',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    dialogError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFB42318),
                        ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: localTesting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: localTesting
                    ? null
                    : () async {
                        setDialogState(() {
                          localTesting = true;
                          dialogError = null;
                        });

                        try {
                          await widget.api.testMessagingCredential(
                            token: widget.token,
                            twilioAccountSid: existing.twilioAccountSid,
                            twilioAuthToken: tokenController.text.trim(),
                          );

                          if (!mounted) {
                            return;
                          }

                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Twilio credentials are valid.'),
                              ),
                            );
                        } on ApiException catch (error) {
                          setDialogState(() {
                            localTesting = false;
                            dialogError = error.message;
                          });
                        } catch (_) {
                          setDialogState(() {
                            localTesting = false;
                            dialogError = 'Unable to test credentials.';
                          });
                        }
                      },
                child: Text(localTesting ? 'Testing...' : 'Test'),
              ),
            ],
          ),
        );
      },
    );

    tokenController.dispose();
  }

  Widget _buildFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Search messages',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _loadAll(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _channelFilter,
                items: const [
                  DropdownMenuItem(value: '', child: Text('All channels')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS')),
                  DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Channel',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _channelFilter = value ?? '';
                  });
                  _loadAll();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _directionFilter,
                items: const [
                  DropdownMenuItem(value: '', child: Text('All directions')),
                  DropdownMenuItem(value: 'outbound', child: Text('Outbound')),
                  DropdownMenuItem(value: 'inbound', child: Text('Inbound')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Direction',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _directionFilter = value ?? '';
                  });
                  _loadAll();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInboxCard(MessageLogItem item) {
    final theme = Theme.of(context);
    final directionColor = item.direction == 'inbound'
        ? const Color(0xFF0F766E)
        : const Color(0xFF1D4ED8);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: directionColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${item.direction.isEmpty ? 'message' : item.direction} ${item.channel}'.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: directionColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                item.status ?? '-',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.contactName ?? item.recipientNumber ?? item.senderNumber ?? 'Unknown contact',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            item.body,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'To: ${item.recipientNumber ?? '-'} | From: ${item.senderNumber ?? '-'}',
            style: theme.textTheme.bodySmall,
          ),
          if (item.templateName != null || item.createdByName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Template: ${item.templateName ?? '-'} | By: ${item.createdByName ?? '-'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (item.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              item.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFB42318),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCredentialsSection() {
    final theme = Theme.of(context);
    final bundle = _credentialBundle;
    final credential = bundle?.credential;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Twilio Credentials', style: theme.textTheme.titleLarge),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _openCredentialDialog(),
                icon: const Icon(Icons.edit_outlined),
                label: Text(credential == null ? 'Add' : 'Edit'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (credential == null)
            Text(
              'No active messaging credential is configured for this school yet.',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            Text(
              bundle?.schoolName ?? 'Current school',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Account SID: ${credential.twilioAccountSid}'),
            Text('SMS From: ${credential.smsFromNumber ?? '-'}'),
            Text('WhatsApp From: ${credential.whatsappFromNumber ?? '-'}'),
            Text('Auth Token Saved: ${credential.hasAuthToken ? 'Yes' : 'No'}'),
            Text('Active: ${credential.isActive ? 'Yes' : 'No'}'),
            const SizedBox(height: 8),
            Text('Incoming webhook: ${bundle?.webhooks.incoming ?? '-'}'),
            Text('Status webhook: ${bundle?.webhooks.status ?? '-'}'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _testCredentials(),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Test credentials'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplatesSection() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Templates', style: theme.textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openTemplateDialog(),
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_templates.isEmpty)
            Text(
              'No messaging templates yet.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ..._templates.map(
              (template) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.name,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          template.channel.toUpperCase(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.content,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Active: ${template.isActive ? 'Yes' : 'No'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (template.whatsappTemplateName != null)
                      Text(
                        'WA Template: ${template.whatsappTemplateName} (${template.whatsappLanguage ?? '-'})',
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _openTemplateDialog(template: template),
                          child: const Text('Edit'),
                        ),
                        OutlinedButton(
                          onPressed: () => _deleteTemplate(template),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _inbox?.items ?? const <MessageLogItem>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadAll(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed:
                _loading || _sending ? null : () => _openSendDialog(),
            icon: const Icon(Icons.send_outlined),
            tooltip: 'Send message',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _buildFilters(),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_inbox != null && !_inbox!.hasCredentials)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _isSchoolAdmin
                      ? 'Add active Twilio credentials before sending messages.'
                      : 'Messaging credentials are not active yet for this school.',
                ),
              ),
            if (_isSchoolAdmin) ...[
              _buildCredentialsSection(),
              const SizedBox(height: 16),
              _buildTemplatesSection(),
              const SizedBox(height: 16),
            ],
            Text(
              'Inbox',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('No messages found.')
            else
              ...items.map(_buildInboxCard),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
