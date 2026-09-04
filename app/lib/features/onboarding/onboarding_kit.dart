import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';

/// The furniture first run is built from, so fifteen screens share one set
/// of spacings, one button and one selected state rather than fifteen
/// slightly different ones.
///
/// The shape is borrowed from Nouvel's onboarding: a small tracked eyebrow, a
/// serif question, a quieter helper line, the options in a scroll, and one
/// pinned button that is dim until there is an answer to continue with. The
/// colours, the type and the words are Soul's.

/// The small uppercase line above a question. It says which part of first
/// run this is, and it never asks anything.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: SoulType.sans,
        fontSize: 11,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w500,
        color: SoulColors.clayDark,
      ),
    );
  }
}

/// A question screen: eyebrow, serif question, optional helper, the content
/// in a scroll, and the button pinned under it.
///
/// The button stays put when the keyboard opens, lifted above it, so the one
/// step with a field does not lose its continue at the moment there is
/// something to continue with.
class QuestionScaffold extends StatelessWidget {
  const QuestionScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    this.helper,
    required this.ctaTitle,
    required this.ctaEnabled,
    required this.onContinue,
    required this.child,
    this.trailing,
    this.centered = false,
  });

  final String eyebrow;
  final String title;
  final String? helper;
  final String ctaTitle;
  final bool ctaEnabled;
  final VoidCallback onContinue;
  final Widget child;

  /// Holds the child in the middle of the space rather than at the top of
  /// a scroll. For a control that is one thing, like a wheel, and would sit
  /// stranded under the question otherwise.
  final bool centered;

  /// Sits on the same line as the helper, at the right. The selection count
  /// goes here on a screen with a cap.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(eyebrow),
              const SizedBox(height: 12),
              Text(
                title,
                style: SoulType.heading.copyWith(fontSize: 28, height: 1.15),
              ),
              if (helper != null || trailing != null) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: helper == null
                          ? const SizedBox.shrink()
                          : Text(
                              helper!,
                              style: const TextStyle(
                                fontFamily: SoulType.serif,
                                fontSize: 16,
                                height: 1.4,
                                color: SoulColors.text2,
                              ),
                            ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: centered
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                  child: Center(child: child),
                )
              : SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                  child: child,
                ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 26 + bottomInset),
          child: PrimaryCta(ctaTitle, enabled: ctaEnabled, onPressed: onContinue),
        ),
      ],
    );
  }
}

