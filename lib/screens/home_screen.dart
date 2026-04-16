import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/dashboard_data.dart';
import '../services/laravel_api.dart';
import '../widgets/summary_card.dart';
import 'discipline_incidents_screen.dart';
import 'exam_mark_entry_screen.dart';
import 'exam_report_screen.dart';
import 'fee_invoices_screen.dart';
import 'fee_payments_screen.dart';
import 'fee_structures_screen.dart';
import 'main_attendance_screen.dart';
import 'student_list_screen.dart';
import 'subject_attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.dashboard,
    required this.api,
    required this.onRefresh,
    required this.onLogout,
  });

  final AuthSession session;
  final DashboardData? dashboard;
  final LaravelApi api;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  bool get _canTakeMainAttendance => widget.session.hasAnyPermission(const [
        'attendance.view',
        'attendance.create',
        'attendance.edit',
      ]);

  bool get _canTakeSubjectAttendance => widget.session.hasAnyPermission(const [
        'subject_attendance.view',
        'subject_attendance.create',
      ]);

  bool get _canViewStudents => widget.session.hasPermission('students.view');

  bool get _canViewDisciplineIncidents =>
      widget.session.hasAnyPermission(const [
        'discipline_incidents.view',
        'discipline_incidents.report.view',
      ]);

  bool get _canViewFees => widget.session.hasAnyPermission(const [
        'fees.view',
        'fees.generate',
        'fees.pay',
      ]);

  bool get _canEnterExamMarks => widget.session.hasAnyPermission(const [
        'marks.create',
        'marks.view',
        'exams.view',
      ]);

  bool get _canViewExamReports => widget.session.hasPermission('marks.view');

  bool get _canPayFees => widget.session.hasPermission('fees.pay');

  List<_ShellDestination> _destinations() {
    final destinations = <_ShellDestination>[
      _ShellDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        builder: _buildDashboardPage,
      ),
    ];

    if (_canViewStudents) {
      destinations.add(
        _ShellDestination(
          label: 'Students',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups,
          builder: _buildStudentsPage,
        ),
      );
    }

    if (_canTakeMainAttendance || _canTakeSubjectAttendance) {
      destinations.add(
        _ShellDestination(
          label: 'Attendance',
          icon: Icons.how_to_reg_outlined,
          selectedIcon: Icons.how_to_reg,
          builder: _buildAttendancePage,
        ),
      );
    }

    if (_canViewFees) {
      destinations.add(
        _ShellDestination(
          label: 'Fees',
          icon: Icons.request_quote_outlined,
          selectedIcon: Icons.request_quote,
          builder: _buildFeesPage,
        ),
      );
    }

    destinations.add(
      _ShellDestination(
        label: 'More',
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view,
        builder: _buildMorePage,
      ),
    );

    return destinations;
  }

  Future<void> _openScreen(Widget screen) {
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
    return _buildSectionPage(
      title: 'Students',
      description:
          'Open the student roster and drill into profiles from one place.',
      actions: [
        _SectionAction(
          title: 'Student List',
          description: 'Browse students by level and class.',
          icon: Icons.groups_outlined,
          onPressed: () => _openScreen(
            StudentListScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendancePage() {
    final actions = <_SectionAction>[];

    if (_canTakeMainAttendance) {
      actions.add(
        _SectionAction(
          title: 'Daily Attendance',
          description: 'Take and update whole-class attendance by shift.',
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
      actions.add(
        _SectionAction(
          title: 'Subject Attendance',
          description: 'Record attendance for a subject period.',
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

    return _buildSectionPage(
      title: 'Attendance',
      description: 'Open the attendance tools that match the signed-in role.',
      actions: actions,
    );
  }

  Widget _buildFeesPage() {
    final actions = <_SectionAction>[
      _SectionAction(
        title: 'Fee Structures',
        description: 'Review fee setup for the active academic year.',
        icon: Icons.request_quote_outlined,
        onPressed: () => _openScreen(
          FeeStructuresScreen(
            api: widget.api,
            token: widget.session.token,
          ),
        ),
      ),
      _SectionAction(
        title: 'Fee Invoices',
        description: 'Filter invoices and generate new billing runs.',
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
      actions.add(
        _SectionAction(
          title: 'Fee Payments',
          description: 'Capture and review invoice payments.',
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

    return _buildSectionPage(
      title: 'Fees',
      description: 'Manage school billing, invoices, and payment workflows.',
      actions: actions,
    );
  }

  Widget _buildMorePage() {
    final theme = Theme.of(context);
    final actions = <_SectionAction>[];

    if (_canEnterExamMarks) {
      actions.add(
        _SectionAction(
          title: 'Exam Mark Entry',
          description: 'Enter marks for the selected exam and subject.',
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
      actions.add(
        _SectionAction(
          title: 'Exam Reports',
          description: 'Review published report card and exam outcomes.',
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

    if (_canViewDisciplineIncidents) {
      actions.add(
        _SectionAction(
          title: 'Discipline Incidents',
          description: 'Track and review student incident records.',
          icon: Icons.report_problem_outlined,
          onPressed: () => _openScreen(
            DisciplineIncidentsScreen(
              api: widget.api,
              token: widget.session.token,
              session: widget.session,
            ),
          ),
        ),
      );
    }

    actions.addAll([
      _SectionAction(
        title: 'Refresh Dashboard',
        description: 'Reload the latest dashboard and session data.',
        icon: Icons.refresh,
        onPressed: widget.onRefresh,
      ),
      _SectionAction(
        title: 'Sign Out',
        description: 'Clear the current token and return to login.',
        icon: Icons.logout,
        onPressed: widget.onLogout,
      ),
    ]);

    return _buildSectionPage(
      title: 'More',
      description: 'Open the extra school tools and account actions.',
      actions: actions,
      footer: _buildPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signed in as', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.session.name, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(widget.session.email, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionPage({
    required String title,
    required String description,
    required List<_SectionAction> actions,
    Widget? footer,
  }) {
    final theme = Theme.of(context);

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
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: actions
                .map((action) => _SectionActionCard(action: action))
                .toList(),
          ),
        ] else ...[
          const SizedBox(height: 16),
          _buildPanel(
            child: Text(
              'No tools are available for this section with the current role.',
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinations = _destinations();
    final selectedIndex = _selectedIndex.clamp(0, destinations.length - 1);
    final selectedDestination = destinations[selectedIndex];

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
                  child: selectedDestination.builder(),
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

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
}

class _SectionAction {
  const _SectionAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final Future<void> Function() onPressed;
}

class _SectionActionCard extends StatelessWidget {
  const _SectionActionCard({required this.action});

  final _SectionAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 280,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(action.icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(action.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(action.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async => action.onPressed(),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Open'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
