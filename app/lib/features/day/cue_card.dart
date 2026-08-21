import 'package:flutter/material.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// What the student said, on their way to a decision.
///
/// The screen holds one of these per card it has seen answered, because the
/// day tells us that a card was answered and never what with. A card answered
/// on another day arrives with nothing under it and says so.
class CueCardAnswer {
  const CueCardAnswer({
    required this.yes,
    this.detail,
    this.horizonDays,
  });

  /// Yes writes a decision and books the check back. No writes neither.
  final bool yes;

  /// Anything they wanted to say about it, which is usually nothing and is a
  /// complete answer either way.
  final String? detail;

  /// Null on a no, because nothing was booked to come back to.
  final int? horizonDays;
}

/// One cue card, inside an open day and under that day's entries.
///
/// The card asks one question about one thing the student already named and
/// has not settled, and yes or no answers it. Picking one selects it and
/// commits nothing: a tap that sends on their behalf is the wrong shape for a
/// question about what they are going to do, so the one button at the bottom
/// is the only thing that sends anything.
///
/// The box under the question is theirs. It takes anything they want to say
/// about the thing and it is never required, because a student who knows the
/// answer is yes and has nothing to add has already finished.
class CueCardTile extends StatefulWidget {
  const CueCardTile({
    super.key,
    required this.card,
    required this.answer,
    required this.onAnswer,
  });

  final CueCard card;

  /// What the student said, once this screen has seen them say it.
  final CueCardAnswer? answer;

  /// Throws when the answer did not land, which is what puts the card into its
  /// failed state with a way back.
  final Future<void> Function(CueCardAnswer answer) onAnswer;

  @override
  State<CueCardTile> createState() => _CueCardTileState();
}

class _CueCardTileState extends State<CueCardTile> {
  final _detail = TextEditingController();
  final _detailFocus = FocusNode();

  /// Yes, no, or nothing picked yet. Nothing picked is the state the card
  /// opens in and the state the button stays dim in.
  bool? _yes;

  /// Three days, the same as the Mirror path holds a decision for. It starts
  /// on a day so that a student who has nothing to say about timing still has
  /// a card that works. Kept through a switch to no and back, so changing
  /// their mind twice does not quietly reset the day they picked.
  int _horizonDays = 3;

  bool _sending = false;
  bool _failed = false;

  /// What the server will take. Quietly cutting somebody's own words down to
  /// fit would be worse than saying the field is full.
  static const _detailLimit = 500;

  static const _horizons = [
    (days: 1, label: 'Tomorrow'),
    (days: 3, label: 'In three days'),
    (days: 7, label: 'In a week'),
    (days: 14, label: 'In two weeks'),
  ];

  @override
  void initState() {
    super.initState();
    // The button turns off when the box is over length, so the box has to say
    // when it changes.
    _detail.addListener(_detailChanged);
  }

