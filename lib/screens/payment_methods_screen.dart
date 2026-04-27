import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/finance_admin_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  List<PaymentMethodAdminItem> _methods = const [];
  bool _includeInactive = true;
  bool _loading = true;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  bool get _canEdit => widget.session.hasPermission('payments.edit');

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final methods = await widget.api.paymentMethods(
        token: widget.token,
        includeInactive: _includeInactive,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _methods = methods;
        _loading = false;
        _usingOfflineData = false;
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced payment methods.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced payment methods.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load payment methods.';
      });
    }
  }

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final json = await _cacheStore.readCacheDocument(_paymentMethodsCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = PaymentMethodsOfflineSnapshot.fromJson(json);

    if (!mounted) {
      return true;
    }

    setState(() {
      _methods = snapshot.methods;
      _includeInactive = snapshot.includeInactive;
      _loading = false;
      _usingOfflineData = true;
      _statusMessage = fallbackMessage;
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot() async {
    await _cacheStore.writeCacheDocument(
      _paymentMethodsCacheKey,
      PaymentMethodsOfflineSnapshot(
        methods: _methods,
        includeInactive: _includeInactive,
      ).toJson(),
    );
  }

  Future<void> _openEditor({PaymentMethodAdminItem? method}) async {
    if (_usingOfflineData) {
      _showMessage('Payment method changes are only available while online.');
      return;
    }

    final nameController = TextEditingController(text: method?.name ?? '');
    final sortOrderController = TextEditingController(
      text: method == null ? '0' : '${method.sortOrder}',
    );
    var isActive = method?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(method == null ? 'Add Payment Method' : 'Edit Payment Method'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sortOrderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sort Order',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  title: const Text('Active'),
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      return;
    }

    final payload = <String, dynamic>{
      'name': nameController.text.trim(),
      'sort_order': int.tryParse(sortOrderController.text.trim()) ?? 0,
      'is_active': isActive,
    };

    try {
      if (method == null) {
        await widget.api.createPaymentMethod(
          token: widget.token,
          payload: payload,
        );
      } else {
        await widget.api.updatePaymentMethod(
          token: widget.token,
          paymentMethodId: method.id,
          payload: payload,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            method == null
                ? 'Payment method created.'
                : 'Payment method updated.',
          ),
        ),
      );

      await _loadMethods();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to save payment method.');
    }
  }

  Future<void> _deleteMethod(PaymentMethodAdminItem method) async {
    if (_usingOfflineData) {
      _showMessage('Payment method changes are only available while online.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: Text('Delete ${method.name}?'),
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
      await widget.api.deletePaymentMethod(
        token: widget.token,
        paymentMethodId: method.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Payment method deleted.');
      await _loadMethods();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to delete payment method.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _methods.where((method) => method.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMethods,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Payment methods',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_canEdit)
                        FilledButton.icon(
                          onPressed: _usingOfflineData ? null : () => _openEditor(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricChip(label: 'Total', value: '${_methods.length}'),
                      _MetricChip(label: 'Active', value: '$activeCount'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _includeInactive,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show inactive methods'),
                    onChanged: (value) async {
                      setState(() {
                        _includeInactive = value;
                      });
                      await _loadMethods();
                    },
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    _PaymentMethodsOfflineBanner(
                      message: _statusMessage!,
                      onRetry: _usingOfflineData ? _loadMethods : null,
                    ),
                  ],
                  if (_error != null)
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB42318),
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_methods.isEmpty)
              _EmptyPanel(message: 'No payment methods found.')
            else
              ..._methods.map(
                (method) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2933),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MetricChip(
                              label: 'Order',
                              value: '${method.sortOrder}',
                            ),
                            _MetricChip(
                              label: 'Status',
                              value: method.isActive ? 'Active' : 'Inactive',
                            ),
                          ],
                        ),
                        if (_canEdit) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _usingOfflineData
                                    ? null
                                    : () => _openEditor(method: method),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _usingOfflineData
                                    ? null
                                    : () => _deleteMethod(method),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ],
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
}

class _PaymentMethodsOfflineBanner extends StatelessWidget {
  const _PaymentMethodsOfflineBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEAE9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                onRetry!();
              },
              child: const Text('Retry Online'),
            ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

const _paymentMethodsCacheKey = 'payment_methods_snapshot';
