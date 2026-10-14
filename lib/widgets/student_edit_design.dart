import 'package:flutter/material.dart';

const studentTeal = Color(0xFF007F73);
const studentInk = Color(0xFF101B35);

class StudentSection extends StatelessWidget {
  const StudentSection(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.children});
  final String title, subtitle;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFE1F4EF),
                child: Icon(icon, color: studentTeal, size: 28)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: studentInk)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF748094))),
                ])),
          ]),
          const SizedBox(height: 22),
          ...children,
        ]),
      );
}

class StudentField extends StatelessWidget {
  const StudentField(
      {super.key,
      required this.label,
      required this.icon,
      required this.child,
      this.required = false});
  final String label;
  final IconData icon;
  final Widget child;
  final bool required;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Icon(icon, size: 22, color: const Color(0xFF526178))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text.rich(
                    TextSpan(text: label, children: [
                      if (required)
                        const TextSpan(
                            text: ' *', style: TextStyle(color: Colors.red))
                    ]),
                    style: const TextStyle(
                        color: Color(0xFF526178), fontSize: 13)),
                const SizedBox(height: 6),
                child,
              ])),
        ]),
      );
}

InputDecoration studentInput({String? hint}) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD7DDE4))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD7DDE4))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: studentTeal, width: 1.5)),
    );

class StudentFooter extends StatelessWidget {
  const StudentFooter(
      {super.key,
      required this.backLabel,
      required this.nextLabel,
      required this.onBack,
      required this.onNext,
      this.busy = false,
      this.backIcon = Icons.arrow_back,
      this.nextIcon = Icons.save});
  final String backLabel, nextLabel;
  final VoidCallback? onBack, onNext;
  final bool busy;
  final IconData backIcon, nextIcon;

  @override
  Widget build(BuildContext context) {
    Widget content(IconData icon, String label, {bool progress = false}) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (progress)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 20),
            const SizedBox(width: 8),
            Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center)),
          ],
        );
    final back = SizedBox(
        height: 56,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy ? null : onBack,
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: studentTeal,
              side: const BorderSide(color: studentTeal, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: content(backIcon, backLabel),
        ));
    final next = SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : onNext,
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: studentTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: content(nextIcon, nextLabel, progress: busy),
        ));
    return Container(
        color: Colors.white,
        child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 388 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18) {
                  return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [back, const SizedBox(height: 8), next]);
                }
                return Row(children: [
                  Expanded(child: back),
                  const SizedBox(width: 10),
                  Expanded(child: next)
                ]);
              }),
            )));
  }
}
