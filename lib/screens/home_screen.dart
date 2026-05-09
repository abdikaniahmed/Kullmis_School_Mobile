import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../models/auth_session.dart';
import '../models/dashboard_data.dart';
import '../services/laravel_api.dart';
import '../services/offline_sync_queue.dart';
import '../widgets/summary_card.dart';
import 'academic_years_screen.dart';
import 'attendance_report_screen.dart';
import 'attendance_settings_screen.dart';
import 'audit_logs_screen.dart';
import 'backup_restore_screen.dart';
import 'buses_screen.dart';
import 'classes_screen.dart';
import 'class_report_screen.dart';
import 'discipline_incidents_screen.dart';
import 'documents_screen.dart';
import 'exam_mark_entry_screen.dart';
import 'exam_report_screen.dart';
import 'expenses_screen.dart';
import 'fee_invoices_screen.dart';
import 'fee_payments_screen.dart';
import 'fee_structures_screen.dart';
import 'general_settings_screen.dart';
import 'grade_setup_screen.dart';
import 'levels_screen.dart';
import 'main_attendance_screen.dart';
import 'messaging_screen.dart';
import 'payment_methods_screen.dart';
import 'petty_cash_screen.dart';
import 'promotions_screen.dart';
import 'roles_screen.dart';
import 'setup_config_screen.dart';
import 'staff_screen.dart';
import 'student_incident_report_screen.dart';
import 'student_list_report_screen.dart';
import 'student_list_screen.dart';
import 'students_disabled_screen.dart';
import 'students_graduates_screen.dart';
import 'subject_attendance_screen.dart';
import 'subject_attendance_report_screen.dart';
import 'subject_timetable_screen.dart';
import 'subjects_screen.dart';
import 'sync_issues_screen.dart';
import 'tasks_screen.dart';
import 'teachers_screen.dart';
import 'terms_screen.dart';
import 'users_screen.dart';
import 'weekly_incident_report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.dashboard,
    required this.api,
    required this.onRefresh,
    required this.onSyncNow,
    required this.onLogout,
    this.usingOfflineData = false,
    this.isServerReachable = true,
    this.isSyncing = false,
    this.statusMessage,
  });

  final AuthSession session;
  final DashboardData? dashboard;
  final LaravelApi api;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSyncNow;
  final Future<void> Function() onLogout;
  final bool usingOfflineData;
  final bool isServerReachable;
  final bool isSyncing;
  final String? statusMessage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();
  int _selectedIndex = 0;
  int? _expandedSidebarIndex;
  Widget? _windowContent;
  String? _windowTitle;
  Timer? _pendingSyncTimer;
  int _pendingSyncCount = 0;
  int _syncIssueCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingSyncCount();
    _pendingSyncTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadPendingSyncCount(),
    );
  }

  @override
  void dispose() {
    _pendingSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPendingSyncCount() async {
    final count = await _syncQueue.count();
    final issueCount = await _syncQueue.countIssues();
    if (!mounted ||
        (count == _pendingSyncCount && issueCount == _syncIssueCount)) {
      return;
    }

    setState(() {
      _pendingSyncCount = count;
      _syncIssueCount = issueCount;
    });
  }

  bool get _canTakeMainAttendance => widget.session.hasAnyPermission(const [
        'attendance.view',
        'attendance.create',
        'attendance.edit',
      ]);

  bool get _canViewAttendanceReports =>
      widget.session.hasPermission('attendance.view');

  bool get _canTakeSubjectAttendance => widget.session.hasAnyPermission(const [
        'subject_attendance.view',
        'subject_attendance.create',
      ]);

  bool get _canViewSubjectTimetable => widget.session.hasAnyPermission(const [
        'subject_timetable.view',
        'subject_timetable.create',
        'subject_timetable.edit',
      ]);

  bool get _canViewStudents => widget.session.hasAnyPermission(const [
        'students.view',
        'students.admission.view',
      ]);

  bool get _canManageDisciplineIncidents => widget.session.hasAnyPermission(
        const [
          'discipline_incidents.view',
          'discipline_incidents.create',
          'discipline_incidents.report.view',
        ],
      );

  bool get _canEnterExamMarks => widget.session.hasAnyPermission(const [
        'marks.create',
        'marks.view',
        'exams.view',
      ]);

  bool get _canViewExamReports => widget.session.hasPermission('marks.view');

  bool get _canPayFees => widget.session.hasPermission('fees.pay');

  bool get _canViewAcademicYears =>
      widget.session.hasPermission('academic_years.view');

  bool get _canViewPromotions => widget.session.roles.any(
        (role) => role.toLowerCase() == 'school_admin',
      );

  bool get _isSchoolAdmin => widget.session.roles.any(
        (role) => role.toLowerCase() == 'school_admin',
      );

  bool get _canEditAttendanceSettings =>
      widget.session.hasPermission('attendance.edit');

  bool get _canViewTerms => widget.session.hasPermission('terms.view');

  bool get _canViewSubjects => widget.session.hasPermission('subjects.view');

  bool get _canViewLevels => widget.session.hasPermission('levels.view');

  bool get _canViewClasses => widget.session.hasPermission('classes.view');

  bool get _canViewStaff => widget.session.hasPermission('staff.view');

  bool get _canViewTeachers => widget.session.hasPermission('teachers.view');

  bool get _canViewDocuments => widget.session.hasPermission('documents.view');

  bool get _canViewUsers => widget.session.hasPermission('users.view');

  bool get _canViewRoles => widget.session.hasPermission('roles.view');

  bool get _canViewAudits => widget.session.hasPermission('users.view');

  bool get _canViewBuses => widget.session.hasAnyPermission(const [
        'buses.view',
        'buses.create',
        'buses.edit',
        'buses.assign',
      ]);

  bool get _canUseMessaging => _isSchoolAdmin;

  String _t(String key, [String fallback = '']) => context.tr(key, fallback);

  List<_ShellDestination> _destinations() {
    final destinations = <_ShellDestination>[
      _ShellDestination(
        label: _t('dashboard'),
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        builder: _buildDashboardPage,
      ),
      _ShellDestination(
        label: _t('student'),
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        builder: _buildStudentsPage,
        showChildren: true,
        sidebarChildren: _studentSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('transport'),
        icon: Icons.directions_bus_outlined,
        selectedIcon: Icons.directions_bus,
        builder: _buildTransportPage,
        showChildren: true,
        sidebarChildren: _transportSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('reports'),
        icon: Icons.description_outlined,
        selectedIcon: Icons.description,
        builder: _buildReportsPage,
        showChildren: true,
        sidebarChildren: _reportsSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('attendance'),
        icon: Icons.how_to_reg_outlined,
        selectedIcon: Icons.how_to_reg,
        builder: _buildAttendancePage,
        showChildren: true,
        sidebarChildren: _attendanceSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('subject_attendance'),
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        builder: _buildSubjectAttendancePage,
        showChildren: true,
        sidebarChildren: _subjectAttendanceSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('exams'),
        icon: Icons.school_outlined,
        selectedIcon: Icons.school,
        builder: _buildExamsPage,
        showChildren: true,
        sidebarChildren: _examsSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('finance'),
        icon: Icons.request_quote_outlined,
        selectedIcon: Icons.request_quote,
        builder: _buildFeesPage,
        showChildren: true,
        sidebarChildren: _financeSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('hr', 'HR'),
        icon: Icons.badge_outlined,
        selectedIcon: Icons.badge,
        builder: _buildHrPage,
        showChildren: true,
        sidebarChildren: _hrSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('messaging'),
        icon: Icons.message_outlined,
        selectedIcon: Icons.message,
        builder: _buildMessagingPage,
        showChildren: true,
        sidebarChildren: _messagingSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('academic'),
        icon: Icons.auto_stories_outlined,
        selectedIcon: Icons.auto_stories,
        builder: _buildAcademicPage,
        showChildren: true,
        sidebarChildren: _academicSidebarLinks(),
      ),
      _ShellDestination(
        label: _t('settings'),
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        builder: _buildSettingsPage,
        showChildren: true,
        sidebarChildren: _settingsSidebarLinks(),
      ),
    ];

    return destinations
        .where((destination) =>
            !destination.showChildren || destination.sidebarChildren.isNotEmpty)
        .toList();
  }

  List<_SidebarChildLink> _studentSidebarLinks() {
    if (!_canViewStudents && !_canManageDisciplineIncidents) {
      return const [];
    }

    return <_SidebarChildLink>[
      if (_canViewStudents)
        _SidebarChildLink(
          label: _t('admission'),
          icon: Icons.groups_outlined,
          onPressed: () => _openScreen(
            StudentListScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      if (_canViewStudents)
        _SidebarChildLink(
          label: _t('disabled'),
          icon: Icons.block_outlined,
          onPressed: () => _openScreen(
            StudentsDisabledScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      if (_canViewStudents)
        _SidebarChildLink(
          label: _t('graduates'),
          icon: Icons.school_outlined,
          onPressed: () => _openScreen(
            StudentsGraduatesScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      if (_canManageDisciplineIncidents)
        _SidebarChildLink(
          label: _t('discipline_incidents'),
          icon: Icons.warning_amber_outlined,
          onPressed: () => _openScreen(
            DisciplineIncidentsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
    ];
  }

  List<_SidebarChildLink> _attendanceSidebarLinks() {
    final links = <_SidebarChildLink>[];

    if (_canTakeMainAttendance) {
      links.add(
        _SidebarChildLink(
          label: _t('mark_attendance'),
          icon: Icons.how_to_reg_outlined,
          onPressed: () => _openScreen(
            MainAttendanceScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );
    }

    if (widget.session.hasPermission('attendance.edit')) {
      links.add(
        _SidebarChildLink(
          label: _t('edit_attendance'),
          icon: Icons.edit_note_outlined,
          onPressed: () => _openScreen(
            MainAttendanceScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );
    }

    if (_canViewAttendanceReports) {
      links.add(
        _SidebarChildLink(
          label: _t('attendance_report'),
          icon: Icons.list_alt_outlined,
          onPressed: () => _openScreen(
            AttendanceReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );
    }

    return links;
  }

  List<_SidebarChildLink> _reportsSidebarLinks() {
    final links = <_SidebarChildLink>[];

    if (_canViewStudents ||
        widget.session.hasPermission('students.report_list.view')) {
      links.add(
        _SidebarChildLink(
          label: _t('student_list_report'),
          icon: Icons.list_alt_outlined,
          onPressed: () => _openScreen(
            StudentListReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );
    }

    if (_canViewBuses) {
      links.add(
        _SidebarChildLink(
          label: _t('student_bus_report'),
          icon: Icons.directions_bus_outlined,
          onPressed: () => _openScreen(
            BusesScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (widget.session.hasPermission('discipline_incidents.report.view')) {
      links.addAll([
        _SidebarChildLink(
          label: _t('student_incident_report'),
          icon: Icons.report_outlined,
          onPressed: () => _openScreen(
            StudentIncidentReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
        _SidebarChildLink(
          label: _t('weekly_incident_report'),
          icon: Icons.calendar_month_outlined,
          onPressed: () => _openScreen(
            WeeklyIncidentReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      ]);
    }

    return links;
  }

  List<_SidebarChildLink> _subjectAttendanceSidebarLinks() {
    final links = <_SidebarChildLink>[];

    if (_canTakeSubjectAttendance) {
      links.addAll([
        _SidebarChildLink(
          label: _t('take_subject_attendance'),
          icon: Icons.fact_check_outlined,
          onPressed: () => _openScreen(
            SubjectAttendanceScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
        _SidebarChildLink(
          label: _t('subject_attendance_report'),
          icon: Icons.analytics_outlined,
          onPressed: () => _openScreen(
            SubjectAttendanceReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      ]);
    }

    if (_canViewSubjectTimetable) {
      links.add(
        _SidebarChildLink(
          label: _t('subject_timetable'),
          icon: Icons.schedule_outlined,
          onPressed: () => _openScreen(
            SubjectTimetableScreen(
              api: widget.api,
              token: widget.session.token,
              canEdit: widget.session.hasAnyPermission(const [
                'subject_timetable.create',
                'subject_timetable.edit',
              ]),
            ),
          ),
        ),
      );
    }

    return links;
  }

  List<_SidebarChildLink> _examsSidebarLinks() {
    final links = <_SidebarChildLink>[];

    if (_canEnterExamMarks) {
      links.addAll([
        _SidebarChildLink(
          label: _t('enter_marks'),
          icon: Icons.edit_note_outlined,
          onPressed: () => _openScreen(
            ExamMarkEntryScreen(
              api: widget.api,
              token: widget.session.token,
              canViewMarks: widget.session.hasPermission('marks.view'),
            ),
          ),
        ),
        _SidebarChildLink(
          label: _t('enter_class_marks'),
          icon: Icons.check_circle_outline,
          onPressed: () => _openScreen(
            ExamMarkEntryScreen(
              api: widget.api,
              token: widget.session.token,
              canViewMarks: widget.session.hasPermission('marks.view'),
            ),
          ),
        ),
      ]);
    }

    if (_canViewExamReports) {
      links.addAll([
        _SidebarChildLink(
          label: _t('marks_report'),
          icon: Icons.assessment_outlined,
          onPressed: () => _openScreen(
            ExamReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
        _SidebarChildLink(
          label: _t('class_report'),
          icon: Icons.leaderboard_outlined,
          onPressed: () => _openScreen(
            ClassReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      ]);
    }

    return links;
  }

  List<_SidebarChildLink> _financeSidebarLinks() {
    final links = <_SidebarChildLink>[
      _SidebarChildLink(
        label: _t('fee_invoices'),
        icon: Icons.receipt_long_outlined,
        onPressed: () => _openScreen(
          FeeInvoicesScreen(
            api: widget.api,
            token: widget.session.token,
            session: widget.session,
          ),
        ),
      ),
    ];

    if (_canPayFees) {
      links.add(
        _SidebarChildLink(
          label: _t('receive_payment'),
          icon: Icons.payments_outlined,
          onPressed: () => _openScreen(
            FeePaymentsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewExamReports) {
      links.add(
        _SidebarChildLink(
          label: _t('fee_reports'),
          icon: Icons.description_outlined,
          onPressed: () => _openScreen(
            ExamReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );
    }

    if (widget.session.hasPermission('expenses.view')) {
      links.add(
        _SidebarChildLink(
          label: _t('expenses'),
          icon: Icons.receipt_outlined,
          onPressed: () => _openScreen(
            ExpensesScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (widget.session.hasPermission('petty_cash.view')) {
      links.add(
        _SidebarChildLink(
          label: _t('petty_cash'),
          icon: Icons.account_balance_wallet_outlined,
          onPressed: () => _openScreen(
            PettyCashScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (widget.session.hasAnyPermission(const ['fees.pay', 'payments.edit'])) {
      links.add(
        _SidebarChildLink(
          label: _t('payment_methods'),
          icon: Icons.credit_card_outlined,
          onPressed: () => _openScreen(
            PaymentMethodsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    links.add(
      _SidebarChildLink(
        label: _t('fee_structures'),
        icon: Icons.layers_outlined,
        onPressed: () => _openScreen(
          FeeStructuresScreen(
            api: widget.api,
            token: widget.session.token,
          ),
        ),
      ),
    );

    return links;
  }

  List<_SidebarChildLink> _transportSidebarLinks() {
    if (!_canViewBuses) {
      return const [];
    }

    return <_SidebarChildLink>[
      _SidebarChildLink(
        label: _t('buses'),
        icon: Icons.directions_bus_outlined,
        onPressed: () => _openScreen(
          BusesScreen(
            api: widget.api,
            token: widget.session.token,
            session: widget.session,
          ),
        ),
      ),
    ];

  }

  List<_SidebarChildLink> _hrSidebarLinks() {
    final links = <_SidebarChildLink>[];

    if (_canViewStaff) {
      links.add(
        _SidebarChildLink(
          label: _t('staff'),
          icon: Icons.badge_outlined,
          onPressed: () => _openScreen(
            StaffScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (widget.session.hasPermission('tasks.view')) {
      links.add(
        _SidebarChildLink(
          label: _t('tasks'),
          icon: Icons.checklist_outlined,
          onPressed: () => _openScreen(
            TasksScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewTeachers) {
      links.add(
        _SidebarChildLink(
          label: _t('teachers'),
          icon: Icons.school_outlined,
          onPressed: () => _openScreen(
            TeachersScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewDocuments) {
      links.add(
        _SidebarChildLink(
          label: _t('documents'),
          icon: Icons.description_outlined,
          onPressed: () => _openScreen(
            DocumentsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewUsers) {
      links.add(
        _SidebarChildLink(
          label: _t('users'),
          icon: Icons.people_outline,
          onPressed: () => _openScreen(
            UsersScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewRoles) {
      links.add(
        _SidebarChildLink(
          label: _t('roles'),
          icon: Icons.settings_outlined,
          onPressed: () => _openScreen(
            RolesScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewAudits) {
      links.add(
        _SidebarChildLink(
          label: _t('audit_logs'),
          icon: Icons.shield_outlined,
          onPressed: () => _openScreen(
            AuditLogsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    return links;
  }

  List<_SidebarChildLink> _academicSidebarLinks() {
    final links = <_SidebarChildLink>[];

    if (_canViewAcademicYears) {
      links.add(
        _SidebarChildLink(
          label: _t('academic_years'),
          icon: Icons.calendar_month_outlined,
          onPressed: () => _openScreen(
            AcademicYearsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewPromotions) {
      links.add(
        _SidebarChildLink(
          label: _t('promotions'),
          icon: Icons.trending_up,
          onPressed: () => _openScreen(
            PromotionsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewTerms) {
      links.add(
        _SidebarChildLink(
          label: _t('terms'),
          icon: Icons.calendar_today_outlined,
          onPressed: () => _openScreen(
            TermsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewSubjects) {
      links.add(
        _SidebarChildLink(
          label: _t('subjects'),
          icon: Icons.menu_book_outlined,
          onPressed: () => _openScreen(
            SubjectsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewLevels) {
      links.add(
        _SidebarChildLink(
          label: _t('levels'),
          icon: Icons.layers_outlined,
          onPressed: () => _openScreen(
            LevelsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    if (_canViewClasses) {
      links.add(
        _SidebarChildLink(
          label: _t('classes'),
          icon: Icons.folder_outlined,
          onPressed: () => _openScreen(
            ClassesScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    return links;
  }

  List<_SidebarChildLink> _messagingSidebarLinks() {
    if (!_canUseMessaging) {
      return const [];
    }

    return <_SidebarChildLink>[
      _SidebarChildLink(
        label: _t('inbox'),
        icon: Icons.message_outlined,
        onPressed: () => _openScreen(
          MessagingScreen(
            api: widget.api,
            token: widget.session.token,
            session: widget.session,
          ),
        ),
      ),
      _SidebarChildLink(
        label: _t('twilio_credentials'),
        icon: Icons.settings_outlined,
        onPressed: () => _openScreen(
          MessagingScreen(
            api: widget.api,
            token: widget.session.token,
            session: widget.session,
          ),
        ),
      ),
      _SidebarChildLink(
        label: _t('templates'),
        icon: Icons.description_outlined,
        onPressed: () => _openScreen(
          MessagingScreen(
            api: widget.api,
            token: widget.session.token,
            session: widget.session,
          ),
        ),
      ),
    ];
  }

  List<_SidebarChildLink> _settingsSidebarLinks() {
    final links = <_SidebarChildLink>[];

    if (_isSchoolAdmin) {
      links.addAll([
        _SidebarChildLink(
          label: _t('general'),
          icon: Icons.settings_outlined,
          onPressed: () => _openScreen(
            GeneralSettingsScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
        _SidebarChildLink(
          label: _t('setup_config'),
          icon: Icons.tune_outlined,
          onPressed: () => _openScreen(
            SetupConfigScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
        _SidebarChildLink(
          label: _t('grade_setup'),
          icon: Icons.grading_outlined,
          onPressed: () => _openScreen(
            GradeSetupScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      ]);
    }

    if (_canEditAttendanceSettings) {
      links.add(
        _SidebarChildLink(
          label: _t('attendance_settings'),
          icon: Icons.how_to_reg_outlined,
          onPressed: () => _openScreen(
            AttendanceSettingsScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );
    }

    if (_isSchoolAdmin) {
      links.add(
        _SidebarChildLink(
          label: _t('backup_restore', 'Backup & Restore'),
          icon: Icons.archive_outlined,
          onPressed: () => _openScreen(
            BackupRestoreScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );
    }

    links.add(
      _SidebarChildLink(
        label: _t('sync_issues', 'Sync Issues'),
        icon: Icons.sync_problem_outlined,
        onPressed: () => _openScreen(
          const SyncIssuesScreen(),
        ),
      ),
    );

    return links;
  }

  Future<void> _openScreen(Widget screen, {String? title}) {
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    if (isWindows) {
      setState(() {
        _windowContent = screen;
        _windowTitle = title;
      });
      return Future.value();
    }

    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Widget _buildDashboardPage() {
    final theme = Theme.of(context);
    final roleLabels = widget.session.roles
        .map((role) => role.trim().replaceAll('_', ' '))
        .where((role) => role.isNotEmpty)
        .toList();
    final visibleRoleLabels =
        roleLabels.isEmpty ? <String>[_t('admin', 'Admin')] : roleLabels;
    final cards = <SummaryCardData>[
      SummaryCardData(
        label: _t('students'),
        value: widget.dashboard?.studentsLabel ?? '--',
        tone: const Color(0xFFE0F2FE),
      ),
      SummaryCardData(
        label: _t('teachers'),
        value: widget.dashboard?.teachersLabel ?? '--',
        tone: const Color(0xFFFEF3C7),
      ),
      SummaryCardData(
        label: _t('subjects'),
        value: widget.dashboard?.subjectsLabel ?? '--',
        tone: const Color(0xFFDCFCE7),
      ),
      SummaryCardData(
        label: _t('attendance'),
        value: widget.dashboard?.attendanceLabel ?? '--',
        tone: const Color(0xFFFCE7F3),
      ),
    ];

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF115E59),
                  Color(0xFF0F766E),
                  Color(0xFFCB6E17),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.session.name,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.session.email,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: visibleRoleLabels
                      .map(
                        (role) => Container(
                          constraints: const BoxConstraints(maxWidth: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          child: Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF115E59),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(_t('overview'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards.map((card) => SummaryCard(card: card)).toList(),
          ),
          const SizedBox(height: 20),
          if (widget.dashboard == null)
            _buildPanel(
              child: Text(
                'This account authenticated successfully, but the school dashboard endpoint is not available for the current role.',
                style: theme.textTheme.bodyLarge,
              ),
            )
          else ...[
            _buildPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue this month',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.dashboard!.revenueLabel,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Growth: ${widget.dashboard!.growthLabel}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t('monthly_revenue', 'Monthly revenue'),
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ...widget.dashboard!.monthTotals.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.label)),
                          Text(entry.totalLabel),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentsPage() {
    return _buildOverviewPage(
      title: _t('students'),
      description:
          'Open the student roster and drill into profiles from one place.',
      modules: _studentSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildAttendancePage() {
    return _buildOverviewPage(
      title: _t('attendance'),
      description: _t(
        'open_attendance_tools',
        'Open the attendance tools that match the signed-in role.',
      ),
      modules: _attendanceSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildSubjectAttendancePage() {
    return _buildOverviewPage(
      title: _t('subject_attendance'),
      description: _t(
        'take_subject_attendance_review_reports',
        'Take subject attendance and review subject reports.',
      ),
      modules:
          _subjectAttendanceSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildReportsPage() {
    return _buildOverviewPage(
      title: _t('reports'),
      description: _t('open_exam_reports', 'Open exam reports and summaries.'),
      modules: _reportsSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildExamsPage() {
    return _buildOverviewPage(
      title: _t('exams'),
      description:
          _t('manage_exams_marks_reports', 'Manage exams, marks, and reports.'),
      modules: _examsSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildHrPage() {
    return _buildOverviewPage(
      title: _t('hr', 'HR'),
      description: _t(
        'manage_hr_modules',
        'Manage staff, teachers, documents, users, and roles.',
      ),
      modules: _hrSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildAcademicPage() {
    return _buildOverviewPage(
      title: _t('academic'),
      description:
          _t('academic_tools_planning', 'Academic tools and planning modules.'),
      modules: _academicSidebarLinks().map((link) => link.label).toList(),
      emptyMessage: _t(
        'academic_tools_enabled_for_role',
        'Academic tools will appear here once they are enabled for your role.',
      ),
    );
  }

  Widget _buildFeesPage() {
    return _buildOverviewPage(
      title: _t('fees'),
      description: _t(
        'manage_school_billing',
        'Manage school billing, invoices, and payment workflows.',
      ),
      modules: _financeSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildSettingsPage() {
    return _buildOverviewPage(
      title: _t('settings'),
      description: _t(
        'manage_school_configuration',
        'Manage school configuration and attendance defaults.',
      ),
      modules: _settingsSidebarLinks().map((link) => link.label).toList(),
      footer: _buildPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('signed_in_as', 'Signed in as'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.session.name,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(widget.session.email,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewPage({
    required String title,
    required String description,
    required List<String> modules,
    String? emptyMessage,
    Widget? footer,
  }) {
    final theme = Theme.of(context);
    final activeMessage = emptyMessage ??
        _t(
          'use_sidebar_sublinks',
          'Use the sidebar sub-links to open a module.',
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _buildPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(description, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t('overview'), style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                _t('modules_available', 'Modules available: :count')
                    .replaceAll(':count', '${modules.length}'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (modules.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: modules
                      .map(
                        (label) => Chip(
                          label: Text(label),
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.08),
                          labelStyle: TextStyle(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      )
                      .toList(),
                )
              else
                Text(activeMessage, style: theme.textTheme.bodyLarge),
              if (modules.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _t(
                    'open_module_sidebar_sublinks',
                    'Open a module using the sidebar sub-links.',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: 16),
          footer,
        ],
      ],
    );
  }

  Widget _buildPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _buildMessagingPage() {
    return _buildOverviewPage(
      title: _t('messaging'),
      description: _t(
        'open_messaging_tools',
        'Open messaging inbox, templates, and channel settings.',
      ),
      modules: _messagingSidebarLinks().map((link) => link.label).toList(),
      emptyMessage: _t(
        'messaging_tools_enabled_for_role',
        'Messaging tools will appear here once they are enabled for your role.',
      ),
    );
  }

  Widget _buildStatusBanner() {
    final message = widget.statusMessage;
    final showReachabilityWarning = !widget.isServerReachable;
    if ((message == null || message.isEmpty) &&
        _pendingSyncCount == 0 &&
        _syncIssueCount == 0 &&
        !showReachabilityWarning) {
      return const SizedBox.shrink();
    }

    final statusParts = <TextSpan>[
      if (showReachabilityWarning)
        TextSpan(
          text: _t(
            'server_unreachable_queued_changes',
            'Server unreachable. Queued changes will sync when connection returns.',
          ),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      if (message != null && message.isNotEmpty)
        TextSpan(
          text: message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      if (_pendingSyncCount > 0)
        TextSpan(
          text:
              '${_t('pending_offline_sync', 'Pending offline sync')}: $_pendingSyncCount',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      if (_syncIssueCount > 0)
        TextSpan(
          text:
              '${_t('sync_conflicts_need_review', 'Sync conflicts need review')}: $_syncIssueCount',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
    ];
    final separatedStatusParts = <InlineSpan>[];
    for (final part in statusParts) {
      if (separatedStatusParts.isNotEmpty) {
        separatedStatusParts.add(const TextSpan(text: '  |  '));
      }
      separatedStatusParts.add(part);
    }

    final actions = <Widget>[
      if (_syncIssueCount > 0)
        TextButton.icon(
          onPressed: () async => _openScreen(const SyncIssuesScreen()),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: Text(_t('review')),
        ),
      if (_pendingSyncCount > 0 || showReachabilityWarning)
        TextButton.icon(
          onPressed: widget.isSyncing ? null : () async => widget.onSyncNow(),
          icon: widget.isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync, size: 18),
          label: Text(
            widget.isSyncing
                ? _t('syncing', 'Syncing')
                : _t('sync_now', 'Sync Now'),
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: widget.usingOfflineData
          ? const Color(0xFFFFF4CE)
          : const Color(0xFFE8F5E9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.usingOfflineData
                    ? Icons.cloud_off_outlined
                    : Icons.info_outline,
                size: 18,
                color: const Color(0xFF7A4F01),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF7A4F01),
                      fontSize: 14,
                      height: 1.35,
                    ),
                    children: separatedStatusParts,
                  ),
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: actions,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransportPage() {
    return _buildOverviewPage(
      title: _t('transport'),
      description: _t(
        'manage_transport_coverage',
        'Manage buses, assign students, and track transport coverage across the school.',
      ),
      modules: _transportSidebarLinks().map((link) => link.label).toList(),
      emptyMessage: _t(
        'no_transport_modules_available',
        'No transport modules are available for this account yet.',
      ),
    );
  }

  Widget _buildMobileModuleBar(
    ThemeData theme,
    _ShellDestination destination,
  ) {
    if (destination.sidebarChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('modules_title', ':name Modules')
                  .replaceAll(':name', destination.label),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: destination.sidebarChildren
                    .map(
                      (child) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton.icon(
                          onPressed: () async => child.onPressed(),
                          icon: Icon(child.icon, size: 18),
                          label: Text(child.label),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<int> _mobilePrimaryIndexes(List<_ShellDestination> destinations) {
    final preferredIcons = <IconData>[
      Icons.dashboard,
      Icons.groups,
      Icons.how_to_reg,
      Icons.request_quote,
    ];
    final indexes = <int>[];

    for (final icon in preferredIcons) {
      final index = destinations.indexWhere(
        (destination) => destination.selectedIcon == icon,
      );
      if (index != -1 && !indexes.contains(index)) {
        indexes.add(index);
      }
    }

    for (var index = 0;
        index < destinations.length && indexes.length < 4;
        index++) {
      if (!indexes.contains(index)) {
        indexes.add(index);
      }
    }

    return indexes;
  }

  Future<void> _showMobileMoreSheet(
    BuildContext context,
    List<_ShellDestination> destinations,
    List<int> primaryIndexes,
    int selectedIndex,
  ) async {
    final theme = Theme.of(context);
    final moreIndexes = <int>[
      for (var index = 0; index < destinations.length; index++)
        if (!primaryIndexes.contains(index)) index,
    ];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: moreIndexes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, itemIndex) {
              final destinationIndex = moreIndexes[itemIndex];
              final destination = destinations[destinationIndex];
              final selected = destinationIndex == selectedIndex;

              return ListTile(
                selected: selected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: selected ? theme.colorScheme.primary : null,
                ),
                title: Text(destination.label),
                trailing: selected ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _selectedIndex = destinationIndex;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinations = _destinations();
    final selectedIndex = _selectedIndex.clamp(0, destinations.length - 1);
    final selectedDestination = destinations[selectedIndex];
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    if (isWindows) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              schoolName: widget.session.schoolName ?? _t('kullmis_school'),
              destinations: destinations,
              selectedIndex: selectedIndex,
              expandedIndex: _expandedSidebarIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                  _windowContent = null;
                  _windowTitle = null;
                  _expandedSidebarIndex = null;
                });
              },
              onDestinationExpanded: (index) {
                setState(() {
                  _expandedSidebarIndex =
                      _expandedSidebarIndex == index ? null : index;
                });
              },
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: _windowTitle ?? selectedDestination.label,
                    userName: widget.session.name,
                    userEmail: widget.session.email,
                    onProfile: () => _openScreen(
                      GeneralSettingsScreen(
                        api: widget.api,
                        token: widget.session.token,
                      ),
                      title: _t('profile'),
                    ),
                    onRefresh: widget.onRefresh,
                    onSyncNow: widget.onSyncNow,
                    isSyncing: widget.isSyncing,
                    onLogout: widget.onLogout,
                  ),
                  _buildStatusBanner(),
                  Expanded(
                    child: ColoredBox(
                      color: theme.scaffoldBackgroundColor,
                      child: _windowContent ?? selectedDestination.builder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        final mobilePrimaryIndexes = _mobilePrimaryIndexes(destinations);
        final hasMoreDestinations =
            !useRail && destinations.length > mobilePrimaryIndexes.length;
        final mobileSelectedIndex =
            mobilePrimaryIndexes.contains(selectedIndex)
                ? mobilePrimaryIndexes.indexOf(selectedIndex)
                : mobilePrimaryIndexes.length;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(
              useRail
                  ? widget.session.schoolName ??
                      _t('kullmis_school_mobile', 'Kullmis School Mobile')
                  : selectedDestination.label,
            ),
            actions: [
              IconButton(
                onPressed: () async => context.language.toggleLocale(),
                icon: const Icon(Icons.language),
                tooltip: context.tr('language'),
              ),
              IconButton(
                onPressed: () async => widget.onRefresh(),
                icon: const Icon(Icons.refresh),
                tooltip: context.tr('refresh'),
              ),
              IconButton(
                onPressed:
                    widget.isSyncing ? null : () async => widget.onSyncNow(),
                icon: widget.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                tooltip: context.tr('sync_now', 'Sync Now'),
              ),
              IconButton(
                onPressed: () async => widget.onLogout(),
                icon: const Icon(Icons.logout),
                tooltip: context.tr('logout'),
              ),
            ],
          ),
          body: Row(
            children: [
              if (useRail)
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.12),
                          child: Icon(
                            Icons.school_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 88,
                          child: Text(
                            widget.session.schoolName ?? _t('kullmis_school'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
              Expanded(
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      _buildStatusBanner(),
                      _buildMobileModuleBar(theme, selectedDestination),
                      Expanded(
                        child: selectedDestination.builder(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: hasMoreDestinations
                      ? mobileSelectedIndex
                      : selectedIndex,
                  onDestinationSelected: (index) {
                    if (hasMoreDestinations &&
                        index == mobilePrimaryIndexes.length) {
                      _showMobileMoreSheet(
                        context,
                        destinations,
                        mobilePrimaryIndexes,
                        selectedIndex,
                      );
                      return;
                    }

                    setState(() {
                      _selectedIndex = hasMoreDestinations
                          ? mobilePrimaryIndexes[index]
                          : index;
                    });
                  },
                  destinations: [
                    for (final index in hasMoreDestinations
                        ? mobilePrimaryIndexes
                        : List<int>.generate(
                            destinations.length,
                            (index) => index,
                          ))
                      NavigationDestination(
                        icon: Icon(destinations[index].icon),
                        selectedIcon: Icon(destinations[index].selectedIcon),
                        label: destinations[index].label,
                      ),
                    if (hasMoreDestinations)
                      NavigationDestination(
                        icon: const Icon(Icons.more_horiz),
                        selectedIcon: const Icon(Icons.more),
                        label: _t('more', 'More'),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.schoolName,
    required this.destinations,
    required this.selectedIndex,
    required this.expandedIndex,
    required this.onDestinationSelected,
    required this.onDestinationExpanded,
  });

  final String schoolName;
  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final int? expandedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<int> onDestinationExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
                ),
              ),
              child: Text(
                schoolName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 14),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  final selected = index == selectedIndex;
                  final hasChildren = destination.showChildren &&
                      destination.sidebarChildren.isNotEmpty;
                  final showChildren = destination.showChildren &&
                      destination.sidebarChildren.isNotEmpty &&
                      expandedIndex == index;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SidebarTile(
                        label: destination.label,
                        icon: selected
                            ? destination.selectedIcon
                            : destination.icon,
                        selected: selected,
                        expanded: showChildren,
                        expandable: hasChildren,
                        onTap: () {
                          if (hasChildren) {
                            onDestinationExpanded(index);
                            return;
                          }

                          onDestinationSelected(index);
                        },
                      ),
                      if (showChildren)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 10, 6),
                          child: Column(
                            children: destination.sidebarChildren
                                .map(
                                  (child) => _SidebarSubTile(
                                    label: child.label,
                                    icon: child.icon,
                                    onTap: child.onPressed,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Text(
                context.tr('kullmis_school_system', 'Kullmis School System'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.expanded,
    required this.expandable,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool expanded;
  final bool expandable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? theme.colorScheme.onSurface.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (expandable)
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarSubTile extends StatelessWidget {
  const _SidebarSubTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () async => onTap(),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.userName,
    required this.userEmail,
    required this.onProfile,
    required this.onRefresh,
    required this.onSyncNow,
    required this.isSyncing,
    required this.onLogout,
  });

  final String title;
  final String userName;
  final String userEmail;
  final Future<void> Function() onProfile;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSyncNow;
  final bool isSyncing;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard_customize_outlined,
              color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(title, style: theme.textTheme.titleLarge),
          const Spacer(),
          IconButton(
            onPressed: () async => context.language.toggleLocale(),
            icon: const Icon(Icons.language),
            tooltip: context.tr('language'),
          ),
          IconButton(
            onPressed: () async => onRefresh(),
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('refresh'),
          ),
          TextButton.icon(
            onPressed: isSyncing ? null : () async => onSyncNow(),
            icon: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(
              isSyncing
                  ? context.tr('syncing', 'Syncing')
                  : context.tr('sync_now', 'Sync Now'),
            ),
          ),
          const SizedBox(width: 8),
          _ProfileMenu(
            userName: userName,
            userEmail: userEmail,
            onProfile: onProfile,
            onLogout: onLogout,
          ),
        ],
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.userName,
    required this.userEmail,
    required this.onProfile,
    required this.onLogout,
  });

  final String userName;
  final String userEmail;
  final Future<void> Function() onProfile;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(userName);

    return PopupMenuButton<_ProfileMenuAction>(
      tooltip: context.tr('profile'),
      offset: const Offset(0, 14),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints: const BoxConstraints(minWidth: 256),
      onSelected: (action) async {
        switch (action) {
          case _ProfileMenuAction.profile:
            await onProfile();
            break;
          case _ProfileMenuAction.logout:
            await onLogout();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_ProfileMenuAction>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<_ProfileMenuAction>(
          value: _ProfileMenuAction.profile,
          height: 46,
          child: Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
              const SizedBox(width: 12),
              Text(context.tr('profile')),
            ],
          ),
        ),
        PopupMenuItem<_ProfileMenuAction>(
          value: _ProfileMenuAction.logout,
          height: 46,
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Text(
                context.tr('logout'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              foregroundColor: theme.colorScheme.primary,
              child: Text(
                initials,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return 'U';
    }
    if (words.length == 1) {
      return words.first[0].toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

enum _ProfileMenuAction { profile, logout }

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.sidebarChildren = const [],
    this.showChildren = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
  final List<_SidebarChildLink> sidebarChildren;
  final bool showChildren;
}

class _SidebarChildLink {
  const _SidebarChildLink({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;
}
