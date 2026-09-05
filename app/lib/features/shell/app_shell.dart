import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../people/people_screen.dart';
import '../profile/profile_tab.dart';
import '../day/day_screen.dart';
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

  final void Function({String? prompt, String? note}) onCapture;

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

  /// The day opens on top of wherever it was asked for, so back goes back
  /// there. It used to switch to the Days tab and open from inside it, which
  /// meant tapping a day on home and pressing back landed on a different
  /// screen from the one that was left.
  Future<void> _openDay(String date) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) => DayScreen(
          api: _api,
          date: date,
          onBack: () => Navigator.of(page).pop(),
          onCapture: () => widget.onCapture(),
        ),
      ),
    );
    // An entry written from that page changes the week behind it.
    if (mounted) setState(() {});
  }

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
      body: IndexedStack(
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
          DaysScreen(
            api: _api,
            revision: widget.revision,
            onCapture: () => widget.onCapture(),
          ),
          PatternsScreen(api: _api, revision: widget.revision),
          PeopleScreen(api: _api, revision: widget.revision),
        ],
      ),
      bottomNavigationBar: _TabBar(
        current: _tab,
        onChanged: (tab) => setState(() => _tab = tab),
        onCapture: () => widget.onCapture(),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.current,
    required this.onChanged,
    required this.onCapture,
  });

  final int current;
  final ValueChanged<int> onChanged;

  /// Capture sits in the row with the four destinations rather than floating
  /// above it. It is the middle of five things on one line, which is where
  /// the thumb already is.
  final VoidCallback onCapture;

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
              SizedBox(
                width: 78,
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCapture,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: SoulColors.clay,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33EA5F17),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
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
