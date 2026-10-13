import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../models/auth_session.dart';
import '../models/dashboard_data.dart';

const _teal = Color(0xFF0F766E);
const _ink = Color(0xFF101828);
const _muted = Color(0xFF667085);

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({
    super.key,
    required this.session,
    required this.dashboard,
    required this.onRefresh,
    this.onStudents,
    this.onTeachers,
    this.onSubjects,
    this.onAttendance,
  });

  final AuthSession session;
  final DashboardData? dashboard;
  final Future<void> Function() onRefresh;
  final VoidCallback? onStudents, onTeachers, onSubjects, onAttendance;

  @override
  Widget build(BuildContext context) {
    final data = dashboard;
    final roles =
        session.roles.map((role) => role.replaceAll('_', ' ')).join(' · ');
    final cards = <Widget>[
      _MetricCard(
          label: context.tr('students'),
          value: data?.studentsLabel ?? '--',
          icon: Icons.groups,
          background: const Color(0xFFECF8FF),
          accent: const Color(0xFF0879BF),
          onTap: onStudents),
      _MetricCard(
          label: context.tr('teachers'),
          value: data?.teachersLabel ?? '--',
          icon: Icons.co_present,
          background: const Color(0xFFFFF9E5),
          accent: const Color(0xFFA76B00),
          onTap: onTeachers),
      _MetricCard(
          label: context.tr('subjects'),
          value: data?.subjectsLabel ?? '--',
          icon: Icons.menu_book,
          background: const Color(0xFFE6FBF3),
          accent: _teal,
          onTap: onSubjects),
      _MetricCard(
          label: context.tr('attendance'),
          value: data?.attendanceLabel ?? '--',
          icon: Icons.calendar_month,
          background: const Color(0xFFFFEEF5),
          accent: const Color(0xFFB4134A),
          caption: context.tr('today', 'Today'),
          onTap: onAttendance),
    ];
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
        children: [
          Text('Welcome back, ${session.name} \u{1F44B}',
              style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF086562),
                  Color(0xFF16847B),
                  Color(0xFFCA8B30)
                ],
                stops: [0, .65, 1],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFE0FAF5),
                  child: Icon(Icons.school, color: _teal, size: 30)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(session.schoolName ?? context.tr('kullmis_school'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(session.name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                    Text(session.email,
                        style: const TextStyle(
                            color: Color(0xFFCFEBE6), fontSize: 12)),
                    if (roles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.verified_user,
                              size: 14, color: _teal),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(roles,
                                  style: const TextStyle(
                                      color: _teal,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11))),
                        ]),
                      ),
                    ],
                  ])),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: Text(context.tr('overview'),
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: _ink))),
            const _PeriodBadge(
                label: 'Current overview', icon: Icons.calendar_today_outlined),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 4
                : constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(14) > 21
                    ? 1
                    : 2;
            return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards
                    .map((card) => SizedBox(
                        width: (constraints.maxWidth - (columns - 1) * 10) /
                            columns,
                        child: card))
                    .toList());
          }),
          const SizedBox(height: 14),
          if (data == null)
            const _Panel(
                child:
                    Text('Dashboard data is not available for this account.'))
          else ...[
            if (session.hasPermission('dashboard.summary.view')) ...[
              _Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      const _TileIcon(icon: Icons.savings_outlined),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: Text('Revenue this month',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _ink))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                            color: data.revenueGrowthPercent < 0
                                ? const Color(0xFFFFEEF3)
                                : const Color(0xFFE4F6EF),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                            '${data.revenueGrowthPercent < 0 ? '\u2198' : '\u2197'} ${data.growthLabel}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: data.revenueGrowthPercent < 0
                                    ? const Color(0xFFB4134A)
                                    : _teal)),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Text(_money(data.revenueTotal),
                        style: const TextStyle(
                            color: _teal,
                            fontSize: 32,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    const Text('Total income this month',
                        style: TextStyle(color: _muted, fontSize: 13)),
                  ])),
              const SizedBox(height: 14),
            ],
            if (session.hasPermission('dashboard.finance_charts.view'))
              _Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      const _TileIcon(icon: Icons.bar_chart),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              context.tr('monthly_revenue', 'Monthly Revenue'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _ink))),
                    ]),
                    const SizedBox(height: 18),
                    if (data.monthTotals.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('No monthly revenue data available.'))
                    else ...[
                      _RevenueChart(months: data.monthTotals),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, constraints) {
                        final highest = data.monthTotals
                            .reduce((a, b) => a.total >= b.total ? a : b);
                        final lowest = data.monthTotals
                            .reduce((a, b) => a.total <= b.total ? a : b);
                        final width = constraints.maxWidth < 290
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 10) / 2;
                        return Wrap(spacing: 10, runSpacing: 10, children: [
                          SizedBox(
                              width: width,
                              child: _ExtremeMonth(
                                  label: 'Highest Month',
                                  month: highest,
                                  highest: true)),
                          SizedBox(
                              width: width,
                              child: _ExtremeMonth(
                                  label: 'Lowest Month',
                                  month: lowest,
                                  highest: false)),
                        ]);
                      }),
                    ],
                  ])),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.background,
      required this.accent,
      this.onTap,
      this.caption});
  final String label, value;
  final String? caption;
  final IconData icon;
  final Color background, accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 38,
                  height: 42,
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(18)),
                  child: Icon(icon, color: accent, size: 24)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: const TextStyle(color: _muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    if (caption != null)
                      Text(caption!,
                          style: const TextStyle(color: _muted, fontSize: 10)),
                  ])),
              if (onTap != null)
                const Padding(
                    padding: EdgeInsets.only(top: 17),
                    child: Icon(Icons.chevron_right, size: 16, color: _muted)),
            ]),
          ),
        ),
      );
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.months});
  final List<MonthlyTotal> months;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final maximum = months.fold<double>(
        0, (value, month) => math.max(value, month.total.abs()));
    final ceiling = maximum == 0 ? 100.0 : maximum * 1.2;
    return LayoutBuilder(builder: (context, constraints) {
      final chartWidth = math.max(
          constraints.maxWidth - 38 * scale, months.length * 52.0 * scale);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 38 * scale,
            height: 160 * scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                  5,
                  (i) => Text(_axis(ceiling * (4 - i) / 4),
                      style: const TextStyle(fontSize: 9, color: _muted))),
            )),
        Expanded(
            child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
              width: chartWidth,
              height: 190 * scale,
              child: Stack(children: [
                Positioned(
                    top: 6 * scale,
                    left: 0,
                    right: 0,
                    height: 148 * scale,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                            5,
                            (_) => const Divider(
                                height: 1, color: Color(0xFFEDF0F2))))),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: months.map((month) {
                      final height = (month.total.abs() / ceiling * 148 * scale)
                          .clamp(2.0, 148.0 * scale);
                      return Expanded(
                          child: Semantics(
                        label: '${month.label}: ${_money(month.total)}',
                        child: Tooltip(
                          message: '${month.label}: ${_money(month.total)}',
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(_axis(month.total),
                                    style: const TextStyle(
                                        fontSize: 9, color: _ink)),
                                SizedBox(height: 5 * scale),
                                Container(
                                    height: height,
                                    width: 28,
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: month.total < 0
                                                ? [
                                                    const Color(0xFFE8889D),
                                                    const Color(0xFFB4134A)
                                                  ]
                                                : [
                                                    const Color(0xFF3ABAA3),
                                                    const Color(0xFF00836F)
                                                  ]),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(5)))),
                                SizedBox(height: 10 * scale),
                                SizedBox(
                                    height: 25 * scale,
                                    child: Text(month.label,
                                        style: const TextStyle(
                                            fontSize: 10, color: _muted))),
                              ]),
                        ),
                      ));
                    }).toList()),
              ])),
        )),
      ]);
    });
  }
}

class _ExtremeMonth extends StatelessWidget {
  const _ExtremeMonth(
      {required this.label, required this.month, required this.highest});
  final String label;
  final MonthlyTotal month;
  final bool highest;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: highest ? const Color(0xFFEDFAF5) : const Color(0xFFFFF1F5),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(highest ? Icons.north_east : Icons.south,
              size: 24, color: highest ? _teal : const Color(0xFFB4134A)),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: _muted)),
                Text(_money(month.total),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                Text(month.label,
                    style: const TextStyle(fontSize: 11, color: _muted)),
              ])),
        ]),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: child,
      );
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: const Color(0xFFDEFAF0),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _teal, size: 22),
      );
}

class _PeriodBadge extends StatelessWidget {
  const _PeriodBadge({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E7EC))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: _ink),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: _ink)),
        ]),
      );
}

String _money(double value) {
  final parts = value.abs().toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
      RegExp(r'([0-9])(?=([0-9]{3})+$)'), (match) => '${match[1]},');
  return '${value < 0 ? '-' : ''}\$ $whole.${parts.last}';
}

String _axis(double value) => value.abs() >= 1000
    ? '${(value / 1000).toStringAsFixed(1)}k'
    : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
