import 'package:flutter/material.dart';

import '../models/fee_models.dart';
import '../services/laravel_api.dart';

class FeeStructuresScreen extends StatefulWidget {
  const FeeStructuresScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<FeeStructuresScreen> createState() => _FeeStructuresScreenState();
}

class _FeeStructuresScreenState extends State<FeeStructuresScreen> {
  List<AcademicYearOption> _years = const [];
  List<FeeStructureItem> _fees = const [];
  int? _selectedYearId;
  bool _loadingMeta = true;
  bool _loadingFees = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.activeAcademicYear(widget.token),
      ]);

      final years = results[0] as List<AcademicYearOption>;
      final activeYearId = (results[1] as dynamic).id as int;
      final selectedYearId = years.any((year) => year.id == activeYearId)
          ? activeYearId
          : (years.isNotEmpty ? years.first.id : null);

      if (!mounted) {
        return;
      }

      setState(() {
        _years = years;
        _selectedYearId = selectedYearId;
        _loadingMeta = false;
      });

      if (selectedYearId != null) {
        await _loadFees();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = 'Unable to load fee structure setup.';
      });
    }
  }

  Future<void> _loadFees() async {
    final yearId = _selectedYearId;
    if (yearId == null) {
      setState(() {
        _fees = const [];
      });
      return;
    }

    setState(() {
      _loadingFees = true;
      _error = null;
    });

    try {
      final fees = await widget.api.feeStructures(
        token: widget.token,
        academicYearId: yearId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _fees = fees;
        _loadingFees = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _fees = const [];
        _loadingFees = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _fees = const [];
        _loadingFees = false;
        _error = 'Unable to load fee structures.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mandatoryCount = _fees.where((fee) => fee.isMandatory).length;
    final activeCount = _fees.where((fee) => fee.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFees,
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
                        Text('Academic year',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedYearId,
                          decoration: const InputDecoration(
                            labelText: 'Select academic year',
                            border: OutlineInputBorder(),
                          ),
                          items: _years
                              .map(
                                (year) => DropdownMenuItem<int>(
                                  value: year.id,
                                  child: Text(year.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedYearId = value;
                            });
                            await _loadFees();
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB42318),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatChip(
                            label: 'Structures', value: '${_fees.length}'),
                        _StatChip(label: 'Mandatory', value: '$mandatoryCount'),
                        _StatChip(label: 'Active', value: '$activeCount'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_loadingFees)
                    const Center(child: CircularProgressIndicator())
                  else if (_fees.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'No fee structures found for the selected academic year.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  else
                    ..._fees.map(_buildFeeCard),
                ],
              ),
            ),
    );
  }

  Widget _buildFeeCard(FeeStructureItem fee) {
    return Padding(
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
              fee.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatusBadge(
                  label: fee.isMandatory ? 'Mandatory' : 'Optional',
                  color: fee.isMandatory
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFE0F2FE),
                ),
                _StatusBadge(
                  label: fee.isActive ? 'Active' : 'Inactive',
                  color: fee.isActive
                      ? const Color(0xFFFFF3C4)
                      : const Color(0xFFF1F5F9),
                ),
                if (fee.frequency != null)
                  _StatusBadge(
                    label: fee.frequency!,
                    color: const Color(0xFFF3E8FF),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Amount: ${_formatMoney(fee.amount)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (fee.feeTypeName != null) ...[
              const SizedBox(height: 6),
              Text(
                'Type: ${fee.feeTypeName}',
                style: const TextStyle(color: Color(0xFF52606D)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2933),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

String _formatMoney(num value) {
  return value.toStringAsFixed(2);
}
