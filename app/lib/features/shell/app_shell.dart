import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../people/people_screen.dart';
import '../profile/profile_tab.dart';
import '../day/days_screen.dart';
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
/// user is ever encouraged to do.
///
/// Profile is the fourth destination. It is last because it is the one a
/// user visits rarely and on purpose, and it is a tab rather than a menu
/// because what the app holds about somebody should not be hidden behind a
/// gear.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.onCapture,
    this.revision = 0,
    this.name,
  });

  final VoidCallback onCapture;

  /// Changes when an entry lands, so the tabs behind the capture screen go and
  /// read again instead of showing what was true a minute ago.
  final int revision;

  final String? name;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _api = SoulApi.fromEnvironment();
  int _tab = 0;

  /// Which day the Days tab should open, when the user picked one from the
  /// week strip. Null means the list decides, and it opens the newest.
  String? _day;

  void _openDay(String date) => setState(() {
        _day = date;
        _tab = 1;
      });

  /// The profile is a screen of its own now rather than a fifth tab. It is
  /// read now and then and changed rarely, which is not what a place in the
  /// bar is for.
  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (route) => ProfileTab(
          api: _api,
          onBack: () => Navigator.of(route).maybePop(),
        ),
      ),
    );
  }

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
                api: _api,
                name: widget.name,
                onOpenProfile: _openProfile,
                revision: widget.revision,
                showFooter: false,
                onCapture: widget.onCapture,
                onOpenDay: _openDay,
                onOpenPatterns: () => setState(() => _tab = 2),
              ),
              DaysScreen(api: _api, revision: widget.revision, openOn: _day),
              PatternsScreen(api: _api, revision: widget.revision),
              PeopleScreen(api: _api, revision: widget.revision),
            ],
          ),
          // Capture sits in the middle of the bar, raised out of it. Four
          // destinations divide evenly around a centre button; five did not,
          // which is why it used to sit off in the corner.
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
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
    (icon: Icons.people_outline, label: 'People'),
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
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: _Tab(
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: current == i,
                    onTap: () => onChanged(i),
                  ),
                ),
              // The gap the capture button sits in.
              const SizedBox(width: 78),
              for (var i = 2; i < _tabs.length; i++)
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
              // Five labels across a 375 point phone leaves about 66 points
              // each. Eleven points truncated This week and Returning, so the
              // label steps down and the letter spacing comes out.
              fontSize: 10,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}
