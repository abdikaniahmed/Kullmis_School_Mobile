import 'package:flutter/material.dart';

import '../models/exam_models.dart';
import '../models/fee_models.dart';
import '../models/main_attendance_models.dart';
import '../models/student_list_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import '../services/offline_sync_queue.dart';

class ExamMarkEntryScreen extends StatefulWidget {
  const ExamMarkEntryScreen({
    super.key,
    required this.api,
    required this.token,
    required this.canViewMarks,
  });

  final LaravelApi api;
  final String token;
  final bool canViewMarks;

  @override
  State<ExamMarkEntryScreen> createState() => _ExamMarkEntryScreenState();
}

class _ExamMarkEntryScreenState extends State<ExamMarkEntryScreen> {
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();

  List<AcademicYearOption> _years = const [];
  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  List<ExamSubjectOption> _subjects = const [];
  List<ExamTermOption> _terms = const [];
  List<ExamOption> _exams = const [];
  List<StudentListItem> _students = const [];
  final Map<int, _MarkDraftControllers> _drafts = {};

  int? _selectedYearId;
  int? _selectedLevelId;
  int? _selectedClassId;
  int? _selectedTermId;
  int? _selectedExamId;
  int? _selectedSubjectId;
  bool _loadingSetup = true;
  bool _loadingRoster = false;
  bool _saving = false;
  bool _usingOfflineData = false;
  bool _hasPendingDraft = false;
  String? _statusMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  List<MainAttendanceClass> get _filteredClasses {
    if (_selectedLevelId == null) {
      return _classes;
    }

    return _classes
        .where((entry) => entry.levelId == _selectedLevelId)
        .toList();
  }

  ExamOption? get _selectedExam {
    final examId = _selectedExamId;
    if (examId == null) {
      return null;
    }

    for (final exam in _exams) {
      if (exam.id == examId) {
        return exam;
      }
    }

    return null;
  }