/// The one button. Dim when there is nothing to continue with, and the
/// dimming animates so an answer landing is seen to turn it on.
class PrimaryCta extends StatelessWidget {
  const PrimaryCta(
    this.label, {
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.arrow = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  /// A small arrow after the words, for the one button that begins the
  /// whole thing.
  final bool arrow;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: SoulColors.clay,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: arrow ? 26 : 16,
              vertical: 16,
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: SoulType.sans,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                if (arrow) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A full width option. Used by every question whose answers are phrases.
///
/// The chosen one fills with the accent and gets a mark. On a single choice
/// question the others fade once one is picked, so the answer is the only
/// thing at full strength, and they stay tappable so changing your mind is
/// one tap rather than clear then pick. On a capped question the ones past
/// the cap fade the same amount and stop responding, which is the one
/// difference between dimmed and disabled.
class OptionRow extends StatefulWidget {
  const OptionRow({
    super.key,
    required this.label,
    this.detail,
    required this.selected,
    this.dimmed = false,
    this.disabled = false,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final bool selected;
  final bool dimmed;
  final bool disabled;
  final VoidCallback onTap;

  @override
  State<OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<OptionRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final faded = widget.dimmed || widget.disabled;

    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.disabled ? null : widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: faded ? 0.4 : 1,
          duration: const Duration(milliseconds: 180),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              color: selected ? SoulColors.clay : SoulColors.s1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? SoulColors.clay : SoulColors.border,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x40EA5F17),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: SoulColors.shade,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: SoulType.sans,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? Colors.white : SoulColors.text,
                        ),
                      ),
                      if (widget.detail != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.detail!,
                          style: TextStyle(
                            fontFamily: SoulType.sans,
                            fontSize: 12,
                            height: 1.4,
                            color: selected
                                ? Colors.white.withValues(alpha: 0.8)
                                : SoulColors.text2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check, size: 16, color: Colors.white),
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

/// A compact capsule, for a question whose answers are single words. Each
/// carries its own colour: unselected it sits at a low wash so four at once
/// do not shout, selected it fills, and the chosen one is the loudest thing
/// on the row.
class OptionChip extends StatelessWidget {
  const OptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.tint,
    this.disabled = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color tint;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.4 : 1,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? tint : tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? tint : tint.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: SoulType.sans,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : SoulColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// "2 of 3 chosen", so a cap is visible before it is hit rather than found
/// by a tap that seems to do nothing.
class SelectionCount extends StatelessWidget {
  const SelectionCount({super.key, required this.count, required this.limit});
  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontFamily: SoulType.sans,
        fontSize: 11,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w500,
        color: count >= limit ? SoulColors.clayDark : SoulColors.text3,
      ),
      child: Text('$count of $limit chosen'),
    );
  }
}

/// One capsule per question, filled up to where the person is. It sits over
/// the questions only: the narrative screens before them and the screens
/// after them are not work to get through, and a bar over them would say
/// they were.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.done, required this.of});
  final int done;
  final int of;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < of; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 3,
              decoration: BoxDecoration(
                color: i <= done ? SoulColors.clay : SoulColors.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The card a name is typed into. Serif, a size up from the option rows,
/// because it is the person's own word on the screen.
class NameField extends StatelessWidget {
  const NameField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.focusNode,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(
        fontFamily: SoulType.serif,
        fontSize: 21,
        color: SoulColors.text,
      ),
      cursorColor: SoulColors.clay,
      maxLength: 40,
      autocorrect: false,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: SoulColors.s1,
        hintText: 'First name',
        hintStyle: const TextStyle(
          fontFamily: SoulType.serif,
          fontSize: 21,
          color: SoulColors.text3,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoulColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoulColors.clay, width: 1.5),
        ),
      ),
    );
  }
}

/// Fades and rises its child into place once, on first build. Given a delay
/// so a screen can settle in parts rather than snap on all at once.
///
/// Under reduce motion the child is simply there.
class Settle extends StatefulWidget {
  const Settle({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<Settle> createState() => _SettleState();
}

class _SettleState extends State<Settle> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedOpacity(
      opacity: _in ? 1 : 0,
      duration: widget.duration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _in ? Offset.zero : const Offset(0, 0.03),
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Swaps one step for the next. The new one comes in from the right as the
/// old one leaves to the left, both fading, and the direction flips for
/// back, so the sequence reads as a line the person is walking along.
///
/// Built on AnimatedSwitcher because it keeps the leaving screen's state
/// alive for the length of the slide. A stack of two built by hand rebuilt
/// the leaving screen from scratch, so a name field asked for the keyboard
/// on its way out and the capture screen fetched a second speech token.
///
/// Written here rather than taken from a package: every package is a name
/// in a district data agreement.
class StepSwitcher extends StatelessWidget {
  const StepSwitcher({
    super.key,
    required this.stepKey,
    required this.forward,
    required this.child,
  });

  /// Changes when the step does. Same key, same step, no transition.
  final Object stepKey;
  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final sign = forward ? 1.0 : -1.0;
    final current = ValueKey(stepKey);

    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 400),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final arriving = child.key == current;
        // The leaving screen's animation runs backwards, from one to nought,
        // so its tween is written from where it ends up.
        final from = arriving ? Offset(0.12 * sign, 0) : Offset(-0.12 * sign, 0);
        return IgnorePointer(
          ignoring: !arriving,
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: from, end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          ),
        );
      },
      child: KeyedSubtree(key: current, child: child),
    );
  }
}