  void _detailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _detail.dispose();
    _detailFocus.dispose();
    super.dispose();
  }

  /// An answer, inside the length the server takes. The box is not part of
  /// this: yes on its own is an answer and no on its own is an answer.
  bool get _ready =>
      _yes != null && _detail.text.trim().length <= _detailLimit;

  Future<void> _send() async {
    final yes = _yes;
    if (yes == null || _sending || !_ready) return;

    final detail = _detail.text.trim();
    _detailFocus.unfocus();
    setState(() {
      _sending = true;
      _failed = false;
    });

    try {
      await widget.onAnswer(
        CueCardAnswer(
          yes: yes,
          detail: detail.isEmpty ? null : detail,
          horizonDays: yes ? _horizonDays : null,
        ),
      );
      // The screen is holding the answer now and rebuilds this card answered.
      if (mounted) setState(() => _sending = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final answer = widget.answer;

    return SoulCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Label('coming up'),
          const SizedBox(height: 6),
          Text(card.about, style: SoulType.field),
          const SizedBox(height: 14),
          // An answered card keeps its words and loses its controls. There is
          // one answer per card and the server is the one that says so.
          if (card.answered || answer != null)
            ..._answered(answer)
          else
            ..._asking(card),
        ],
      ),
    );
  }

  List<Widget> _answered(CueCardAnswer? answer) {
    if (answer == null) return const [Label('answered')];

    final detail = answer.detail;
    final horizon = answer.horizonDays;

    return [
      const Label('you said'),
      const SizedBox(height: 6),
      Text(answer.yes ? 'Yes' : 'No', style: SoulType.lead),
      // Their own words, set apart the way their own words always are.
      if (detail != null) ...[const SizedBox(height: 10), Quote(detail)],
      if (answer.yes && horizon != null) ...[
        const SizedBox(height: 8),
        Label(_whenLine(horizon)),
      ],
    ];
  }

  List<Widget> _asking(CueCard card) {
    final yes = _yes;
    final over = _detail.text.trim().length > _detailLimit;

    return [
      Text(card.question, style: SoulType.lead),
      const SizedBox(height: 14),
      ButtonRow(
        children: [
          // A tap sets the answer and a second tap on the same one leaves it
          // set. Nothing is sent yet, so the only thing an unpick could do is
          // lose an answer somebody had already given.
          _Choice(
            text: 'Yes',
            picked: yes == true,
            onTap: _sending ? null : () => setState(() => _yes = true),
          ),
          _Choice(
            text: 'No',
            picked: yes == false,
            onTap: _sending ? null : () => setState(() => _yes = false),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Label('anything you want to say, or nothing'),
      const SizedBox(height: 8),
      SoulField(controller: _detail, focusNode: _detailFocus),
      if (over) ...[
        const SizedBox(height: 8),
        const Label('500 characters is the most this holds'),
      ],
      // Only a yes has something to come back to. A no closes the thing and
      // asking which day it should be reopened on would be the card refusing
      // to take no for an answer.
      if (yes == true) ...[
        const SizedBox(height: 16),
        const Label('which day'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final horizon in _horizons)
              _Horizon(
                label: horizon.label,
                picked: _horizonDays == horizon.days,
                onTap: _sending
                    ? null
                    : () => setState(() => _horizonDays = horizon.days),
              ),
          ],
        ),
      ],
      const SizedBox(height: 18),
      // Dimmed while there is nothing to send and named for what it is doing
      // while it sends, which is how the rest of the app says a button is not
      // live. A filled button keeps its colour when it is disabled, so without
      // this it reads as a button that ignores a tap.
      AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _ready ? 1 : 0.4,
        child: SoulButton(
          _sending ? 'Answering' : 'Answer it',
          kind: SoulButtonKind.filled,
          onPressed: _ready && !_sending ? _send : null,
        ),
      ),
      if (_failed) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text('That did not save.', style: SoulType.secondary),
            ),
            TextButton(
              onPressed: _send,
              child: const Text(
                'Try again',
                style: TextStyle(
                  fontFamily: SoulType.sans,
                  fontSize: 14,
                  color: SoulColors.clay,
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  /// The day they named, said the way they picked it. Only the four horizons
  /// on the card can get here; the last branch is there so a horizon that
  /// arrives from anywhere else still reads as a sentence.
  static String _whenLine(int days) => switch (days) {
        1 => 'back to it tomorrow',
        3 => 'back to it in three days',
        7 => 'back to it in a week',
        14 => 'back to it in two weeks',
        _ => 'back to it in $days days',
      };
}

/// Yes or no. The two sit side by side and are the same size, because the
/// card is asking a question it is willing to hear either answer to.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.text,
    required this.picked,
    required this.onTap,
  });

  final String text;
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: picked ? SoulColors.clayLight : SoulColors.s2,
          border: Border.all(
            color: picked ? SoulColors.clay : SoulColors.border,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: SoulType.lead.copyWith(
            color: picked ? SoulColors.clayDark : SoulColors.text,
          ),
        ),
      ),
    );
  }
}

/// One day to come back on. Small, because when is the smaller half of the
/// question and the answer above it is the part being asked for.
class _Horizon extends StatelessWidget {
  const _Horizon({
    required this.label,
    required this.picked,
    required this.onTap,
  });

  final String label;
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: picked ? SoulColors.clayLight : SoulColors.s1,
          border: Border.all(
            color: picked ? SoulColors.clay : SoulColors.border2,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: SoulType.sans,
            fontSize: 14,
            color: picked ? SoulColors.clayDark : SoulColors.text2,
          ),
        ),
      ),
    );
  }
}
