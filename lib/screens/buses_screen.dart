import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/student_management_models.dart';
import '../models/transport_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import '../services/offline_sync_queue.dart';

class BusesScreen extends StatefulWidget {
  const BusesScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<BusesScreen> createState() => _BusesScreenState();
}

class _BusesScreenState extends State<BusesScreen> {
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();

  List<BusItem> _buses = const [];
  BusStudentReport? _report;
  List<TransportStudentDirectoryItem> _studentDirectory = const [];
  Map<int, List<BusStudentItem>> _assignedStudentsByBus = const {};
  Map<int, List<int>> _pendingAssignments = const {};
  bool _loading = true;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  bool get _canCreate => widget.session.hasPermission('buses.create');
  bool get _canEdit => widget.session.hasPermission('buses.edit');
  bool get _canDelete => widget.session.hasPermission('buses.delete');
  bool get _canAssign => widget.session.hasPermission('buses.assign');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final results = await Future.wait([
        widget.api.buses(token: widget.token),
        widget.api.busStudentReport(token: widget.token),
      ]);

      final buses = results[0] as List<BusItem>;
      final report = results[1] as BusStudentReport;
      final pendingAssignments = await _loadPendingAssignments();
      var assignedStudentsByBus =
          Map<int, List<BusStudentItem>>.from(_assignedStudentsByBus);

      if (!mounted) {
        return;
      }

