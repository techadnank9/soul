import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'reflection_screen.dart';

/// Screen 10. What keeps coming back, and what it is doing to the student.
///
/// This screen used to be a record and nothing more. It now says which of the
/// things that keep returning are worth keeping and which are worth stopping,
/// because a student who has written for months and been handed back a tidy
/// list of themes has been given a filing cabinet rather than an answer.
///
/// The sentence under each theme is the whole of the verdict and the server
/// wrote it out of that student's own situation. Nothing on this screen adds a
/// word to it, ranks the two groups against each other or counts anything up
/// into a total: the app is allowed to say what a pattern is costing them, and
/// is not allowed to turn that into a mark out of ten.
///
/// The two groups are told apart by colour and by two words, moss and worth
/// keeping against clay and worth stopping. Both carry the same amount of
/// language, the same shape and the same size, so neither reads as the prize
/// and neither reads as the telling off. Red was never in this palette and is
/// not being added to it for this.
class PatternsScreen extends StatefulWidget {
  const PatternsScreen({super.key, required this.api, this.revision = 0});

  final SoulApi api;

  /// Changes when an entry lands. A new entry can be the one that makes a
  /// candidate, so this screen goes and asks again rather than holding what it
  /// had.
  final int revision;

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  PatternsView? _patterns;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PatternsScreen old) {
    super.didUpdateWidget(old);
    if (widget.revision != old.revision) _load();
  }

  Future<void> _load() async {
    setState(() {
      _patterns = null;
      _failed = false;
    });
    try {
      final patterns = await widget.api.patterns();
      if (mounted) setState(() => _patterns = patterns);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Opens the reflection on its own page and reloads on the way back, since
  /// answering a check back from there can move a theme between sections.
  Future<void> _open(String theme) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) => ReflectionScreen(
          api: widget.api,
          theme: theme,
          onBack: () => Navigator.of(page).pop(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Screen(
        body: [
          const SizedBox(height: 40),
          const Text('Not loaded', style: SoulType.heading),
          const SizedBox(height: 14),
          const Text(
            'The app could not reach your patterns just now. They are still '
            'there.',
            style: SoulType.secondary,
          ),
          const SizedBox(height: 22),
          // Without this the tab is dead for the life of the app.
          SoulButton('Try again', onPressed: _load),
        ],
      );
    }

    final patterns = _patterns;
    if (patterns == null) {
      return const Screen(
        body: [
          SizedBox(height: 120),
          Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SoulColors.clay,
              ),
            ),
          ),
        ],
      );
    }

    // A theme whose sentence did not arrive is not shown at all. The sentence
    // is the whole of what the app is saying, and a name sitting under Worth
    // stopping with nothing under it is the verdict without the reason.
    final good = _said(patterns.good);
    final bad = _said(patterns.bad);

    // Months of entries can go by before anything comes back often enough to
    // be worth a sentence, so this is the ordinary state for a long time. It
    // says the one plain thing rather than showing three empty frames.
    if (good.isEmpty && bad.isEmpty && patterns.forming.isEmpty) {
      return const Screen(
        body: [
          SizedBox(height: 40),
          Text('Nothing has repeated yet', style: SoulType.heading),
        ],
      );
    }

    return Screen(body: _sections(patterns, good, bad));
  }

  /// The themes there is something to say about, in the order they arrived.
  static List<JudgedTheme> _said(List<JudgedTheme> themes) =>
      [for (final theme in themes) if (theme.line.trim().isNotEmpty) theme];

  List<Widget> _sections(
    PatternsView patterns,
    List<JudgedTheme> good,
    List<JudgedTheme> bad,
  ) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text(
            'So far',
            style: TextStyle(
              fontFamily: SoulType.serif,
              fontSize: 26,
              color: SoulColors.text,
            ),
          ),
          Label(_from(patterns.reflections)),
        ],
      ),
      const SizedBox(height: 22),

      // An empty group is missing entirely, and says nothing about itself. A
      // student with two things worth keeping and nothing worth stopping
      // should see one section, not one section and a hole where the other
      // would go.
      //
      // The exception is the one that matters. When there is nothing worth
      // keeping and something worth stopping, hiding the empty section leaves
      // a screen that is nothing but a verdict against them. It stays, and it
      // says plainly that this half is empty rather than implying there was
      // nothing to find.
      if (good.isNotEmpty)
        ..._section(
          heading: 'Worth keeping',
          mark: SoulColors.moss,
          rows: [
            for (final theme in good)
              _Row(
                theme: theme.theme,
                detail: _facts(theme),
                mark: SoulColors.moss,
                times: theme.times,
                onTap: () => _open(theme.theme),
              ),
          ],
        )
      else if (bad.isNotEmpty)
        ..._section(
          heading: 'Worth keeping',
          mark: SoulColors.moss,
          rows: const [
            Text(
              'Nothing here yet. This fills in when the app asks how something '
              'went and you say it went better.',
              style: SoulType.secondary,
            ),
          ],
        ),
      if (bad.isNotEmpty)
        ..._section(
          heading: 'Worth stopping',
          mark: SoulColors.clay,
          rows: [
            for (final theme in bad)
              _Row(
                theme: theme.theme,
                detail: _facts(theme),
                mark: SoulColors.clay,
                times: theme.times,
                onTap: () => _open(theme.theme),
              ),
          ],
        ),
      if (patterns.forming.isNotEmpty)
        ..._section(
          heading: 'Still forming',
          label: 'not enough to say yet',
          mark: SoulColors.border2,
          settled: false,
          rows: [
            for (final pattern in patterns.forming)
              _Row(
                theme: pattern.theme,
                detail: _entries(pattern.supporting),
                mark: SoulColors.border2,
              ),
          ],
        ),
      const SizedBox(height: 40),
    ];
  }

  /// A heading, a dot in the group's colour, and the rows in one card.
  ///
  /// The card is tinted and outlined in the same colour as the dot, which is
  /// what makes the two groups different before a word of either is read. The
  /// forming group takes the quiet colour and no outline, because it is not
  /// claiming anything yet.
  static List<Widget> _section({
    required String heading,
    String? label,
    required Color mark,
    required List<Widget> rows,
    bool settled = true,
  }) {
    return [
      Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: mark, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Text(
            heading,
            style: const TextStyle(
              fontFamily: SoulType.sans,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: SoulColors.text,
            ),
          ),
        ],
      ),
      if (label != null) ...[
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Label(label),
        ),
      ],
      const SizedBox(height: 12),
      SoulCard(
        padding: const EdgeInsets.all(16),
        background: settled ? mark.withValues(alpha: 0.07) : SoulColors.s2,
        borderColor: settled ? mark.withValues(alpha: 0.45) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              // A line between rows, because each one is three lines deep now
              // and without it two themes read as one long paragraph.
              if (i > 0) ...[
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: settled
                      ? mark.withValues(alpha: 0.22)
                      : SoulColors.border,
                ),
                const SizedBox(height: 16),
              ],
              rows[i],
            ],
          ],
        ),
      ),
      const SizedBox(height: 26),
    ];
  }

  static String _from(int reflections) => reflections == 1
      ? 'from one reflection'
      : 'from $reflections reflections';

  /// The facts under the sentence: how often, when the last one was, and who
  /// decided. The last of the three is there because the app is asserting
  /// something now, and a student is owed the difference between their own
  /// verdict handed back to them and ours.
  static String _facts(JudgedTheme theme) {
    final ago = _ago(theme.lastAt);
    final from = switch (theme.source) {
      PatternSource.outcomes => 'from how you said it went',
      PatternSource.model => 'from what you have written',
    };

    if (ago == null) return '${_times(theme.times)}, $from';
    return theme.times == 1
        ? '${_times(theme.times)}, $ago, $from'
        : '${_times(theme.times)}, the last of them $ago, $from';
  }

  static String _times(int count) => switch (count) {
        1 => 'once',
        2 => 'twice',
        _ => '$count times',
      };

  static String _entries(int count) => switch (count) {
        1 => 'one entry',
        2 => 'two entries',
        _ => '$count entries',
      };

  /// How long ago, in whole days, and never closer than that.
  ///
  /// The device works this out, which is the one place in this screen it is
  /// allowed to: a day count off two local midnights survives a student
  /// travelling, and a clock time would not. Whole days on both sides rather
  /// than elapsed hours, so something written last night reads as yesterday
  /// however late it was. Null when the string will not parse, and then the
  /// line simply says one fact fewer.
  static String? _ago(String iso) {
    final at = DateTime.tryParse(iso);
    if (at == null) return null;

    final then = at.toLocal();
    final now = DateTime.now();
    final days = (DateTime(now.year, now.month, now.day)
                .difference(DateTime(then.year, then.month, then.day))
                .inHours /
            24)
        .round();

    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';

    final weeks = days ~/ 7;
    if (weeks == 1) return 'last week';
    if (weeks < 9) return '$weeks weeks ago';

    final months = days ~/ 30;
    return months == 1 ? 'last month' : '$months months ago';
  }
}

/// One theme. The name, the sentence about it, and the facts it rests on.
///
/// The sentence is the server's and it is the only thing on this screen that
/// says anything. A forming row has none, which is the difference between the
/// two states and is why nothing is written in its place.
/// One reflection, in one line.
///
/// It used to print the whole sentence under every theme, which meant three
/// reflections filled the screen and a student with a dozen never saw most of
/// them. This tab is the overview: what keeps coming back and how often, in a
/// list you can take in at once. The sentence, the entries behind it and what
/// was decided all live on the page this opens.
class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.detail,
    required this.mark,
    this.times,
    this.onTap,
  });

  final String theme;

  /// When it last happened, said shortly. Two words, not a sentence.
  final String detail;

  /// The colour of the section this belongs to.
  final Color mark;

  final int? times;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: mark, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              theme,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: SoulType.sans,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: SoulColors.text,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            times == null ? detail : '${times}x',
            style: SoulType.muted,
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18, color: SoulColors.text3),
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: body,
    );
  }
}
