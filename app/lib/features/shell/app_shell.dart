import 'package:flutter/material.dart';
import '../../data/sample.dart';
import '../day/day_screen.dart';
import '../home/home_screen.dart';
import '../patterns/patterns_screen.dart';
import '../../theme/soul_theme.dart';

/// The tab shell.
///
/// The original designs had no tab bar. Home was the hub and everything was
/// pushed on top of it. Tabs were added because moving between the week, a
/// single day and the patterns is the thing you do most, and pushing and
/// popping to reach them made the product feel deeper than it is.
///
/// Capture is not a tab. It is the raised button in the middle, because it is
/// an action rather than a place, and it is the only thing on this bar the
/// student is ever encouraged to do.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onCapture, this.momentsThisWeek = 12});

  final VoidCallback onCapture;
  final int momentsThisWeek;

  bool get _dayOne => momentsThisWeek == 0;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoulColors.bg,
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: [
              HomeScreen(
                momentsThisWeek: widget.momentsThisWeek,
                // Nothing is being held on day one, because nothing has been
                // decided yet.
                heldDecision: widget._dayOne ? null : Sample.heldDecision,
                showFooter: false,
                onCapture: widget.onCapture,
                onOpenDay: (_) => setState(() => _tab = 1),
                onOpenPatterns: () => setState(() => _tab = 2),
                onOutcome: widget.onCapture,
              ),
              DayScreen(day: 'Tuesday', onBack: () => setState(() => _tab = 0)),
              const PatternsScreen(reflectionCount: 34),
            ],
          ),
          // Capture floats clear of the bar rather than sitting inside it.
          // Three destinations do not divide evenly around a centre button, and
          // a lopsided bar looks like a mistake.
          Positioned(
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onTap: widget.onCapture,
              child: Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  color: SoulColors.clay,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4DEA5F17),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _TabBar(
        current: _tab,
        onChanged: (tab) => setState(() => _tab = tab),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onChanged});

  final int current;
  final ValueChanged<int> onChanged;

  static const _tabs = [
    (icon: Icons.circle_outlined, label: 'This week'),
    (icon: Icons.view_day_outlined, label: 'Days'),
    (icon: Icons.auto_awesome_outlined, label: 'Returning'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SoulColors.s1,
        boxShadow: [
          BoxShadow(color: SoulColors.shade, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _Tab(
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: current == i,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? SoulColors.clay : SoulColors.text3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: colour),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: SoulType.sans,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}