      setState(() {
        _buses = buses;
        _report = report;
        _assignedStudentsByBus = assignedStudentsByBus;
        _pendingAssignments = pendingAssignments;
        _loading = false;
        _usingOfflineData = false;
        _statusMessage = pendingAssignments.isEmpty
            ? null
            : 'Some bus assignments are still queued for sync.';
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced transport data.',
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
        'Offline mode: showing last synced transport data.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load buses.';
      });
    }
  }

  Future<Map<int, List<int>>> _loadPendingAssignments() async {
    final queued = await _syncQueue.readQueue();
    final pending = <int, List<int>>{};

    for (final item in queued.where(
      (entry) => entry.key.startsWith(busAssignQueuePrefix),
    )) {
      final busId = _toInt(item.payload['bus_id']);
      if (busId <= 0) {
        continue;
      }
      pending[busId] = (item.payload['student_ids'] as List<dynamic>? ?? const [])
          .map(_toInt)
          .where((value) => value > 0)
          .toList();
    }

    return pending;
  }

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final json = await _cacheStore.readCacheDocument(_transportCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = TransportOfflineSnapshot.fromJson(json);

    if (!mounted) {
      return true;
    }

    setState(() {
      _buses = snapshot.buses;
      _report = snapshot.report;
      _studentDirectory = snapshot.studentDirectory;
      _assignedStudentsByBus = snapshot.assignedStudentsByBus;
      _pendingAssignments = snapshot.pendingAssignments;
      _loading = false;
      _usingOfflineData = true;
      _statusMessage = snapshot.pendingAssignments.isEmpty
          ? fallbackMessage
          : 'Offline mode: showing cached transport data with queued assignments.';
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot() async {
    await _cacheStore.writeCacheDocument(
      _transportCacheKey,
      TransportOfflineSnapshot(
        buses: _buses,
        report: _report,
        studentDirectory: _studentDirectory,
        assignedStudentsByBus: _assignedStudentsByBus,
        pendingAssignments: _pendingAssignments,
      ).toJson(),
    );
  }

  Future<void> _openBusEditor({BusItem? bus}) async {
    final busNumberController =
        TextEditingController(text: bus?.busNumber ?? '');
    final routeController = TextEditingController(text: bus?.route ?? '');
    final capacityController = TextEditingController(
      text: bus?.capacity == null ? '' : '${bus!.capacity}',
    );
    final contactController = TextEditingController(text: bus?.contact ?? '');
    final driverNameController =
        TextEditingController(text: bus?.driverName ?? '');
    final driverPhoneController =
        TextEditingController(text: bus?.driverPhone ?? '');
    final driverLicenceController =
        TextEditingController(text: bus?.driverLicence ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(bus == null ? 'Add Bus' : 'Edit Bus'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: busNumberController,
                decoration: const InputDecoration(
                  labelText: 'Bus Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: routeController,
                decoration: const InputDecoration(
                  labelText: 'Route',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: driverNameController,
                decoration: const InputDecoration(
                  labelText: 'Driver Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: driverPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Driver Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: driverLicenceController,
                decoration: const InputDecoration(
                  labelText: 'Driver Licence',
                  border: OutlineInputBorder(),
                ),
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
    );

    if (saved != true) {
      return;
    }

    final payload = <String, dynamic>{
      'bus_number': busNumberController.text.trim(),
      'route': routeController.text.trim().isEmpty
          ? null
          : routeController.text.trim(),
      'capacity': int.tryParse(capacityController.text.trim()),
      'contact': contactController.text.trim().isEmpty
          ? null
          : contactController.text.trim(),
      'driver_name': driverNameController.text.trim().isEmpty
          ? null
          : driverNameController.text.trim(),
      'driver_phone': driverPhoneController.text.trim().isEmpty
          ? null
          : driverPhoneController.text.trim(),
      'driver_licence': driverLicenceController.text.trim().isEmpty
          ? null
          : driverLicenceController.text.trim(),
    };

    try {
      if (bus == null) {
        await widget.api.createBus(
          token: widget.token,
          payload: payload,
        );
      } else {
        await widget.api.updateBus(
          token: widget.token,
          busId: bus.id,
          payload: payload,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(bus == null ? 'Bus created.' : 'Bus updated.');
      await _loadData();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to save bus.');
    }
  }

  Future<void> _deleteBus(BusItem bus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bus'),
        content: Text('Delete ${bus.busNumber}?'),
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
      await widget.api.deleteBus(
        token: widget.token,
        busId: bus.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Bus deleted.');
      await _loadData();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to delete bus.');
    }
  }

  Future<void> _showStudents(BusItem bus) async {
    try {
      final students = await widget.api.busStudents(
        token: widget.token,
        busId: bus.id,
      );

      _assignedStudentsByBus = {
        ..._assignedStudentsByBus,
        bus.id: students,
      };
      await _writeSnapshot();

      if (!mounted) {
        return;
      }

      await _showStudentsDialog(bus, students);
    } on ApiException catch (error) {
      final cachedStudents = _assignedStudentsByBus[bus.id];
      if (cachedStudents != null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _usingOfflineData = true;
          _statusMessage =
              'Offline mode: showing cached student assignments for ${bus.busNumber}.';
        });
        await _showStudentsDialog(bus, cachedStudents);
        return;
      }

      _showMessage(error.message);
    } catch (_) {
      final cachedStudents = _assignedStudentsByBus[bus.id];
      if (cachedStudents != null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _usingOfflineData = true;
          _statusMessage =
              'Offline mode: showing cached student assignments for ${bus.busNumber}.';
        });
        await _showStudentsDialog(bus, cachedStudents);
        return;
      }

      _showMessage('Unable to load bus students.');
    }
  }

  Future<void> _showStudentsDialog(
    BusItem bus,
    List<BusStudentItem> students,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${bus.busNumber} Students'),
        content: SizedBox(
          width: 520,
          height: 420,
          child: students.isEmpty
              ? const Text('No students assigned.')
              : ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(student.rollNumber ?? '-'),
                        Text(
                          '${student.levelName ?? '-'} / ${student.className ?? '-'}',
                        ),
                        if (student.phone != null) Text(student.phone!),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignStudents(BusItem bus) async {
    late final List<TransportStudentDirectoryItem> studentDirectory;
    late final List<BusStudentItem> assignedStudents;

    try {
      final results = await Future.wait([
        widget.api.studentListReport(
          token: widget.token,
          queryParameters: const {'filter': 'all'},
        ),
        widget.api.busStudents(
          token: widget.token,
          busId: bus.id,
        ),
      ]);

      final report = results[0] as StudentListReport;
      assignedStudents = results[1] as List<BusStudentItem>;
      studentDirectory = report.students
          .map(
            (student) => TransportStudentDirectoryItem(
              id: student.id,
              name: student.name,
              rollNumber: student.rollNumber,
              gender: student.gender,
              levelName: student.levelName,
              className: student.className,
              section: student.section,
              phone: student.phone,
            ),
          )
          .toList();

      _studentDirectory = studentDirectory;
      _assignedStudentsByBus = {
        ..._assignedStudentsByBus,
        bus.id: assignedStudents,
      };
      await _writeSnapshot();
    } on ApiException catch (_) {
      if (_studentDirectory.isEmpty) {
        _showMessage('Student directory is not available offline yet.');
        return;
      }

      studentDirectory = _studentDirectory;
      assignedStudents = _assignedStudentsByBus[bus.id] ?? const [];
      if (!mounted) {
        return;
      }

      setState(() {
        _usingOfflineData = true;
        _statusMessage =
            'Offline mode: assigning from cached student and bus data.';
      });
    } catch (_) {
      if (_studentDirectory.isEmpty) {
        _showMessage('Unable to load students for assignment.');
        return;
      }

      studentDirectory = _studentDirectory;
      assignedStudents = _assignedStudentsByBus[bus.id] ?? const [];
      if (!mounted) {
        return;
      }

      setState(() {
        _usingOfflineData = true;
        _statusMessage =
            'Offline mode: assigning from cached student and bus data.';
      });
    }

    final selected = assignedStudents.map((item) => item.id).toSet();
    final searchController = TextEditingController();

    if (!mounted) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchController.text.trim().toLowerCase();
          final filteredStudents = studentDirectory.where((student) {
            if (query.isEmpty) {
              return true;
            }

            return student.name.toLowerCase().contains(query) ||
                (student.rollNumber ?? '').toLowerCase().contains(query) ||
                (student.className ?? '').toLowerCase().contains(query);
          }).toList();

          return AlertDialog(
            title: Text('Assign Students to ${bus.busNumber}'),
            content: SizedBox(
              width: 560,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search students',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) {
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        final checked = selected.contains(student.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selected.add(student.id);
                              } else {
                                selected.remove(student.id);
                              }
                            });
                          },
                          title: Text(student.name),
                          subtitle: Text(
                            '${student.rollNumber ?? '-'} - ${student.levelName ?? '-'} / ${student.className ?? '-'}',
                          ),
                        );
                      },
                    ),
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
          );
        },
      ),
    );

    if (saved != true) {
      return;
    }

    final sortedIds = selected.toList()..sort();

    try {
      await widget.api.assignBusStudents(
        token: widget.token,
        busId: bus.id,
        studentIds: sortedIds,
      );
      await _syncQueue.remove('$busAssignQueuePrefix${bus.id}');

      _pendingAssignments = {
        ..._pendingAssignments,
      }..remove(bus.id);

      if (!mounted) {
        return;
      }

      _showMessage('Bus assignments updated.');
      await _loadData();
    } on ApiException catch (_) {
      await _queueAssignment(bus, studentDirectory, sortedIds);
      _showMessage('Assignment saved offline. Sync will retry later.');
    } catch (_) {
      await _queueAssignment(bus, studentDirectory, sortedIds);
      _showMessage('Assignment saved offline. Sync will retry later.');
    }
  }

  Future<void> _queueAssignment(
    BusItem bus,
    List<TransportStudentDirectoryItem> studentDirectory,
    List<int> selectedIds,
  ) async {
    final updatedAssignedStudents = _buildAssignedStudents(
      studentDirectory: studentDirectory,
      selectedIds: selectedIds,
    );
    final updatedPendingAssignments = {
      ..._pendingAssignments,
      bus.id: selectedIds,
    };

    if (!mounted) {
      _assignedStudentsByBus = {
        ..._assignedStudentsByBus,
        bus.id: updatedAssignedStudents,
      };
      _pendingAssignments = updatedPendingAssignments;
      _report = _buildReportFromLocalAssignments();
      _studentDirectory = studentDirectory;
      await _writeSnapshot();
      return;
    }

    setState(() {
      _assignedStudentsByBus = {
        ..._assignedStudentsByBus,
        bus.id: updatedAssignedStudents,
      };
      _pendingAssignments = updatedPendingAssignments;
      _report = _buildReportFromLocalAssignments();
      _studentDirectory = studentDirectory;
      _usingOfflineData = true;
      _statusMessage =
          'Offline mode: bus assignment changes are queued for sync.';
    });

    await _syncQueue.upsert(
      OfflineSyncOperation(
        key: '$busAssignQueuePrefix${bus.id}',
        type: 'bus_assign',
        payload: {
          'bus_id': bus.id,
          'student_ids': selectedIds,
        },
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    await _writeSnapshot();
  }

  List<BusStudentItem> _buildAssignedStudents({
    required List<TransportStudentDirectoryItem> studentDirectory,
    required List<int> selectedIds,
  }) {
    final lookup = {
      for (final student in studentDirectory) student.id: student,
    };

    return selectedIds
        .map((id) => lookup[id])
        .whereType<TransportStudentDirectoryItem>()
        .map(
          (student) => BusStudentItem(
            id: student.id,
            name: student.name,
            phone: student.phone,
            rollNumber: student.rollNumber,
            levelName: student.levelName,
            className: student.className,
            section: student.section,
            gender: student.gender,
          ),
        )
        .toList();
  }

  BusStudentReport _buildReportFromLocalAssignments() {
    return BusStudentReport(
      buses: _buses
          .map(
            (bus) => BusStudentReportGroup(
              id: bus.id,
              name: bus.busNumber,
              route: bus.route,
              students: _assignedStudentsByBus[bus.id] ?? const [],
            ),
          )
          .toList(),
      count: _assignedStudentsByBus.values.fold<int>(
        0,
        (sum, students) => sum + students.length,
      ),
      generatedAt: _report?.generatedAt,
    );
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
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport / Buses'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
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
                          'Transport fleet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_canCreate)
                        FilledButton.icon(
                          onPressed: () => _openBusEditor(),
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
                      _BusMetric(label: 'Buses', value: '${_buses.length}'),
                      _BusMetric(
                        label: 'Assigned Students',
                        value: report == null ? '0' : '${report.count}',
                      ),
                      if (_pendingAssignments.isNotEmpty)
                        _BusMetric(
                          label: 'Pending Sync',
                          value: '${_pendingAssignments.length}',
                        ),
                    ],
                  ),
                  if (report?.generatedAt != null) ...[
                    const SizedBox(height: 10),
                    Text('Report updated: ${report!.generatedAt}'),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    _TransportStatusBanner(
                      message: _statusMessage!,
                      offline: _usingOfflineData || _pendingAssignments.isNotEmpty,
                      onRetry: _usingOfflineData || _pendingAssignments.isNotEmpty
                          ? _loadData
                          : null,
                    ),
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
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_buses.isEmpty)
              _BusEmpty(message: 'No buses found.')
            else ...[
              if (report != null && report.buses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
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
                          'Student report snapshot',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: report.buses
                              .map(
                                (group) => _BusMetric(
                                  label: group.name,
                                  value: '${group.students.length}',
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ..._buses.map(
                (bus) => Padding(
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                bus.busNumber,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2933),
                                ),
                              ),
                            ),
                            if (_pendingAssignments.containsKey(bus.id))
                              const Chip(
                                label: Text('Pending Sync'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (bus.route != null)
                              _BusMetric(label: 'Route', value: bus.route!),
                            if (bus.capacity != null)
                              _BusMetric(
                                label: 'Capacity',
                                value: '${bus.capacity}',
                              ),
                            if (bus.driverName != null)
                              _BusMetric(label: 'Driver', value: bus.driverName!),
                          ],
                        ),
                        if (bus.contact != null || bus.driverPhone != null) ...[
                          const SizedBox(height: 10),
                          if (bus.contact != null) Text('Contact: ${bus.contact}'),
                          if (bus.driverPhone != null)
                            Text('Driver Phone: ${bus.driverPhone}'),
                          if (bus.driverLicence != null)
                            Text('Licence: ${bus.driverLicence}'),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showStudents(bus),
                              icon: const Icon(Icons.groups_outlined),
                              label: const Text('Students'),
                            ),
                            if (_canAssign)
                              OutlinedButton.icon(
                                onPressed: () => _assignStudents(bus),
                                icon:
                                    const Icon(Icons.person_add_alt_1_outlined),
                                label: const Text('Assign'),
                              ),
                            if (_canEdit)
                              OutlinedButton.icon(
                                onPressed: () => _openBusEditor(bus: bus),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                            if (_canDelete)
                              OutlinedButton.icon(
                                onPressed: () => _deleteBus(bus),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransportStatusBanner extends StatelessWidget {
  const _TransportStatusBanner({
    required this.message,
    required this.offline,
    required this.onRetry,
  });

  final String message;
  final bool offline;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: offline
            ? const Color(0xFFFBEAE9)
            : const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            offline ? Icons.cloud_off_outlined : Icons.info_outline,
            color: offline ? const Color(0xFFB42318) : const Color(0xFF175CD3),
          ),
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

class _BusMetric extends StatelessWidget {
  const _BusMetric({
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

class _BusEmpty extends StatelessWidget {
  const _BusEmpty({required this.message});

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

const _transportCacheKey = 'transport_snapshot';

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? 0;
}