  Future<void> _loadSetup() async {
    setState(() {
      _loadingSetup = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.activeAcademicYear(widget.token),
        widget.api.attendanceLevels(widget.token),
        widget.api.schoolClasses(token: widget.token, includeAll: true),
        widget.api.subjects(token: widget.token),
      ]);

      final years = results[0] as List<AcademicYearOption>;
      final activeYear = results[1] as ActiveAcademicYear;
      final levels = results[2] as List<MainAttendanceLevel>;
      final classes = results[3] as List<MainAttendanceClass>;
      final subjects = results[4] as List<ExamSubjectOption>;

      final selectedYearId = years.any((entry) => entry.id == activeYear.id)
          ? activeYear.id
          : (years.isNotEmpty ? years.first.id : null);
      final firstClass = classes.isNotEmpty ? classes.first : null;
      final selectedLevelId =
          firstClass?.levelId ?? (levels.isNotEmpty ? levels.first.id : null);
      final selectedClassId = firstClass?.id;
      final selectedSubjectId = subjects.isNotEmpty ? subjects.first.id : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _years = years;
        _levels = levels;
        _classes = classes;
        _subjects = subjects;
        _selectedYearId = selectedYearId;
        _selectedLevelId = selectedLevelId;
        _selectedClassId = selectedClassId;
        _selectedSubjectId = selectedSubjectId;
        _loadingSetup = false;
        _usingOfflineData = false;
        _hasPendingDraft = false;
      });

      await _loadTermsAndExams();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        fallbackMessage: 'Offline mode: showing last synced mark-entry data.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSetup = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        fallbackMessage: 'Offline mode: showing last synced mark-entry data.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSetup = false;
        _error = 'Unable to load exam mark entry setup.';
      });
    }
  }

  Future<void> _loadTermsAndExams() async {
    final yearId = _selectedYearId;
    if (yearId == null) {
      return;
    }

    try {
      final terms = await widget.api.terms(
        token: widget.token,
        academicYearId: yearId,
      );
      final selectedTermId = terms.isNotEmpty ? terms.first.id : null;
      final exams = await widget.api.exams(
        token: widget.token,
        academicYearId: yearId,
        termId: selectedTermId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _terms = terms;
        _selectedTermId = selectedTermId;
        _exams = exams;
        _selectedExamId = exams.isNotEmpty ? exams.first.id : null;
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    }
  }

  Future<void> _refreshExams() async {
    final yearId = _selectedYearId;
    if (yearId == null) {
      return;
    }

    try {
      final exams = await widget.api.exams(
        token: widget.token,
        academicYearId: yearId,
        termId: _selectedTermId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _exams = exams;
        _selectedExamId = exams.any((entry) => entry.id == _selectedExamId)
            ? _selectedExamId
            : (exams.isNotEmpty ? exams.first.id : null);
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    }
  }

  Future<List<StudentListItem>> _loadAllStudents({
    required int classId,
    int? levelId,
  }) async {
    final students = <StudentListItem>[];
    var page = 1;
    var hasNext = true;

    while (hasNext) {
      final result = await widget.api.studentList(
        token: widget.token,
        page: page,
        levelId: levelId,
        classId: classId,
      );

      students.addAll(result.items);
      hasNext = result.hasNextPage;
      page += 1;
    }

    return students;
  }

  Future<void> _loadRoster() async {
    final classId = _selectedClassId;
    final examId = _selectedExamId;
    final subjectId = _selectedSubjectId;

    if (classId == null || examId == null || subjectId == null) {
      _showMessage('Select a class, exam, and subject first.');
      return;
    }

    setState(() {
      _loadingRoster = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final students = await _loadAllStudents(
        classId: classId,
        levelId: _selectedLevelId,
      );
      final existingMarks = widget.canViewMarks
          ? await widget.api.classMarks(
              token: widget.token,
              classId: classId,
              examId: examId,
              subjectId: subjectId,
            )
          : const <ClassMarkEntry>[];
      final marksByStudent = {
        for (final entry in existingMarks) entry.studentId: entry,
      };

      if (!mounted) {
        return;
      }

      _replaceDrafts(
        students,
        marksByStudent: marksByStudent,
      );

      setState(() {
        _students = students;
        _loadingRoster = false;
        _usingOfflineData = false;
        _hasPendingDraft = false;
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        fallbackMessage: 'Offline mode: showing last synced mark sheet.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      _disposeDrafts();
      setState(() {
        _students = const [];
        _loadingRoster = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        fallbackMessage: 'Offline mode: showing last synced mark sheet.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      _disposeDrafts();
      setState(() {
        _students = const [];
        _loadingRoster = false;
        _error = 'Unable to load class marks.';
      });
    }
  }

  Future<void> _saveMarks() async {
    final classId = _selectedClassId;
    final subjectId = _selectedSubjectId;
    final exam = _selectedExam;

    if (classId == null || subjectId == null || exam == null) {
      return;
    }

    final drafts = <ExamMarkDraft>[];
    for (final student in _students) {
      final controllers = _drafts[student.id];
      if (controllers == null) {
        continue;
      }

      final rawMark = controllers.markController.text.trim();
      if (rawMark.isEmpty) {
        continue;
      }

      final mark = double.tryParse(rawMark);
      if (mark == null) {
        _showMessage('Enter a valid mark for ${student.name}.');
        return;
      }

      if (mark < 0 || mark > exam.maxMark) {
        _showMessage(
          'Marks for ${student.name} must be between 0 and ${_formatMark(exam.maxMark)}.',
        );
        return;
      }

      final comment = controllers.commentController.text.trim();
      drafts.add(
        ExamMarkDraft(
          studentId: student.id,
          subjectId: subjectId,
          examId: exam.id,
          mark: mark,
          comment: comment.isEmpty ? null : comment,
        ),
      );
    }

    if (drafts.isEmpty) {
      _showMessage('Enter at least one mark before saving.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.api.saveBulkMarks(
        token: widget.token,
        classId: classId,
        marks: drafts,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hasPendingDraft = false;
        _usingOfflineData = false;
        _statusMessage = null;
      });

      await _syncQueue.remove(_queueKeyForMarks());

      await _writeSnapshot();
      _showMessage('Exam marks saved.');
      await _loadRoster();
      setState(() {
        _saving = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      await _writeSnapshot(
        pendingDraft: true,
        statusMessage:
            'Offline draft saved on this device. Sync marks again when the server is reachable.',
      );
      await _syncQueue.upsert(
        OfflineSyncOperation(
          key: _queueKeyForMarks(),
          type: 'exam_marks_save',
          payload: {
            'class_id': classId,
            'marks': drafts.map((item) => item.toJson()).toList(),
          },
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      _showMessage(error.message);
      setState(() {
        _saving = false;
        _usingOfflineData = true;
        _hasPendingDraft = true;
        _statusMessage =
            'Offline draft saved on this device. Sync marks again when the server is reachable.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _writeSnapshot(
        pendingDraft: true,
        statusMessage:
            'Offline draft saved on this device. Sync marks again when the server is reachable.',
      );
      await _syncQueue.upsert(
        OfflineSyncOperation(
          key: _queueKeyForMarks(),
          type: 'exam_marks_save',
          payload: {
            'class_id': classId,
            'marks': drafts.map((item) => item.toJson()).toList(),
          },
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      _showMessage('Exam marks saved locally as a draft.');
      setState(() {
        _saving = false;
        _usingOfflineData = true;
        _hasPendingDraft = true;
        _statusMessage =
            'Offline draft saved on this device. Sync marks again when the server is reachable.';
      });
    }
  }

  void _replaceDrafts(
    List<StudentListItem> students, {
    Map<int, ClassMarkEntry> marksByStudent = const {},
    Map<int, ExamMarkDraftState> draftStates = const {},
  }) {
    _disposeDrafts();

    for (final student in students) {
      final savedDraft = draftStates[student.id];
      final existing = marksByStudent[student.id];
      _drafts[student.id] = _MarkDraftControllers(
        mark: savedDraft?.mark ??
            (existing?.mark == null ? '' : _formatMark(existing!.mark!)),
        comment: savedDraft?.comment ?? existing?.comment ?? '',
      );
    }
  }

  Future<bool> _restoreSnapshot({
    required String fallbackMessage,
  }) async {
    final json = await _cacheStore.readCacheDocument(_examMarkEntryCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = ExamMarkEntryOfflineSnapshot.fromJson(json);

    if (!mounted) {
      return true;
    }

    final students = snapshot.students
        .cast<Map<String, dynamic>>()
        .map(StudentListItem.fromJson)
        .toList();

    _replaceDrafts(
      students,
      draftStates: snapshot.drafts,
    );

    setState(() {
      _years = snapshot.years
          .cast<Map<String, dynamic>>()
          .map(AcademicYearOption.fromJson)
          .toList();
      _levels = snapshot.levels
          .cast<Map<String, dynamic>>()
          .map(MainAttendanceLevel.fromJson)
          .toList();
      _classes = snapshot.classes
          .cast<Map<String, dynamic>>()
          .map(MainAttendanceClass.fromJson)
          .toList();
      _subjects = snapshot.subjects;
      _terms = snapshot.terms;
      _exams = snapshot.exams;
      _students = students;
      _selectedYearId = snapshot.selectedYearId;
      _selectedLevelId = snapshot.selectedLevelId;
      _selectedClassId = snapshot.selectedClassId;
      _selectedTermId = snapshot.selectedTermId;
      _selectedExamId = snapshot.selectedExamId;
      _selectedSubjectId = snapshot.selectedSubjectId;
      _loadingSetup = false;
      _loadingRoster = false;
      _saving = false;
      _usingOfflineData = students.isNotEmpty || snapshot.drafts.isNotEmpty;
      _hasPendingDraft = snapshot.drafts.isNotEmpty;
      _statusMessage = snapshot.drafts.isNotEmpty
          ? 'Offline draft restored. Sync marks again when the server is reachable.'
          : fallbackMessage;
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot({
    bool pendingDraft = false,
    String? statusMessage,
  }) async {
    await _cacheStore.writeCacheDocument(
      _examMarkEntryCacheKey,
      ExamMarkEntryOfflineSnapshot(
        years: _years,
        levels: _levels,
        classes: _classes,
        subjects: _subjects,
        terms: _terms,
        exams: _exams,
        students: _students,
        selectedYearId: _selectedYearId,
        selectedLevelId: _selectedLevelId,
        selectedClassId: _selectedClassId,
        selectedTermId: _selectedTermId,
        selectedExamId: _selectedExamId,
        selectedSubjectId: _selectedSubjectId,
        drafts: {
          for (final entry in _drafts.entries)
            entry.key: ExamMarkDraftState(
              mark: entry.value.markController.text,
              comment: entry.value.commentController.text,
            ),
        },
      ).toJson(
        years: _years.map((item) => item.toJson()).toList(),
        levels: _levels.map((item) => item.toJson()).toList(),
        classes: _classes.map((item) => item.toJson()).toList(),
        students: _students.map((item) => item.toJson()).toList(),
      )
        ..['pending_draft'] = pendingDraft
        ..['status_message'] = statusMessage,
    );
  }

  void _disposeDrafts() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    _drafts.clear();
  }

  void _clearRoster() {
    _disposeDrafts();
    _students = const [];
    _usingOfflineData = false;
    _hasPendingDraft = false;
    _statusMessage = null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _queueKeyForMarks() {
    return '$examMarksQueuePrefix${_selectedClassId ?? 0}:${_selectedExamId ?? 0}:${_selectedSubjectId ?? 0}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Mark Entry'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSetup,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _loadingSetup
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Load Mark Sheet',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Choose the academic year, exam, class, and subject to enter or update marks.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4CE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _hasPendingDraft
                                      ? Icons.save_outlined
                                      : Icons.cloud_off_outlined,
                                  size: 18,
                                  color: const Color(0xFF7A4F01),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _statusMessage!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF7A4F01),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _DropdownField<int>(
                          label: 'Academic Year',
                          value: _selectedYearId,
                          items: _years
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedYearId = value;
                              _terms = const [];
                              _exams = const [];
                              _selectedTermId = null;
                              _selectedExamId = null;
                              _clearRoster();
                            });
                            await _loadTermsAndExams();
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int?>(
                          label: 'Term',
                          value: _selectedTermId,
                          items: _terms
                              .map(
                                (entry) => DropdownMenuItem<int?>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedTermId = value;
                              _selectedExamId = null;
                              _clearRoster();
                            });
                            await _refreshExams();
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: 'Exam',
                          value: _selectedExamId,
                          items: _exams
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(
                                    '${entry.name} · Max ${_formatMark(entry.maxMark)}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedExamId = value;
                              _clearRoster();
                            });
                            await _writeSnapshot();
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: 'Level',
                          value: _selectedLevelId,
                          items: _levels
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            final classes = _classes
                                .where((entry) => entry.levelId == value)
                                .toList();
                            setState(() {
                              _selectedLevelId = value;
                              _selectedClassId =
                                  classes.isNotEmpty ? classes.first.id : null;
                              _clearRoster();
                            });
                            await _writeSnapshot();
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: 'Class',
                          value: _selectedClassId,
                          items: _filteredClasses
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedClassId = value;
                              _clearRoster();
                            });
                            await _writeSnapshot();
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int>(
                          label: 'Subject',
                          value: _selectedSubjectId,
                          items: _subjects
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedSubjectId = value;
                              _clearRoster();
                            });
                            await _writeSnapshot();
                          },
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: _loadingRoster ? null : _loadRoster,
                              icon: const Icon(
                                Icons.playlist_add_check_circle_outlined,
                              ),
                              label: Text(
                                _loadingRoster
                                    ? 'Loading...'
                                    : 'Load Mark Sheet',
                              ),
                            ),
                            if (_usingOfflineData)
                              OutlinedButton.icon(
                                onPressed: _loadingRoster ? null : _loadRoster,
                                icon: const Icon(Icons.cloud_sync_outlined),
                                label: const Text('Retry Online'),
                              ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            if (_students.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Students', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      '${_students.length} students · Max mark ${_selectedExam == null ? '--' : _formatMark(_selectedExam!.maxMark)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ..._students.map(_buildStudentCard),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : _saveMarks,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : (_hasPendingDraft
                                ? 'Sync Exam Marks'
                                : 'Save Exam Marks'),
                      ),
                    ),
                  ],
                ),
              )
            else if (!_loadingSetup && !_loadingRoster)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Load a class mark sheet to start entering scores.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentListItem student) {
    final draft = _drafts[student.id];
    if (draft == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              student.currentYear?.rollNumber?.isNotEmpty == true
                  ? 'Roll No: ${student.currentYear!.rollNumber}'
                  : 'No roll number assigned',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.markController,
              decoration: const InputDecoration(
                labelText: 'Mark',
                hintText: 'Enter score',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                setState(() {
                  _hasPendingDraft = true;
                  _statusMessage =
                      'Offline draft saved on this device. Sync marks again when the server is reachable.';
                });
                _writeSnapshot(
                  pendingDraft: true,
                  statusMessage:
                      'Offline draft saved on this device. Sync marks again when the server is reachable.',
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.commentController,
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'Optional comment',
              ),
              maxLines: 2,
              onChanged: (_) {
                setState(() {
                  _hasPendingDraft = true;
                  _statusMessage =
                      'Offline draft saved on this device. Sync marks again when the server is reachable.';
                });
                _writeSnapshot(
                  pendingDraft: true,
                  statusMessage:
                      'Offline draft saved on this device. Sync marks again when the server is reachable.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: items.any((entry) => entry.value == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}

class _MarkDraftControllers {
  _MarkDraftControllers({
    required String mark,
    required String comment,
  })  : markController = TextEditingController(text: mark),
        commentController = TextEditingController(text: comment);

  final TextEditingController markController;
  final TextEditingController commentController;

  void dispose() {
    markController.dispose();
    commentController.dispose();
  }
}

String _formatMark(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(2);
}

const _examMarkEntryCacheKey = 'exam_mark_entry_snapshot';
