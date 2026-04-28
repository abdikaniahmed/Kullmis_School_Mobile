import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/dashboard_data.dart';
import '../services/laravel_api.dart';
import '../widgets/summary_card.dart';
import 'academic_years_screen.dart';
import 'attendance_settings_screen.dart';
import 'audit_logs_screen.dart';
import 'backup_restore_screen.dart';
import 'buses_screen.dart';
import 'classes_screen.dart';
import 'class_report_screen.dart';
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
import 'students_upload_screen.dart';
import 'subject_attendance_screen.dart';
import 'subject_attendance_report_screen.dart';
import 'subject_timetable_screen.dart';
import 'subjects_screen.dart';
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
    required this.onLogout,
    this.usingOfflineData = false,
    this.statusMessage,
  });

  final AuthSession session;
  final DashboardData? dashboard;
  final LaravelApi api;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;
  final bool usingOfflineData;
  final String? statusMessage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int? _expandedSidebarIndex;
  Widget? _windowContent;
  String? _windowTitle;

  bool get _canTakeMainAttendance => widget.session.hasAnyPermission(const [
        'attendance.view',
        'attendance.create',
        'attendance.edit',
      ]);

  bool get _canTakeSubjectAttendance => widget.session.hasAnyPermission(const [
        'subject_attendance.view',
        'subject_attendance.create',
      ]);

  bool get _canViewSubjectTimetable => widget.session.hasAnyPermission(const [
        'subject_timetable.view',
        'subject_timetable.create',
        'subject_timetable.edit',
      ]);

  bool get _canViewStudents => widget.session.hasPermission('students.view');

  bool get _canViewDisciplineIncidents =>
      widget.session.hasAnyPermission(const [
        'discipline_incidents.view',
        'discipline_incidents.report.view',
      ]);

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

  List<_ShellDestination> _destinations() {
    return <_ShellDestination>[
      _ShellDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        builder: _buildDashboardPage,
        showChildren: true,
        sidebarChildren: _dashboardSidebarLinks(),
      ),
      _ShellDestination(
        label: 'Student',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        builder: _buildStudentsPage,
        showChildren: true,
        sidebarChildren: _studentSidebarLinks(),
      ),
      _ShellDestination(
        label: 'Transport',
        icon: Icons.directions_bus_outlined,
        selectedIcon: Icons.directions_bus,
        builder: _buildTransportPage,
        showChildren: true,
        sidebarChildren: _transportSidebarLinks(),
      ),
      _ShellDestination(
        label: 'Reports',
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        builder: _buildReportsPage,
        showChildren: true,
        sidebarChildren: _reportsSidebarLinks(),
      ),
      _ShellDestination(
        label: 'Attendance',
        icon: Icons.how_to_reg_outlined,
        selectedIcon: Icons.how_to_reg,
        builder: _buildAttendancePage,
        showChildren: true,
        sidebarChildren: _attendanceSidebarLinks(),
      ),
      _ShellDestination(
        label: 'Exams',
        icon: Icons.school_outlined,
        selectedIcon: Icons.school,
        builder: _buildExamsPage,
        showChildren: true,
        sidebarChildren: _examsSidebarLinks(),
      ),
      _ShellDestination(
        label: 'Finance',
        icon: Icons.request_quote_outlined,
        selectedIcon: Icons.request_quote,
        builder: _buildFeesPage,
        showChildren: true,
        sidebarChildren: _financeSidebarLinks(),
      ),
      _ShellDestination(
        label: 'HR',
        icon: Icons.badge_outlined,
        selectedIcon: Icons.badge,
        builder: _buildHrPage,
        showChildren: true,
        sidebarChildren: _hrSidebarLinks(),
      ),
      _ShellDestination(
        label: 'Academic',
        icon: Icons.auto_stories_outlined,
        selectedIcon: Icons.auto_stories,
        builder: _buildAcademicPage,
        showChildren: true,
        sidebarChildren: _academicSidebarLinks(),
      ),
      _ShellDestination(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        builder: _buildSettingsPage,
        showChildren: true,
        sidebarChildren: _settingsSidebarLinks(),
      ),
    ];
  }

  List<_SidebarChildLink> _dashboardSidebarLinks() {
    return <_SidebarChildLink>[
      _SidebarChildLink(
        label: 'Refresh Dashboard',
        icon: Icons.refresh,
        onPressed: widget.onRefresh,
      ),
    ];
  }

  List<_SidebarChildLink> _studentSidebarLinks() {
    if (!_canViewStudents) {
      return const [];
    }

    return <_SidebarChildLink>[
      _SidebarChildLink(
        label: 'Student List',
        icon: Icons.groups_outlined,
        onPressed: () => _openScreen(
          StudentListScreen(
            api: widget.api,
            token: widget.session.token,
            session: widget.session,
          ),
        ),
      ),
      _SidebarChildLink(
        label: 'Disabled Students',
        icon: Icons.block_outlined,
        onPressed: () => _openScreen(
          StudentsDisabledScreen(
            api: widget.api,
            token: widget.session.token,
            session: widget.session,
          ),
        ),
      ),
      _SidebarChildLink(
        label: 'Graduates',
        icon: Icons.school_outlined,
        onPressed: () => _openScreen(
          StudentsGraduatesScreen(
            api: widget.api,
            token: widget.session.token,
            session: widget.session,
          ),
        ),
      ),
      if (widget.session.hasPermission('students.create'))
        _SidebarChildLink(
          label: 'Upload Students',
          icon: Icons.upload_file,
          onPressed: () => _openScreen(
            StudentsUploadScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      _SidebarChildLink(
        label: 'Student List Report',
        icon: Icons.description_outlined,
        onPressed: () => _openScreen(
          StudentListReportScreen(
            api: widget.api,
            token: widget.session.token,
          ),
        ),
      ),
      if (widget.session.hasPermission('discipline_incidents.report.view'))
        _SidebarChildLink(
          label: 'Student Incident Report',
          icon: Icons.report_outlined,
          onPressed: () => _openScreen(
            StudentIncidentReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      if (widget.session.hasPermission('discipline_incidents.report.view'))
        _SidebarChildLink(
          label: 'Weekly Incident Report',
          icon: Icons.calendar_month_outlined,
          onPressed: () => _openScreen(
            WeeklyIncidentReportScreen(
              api: widget.api,
              token: widget.session.token,
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
          label: 'Daily Attendance',
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

    if (_canTakeSubjectAttendance) {
      links.add(
        _SidebarChildLink(
          label: 'Subject Attendance',
          icon: Icons.fact_check_outlined,
          onPressed: () => _openScreen(
            SubjectAttendanceScreen(
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
    if (!_canViewExamReports && !_canTakeSubjectAttendance) {
      return const [];
    }

    return <_SidebarChildLink>[
      if (_canViewExamReports)
        _SidebarChildLink(
          label: 'Exam Reports',
          icon: Icons.assessment_outlined,
          onPressed: () => _openScreen(
            ExamReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      if (_canViewExamReports)
        _SidebarChildLink(
          label: 'Class Report',
          icon: Icons.leaderboard_outlined,
          onPressed: () => _openScreen(
            ClassReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      if (_canTakeSubjectAttendance)
        _SidebarChildLink(
          label: 'Subject Attendance Report',
          icon: Icons.analytics_outlined,
          onPressed: () => _openScreen(
            SubjectAttendanceReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
    ];
  }

  List<_SidebarChildLink> _examsSidebarLinks() {
    final links = <_SidebarChildLink>[];

    if (_canEnterExamMarks) {
      links.add(
        _SidebarChildLink(
          label: 'Exam Mark Entry',
          icon: Icons.edit_note_outlined,
          onPressed: () => _openScreen(
            ExamMarkEntryScreen(
              api: widget.api,
              token: widget.session.token,
              canViewMarks: widget.session.hasPermission('marks.view'),
            ),
          ),
        ),
      );
    }

    if (_canViewExamReports) {
      links.add(
        _SidebarChildLink(
          label: 'Exam Reports',
          icon: Icons.assessment_outlined,
          onPressed: () => _openScreen(
            ExamReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );
    }

    return links;
  }

  List<_SidebarChildLink> _financeSidebarLinks() {
    final links = <_SidebarChildLink>[
      _SidebarChildLink(
        label: 'Fee Structures',
        icon: Icons.request_quote_outlined,
        onPressed: () => _openScreen(
          FeeStructuresScreen(
            api: widget.api,
            token: widget.session.token,
          ),
        ),
      ),
      _SidebarChildLink(
        label: 'Fee Invoices',
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
          label: 'Fee Payments',
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

    if (widget.session.hasPermission('expenses.view')) {
      links.add(
        _SidebarChildLink(
          label: 'Expenses',
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

      links.add(
        _SidebarChildLink(
          label: 'Subject Attendance Report',
          icon: Icons.analytics_outlined,
          onPressed: () => _openScreen(
            SubjectAttendanceReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );

      links.add(
        _SidebarChildLink(
          label: 'Class Report',
          icon: Icons.leaderboard_outlined,
          onPressed: () => _openScreen(
            ClassReportScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
      );
    }

    if (_canViewSubjectTimetable) {
      links.add(
        _SidebarChildLink(
          label: 'Subject Timetable',
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

    if (widget.session.hasPermission('petty_cash.view')) {
      links.add(
        _SidebarChildLink(
          label: 'Petty Cash',
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
          label: 'Payment Methods',
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

    return links;
  }

  List<_SidebarChildLink> _transportSidebarLinks() {
    if (!_canViewBuses) {
      return const [];
    }

    return <_SidebarChildLink>[
      _SidebarChildLink(
        label: 'Buses',
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
          label: 'Staff',
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
          label: 'Tasks',
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
          label: 'Teachers',
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
          label: 'Documents',
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
          label: 'Users',
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
          label: 'Roles',
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
          label: 'Audit Logs',
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
          label: 'Academic Years',
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
          label: 'Promotions',
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
          label: 'Terms',
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
          label: 'Subjects',
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

    if (_canViewSubjectTimetable) {
      links.add(
        _SidebarChildLink(
          label: 'Subject Timetable',
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

    if (_canViewLevels) {
      links.add(
        _SidebarChildLink(
          label: 'Levels',
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
          label: 'Classes',
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

  List<_SidebarChildLink> _settingsSidebarLinks() {
    final links = <_SidebarChildLink>[];

    if (_isSchoolAdmin) {
      links.addAll([
        _SidebarChildLink(
          label: 'Messaging',
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
          label: 'Backup & Restore',
          icon: Icons.archive_outlined,
          onPressed: () => _openScreen(
            BackupRestoreScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
        _SidebarChildLink(
          label: 'General',
          icon: Icons.settings_outlined,
          onPressed: () => _openScreen(
            GeneralSettingsScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
        _SidebarChildLink(
          label: 'Setup Config',
          icon: Icons.tune_outlined,
          onPressed: () => _openScreen(
            SetupConfigScreen(
              api: widget.api,
              token: widget.session.token,
            ),
          ),
        ),
        _SidebarChildLink(
          label: 'Grade Setup',
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
          label: 'Attendance Settings',
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
    final cards = <SummaryCardData>[
      SummaryCardData(
        label: 'Students',
        value: widget.dashboard?.studentsLabel ?? '--',
        tone: const Color(0xFFE0F2FE),
      ),
      SummaryCardData(
        label: 'Teachers',
        value: widget.dashboard?.teachersLabel ?? '--',
        tone: const Color(0xFFFEF3C7),
      ),
      SummaryCardData(
        label: 'Subjects',
        value: widget.dashboard?.subjectsLabel ?? '--',
        tone: const Color(0xFFDCFCE7),
      ),
      SummaryCardData(
        label: 'Attendance',
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
                  children: widget.session.roles
                      .map(
                        (role) => Chip(
                          label: Text(role),
                          backgroundColor: Colors.white.withOpacity(0.18),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Overview', style: theme.textTheme.titleLarge),
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
                  Text('Monthly revenue', style: theme.textTheme.titleLarge),
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
      title: 'Students',
      description:
          'Open the student roster and drill into profiles from one place.',
      modules: _studentSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildAttendancePage() {
    return _buildOverviewPage(
      title: 'Attendance',
      description: 'Open the attendance tools that match the signed-in role.',
      modules: _attendanceSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildReportsPage() {
    return _buildOverviewPage(
      title: 'Reports',
      description: 'Open exam reports and summaries.',
      modules: _reportsSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildExamsPage() {
    return _buildOverviewPage(
      title: 'Exams',
      description: 'Manage exams, marks, and reports.',
      modules: _examsSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildHrPage() {
    return _buildOverviewPage(
      title: 'HR',
      description: 'Manage staff, teachers, documents, users, and roles.',
      modules: _hrSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildAcademicPage() {
    return _buildOverviewPage(
      title: 'Academic',
      description: 'Academic tools and planning modules.',
      modules: _academicSidebarLinks().map((link) => link.label).toList(),
      emptyMessage:
          'Academic tools will appear here once they are enabled for your role.',
    );
  }

  Widget _buildFeesPage() {
    return _buildOverviewPage(
      title: 'Fees',
      description: 'Manage school billing, invoices, and payment workflows.',
      modules: _financeSidebarLinks().map((link) => link.label).toList(),
    );
  }

  Widget _buildSettingsPage() {
    return _buildOverviewPage(
      title: 'Settings',
      description: 'Manage school configuration and attendance defaults.',
      modules: _settingsSidebarLinks().map((link) => link.label).toList(),
      footer: _buildPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signed in as', style: Theme.of(context).textTheme.titleLarge),
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
    final activeMessage =
        emptyMessage ?? 'Use the sidebar sub-links to open a module.';

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
              Text('Overview', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Modules available: ${modules.length}',
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
                  'Open a module using the sidebar sub-links.',
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

  Widget _buildStatusBanner() {
    final message = widget.statusMessage;
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: widget.usingOfflineData
          ? const Color(0xFFFFF4CE)
          : const Color(0xFFE8F5E9),
      child: Row(
        children: [
          Icon(
            widget.usingOfflineData ? Icons.cloud_off_outlined : Icons.info_outline,
            size: 18,
            color: const Color(0xFF7A4F01),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A4F01),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportPage() {
    return _buildOverviewPage(
      title: 'Transport',
      description:
          'Manage buses, assign students, and track transport coverage across the school.',
      modules: _transportSidebarLinks().map((link) => link.label).toList(),
      emptyMessage: 'No transport modules are available for this account yet.',
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
              '${destination.label} Modules',
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
              schoolName: widget.session.schoolName ?? 'Kullmis School',
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
                    onRefresh: widget.onRefresh,
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

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(
              useRail
                  ? widget.session.schoolName ?? 'Kullmis School Mobile'
                  : selectedDestination.label,
            ),
            actions: [
              IconButton(
                onPressed: () async => widget.onRefresh(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              IconButton(
                onPressed: () async => widget.onLogout(),
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
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
                            widget.session.schoolName ?? 'Kullmis School',
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
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: destinations
                      .map(
                        (destination) => NavigationDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: destination.label,
                        ),
                      )
                      .toList(),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.12),
                    child: Icon(
                      Icons.school_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      schoolName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  final selected = index == selectedIndex;
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
                        onTap: () {
                          if (destination.showChildren &&
                              destination.sidebarChildren.isNotEmpty) {
                            onDestinationExpanded(index);
                            return;
                          }

                          onDestinationSelected(index);
                        },
                      ),
                      if (showChildren)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 6),
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
                'Kullmis School System',
                style: theme.textTheme.bodyMedium,
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
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () async => onTap(),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
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
    required this.onRefresh,
    required this.onLogout,
  });

  final String title;
  final String userName;
  final String userEmail;
  final Future<void> Function() onRefresh;
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(userName, style: theme.textTheme.bodyLarge),
              Text(userEmail, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () async => onRefresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          TextButton.icon(
            onPressed: () async => onLogout(),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

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
