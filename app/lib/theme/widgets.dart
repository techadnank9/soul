import 'package:flutter/material.dart';
import 'soul_theme.dart';

/// The pieces every screen is assembled from. Each one has a counterpart class
/// in docs/screens.html. Change both together or the designs stop being true.

/// A small lowercase label. It sits above a line and never asks anything.
class Label extends StatelessWidget {
  const Label(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: SoulType.muted);
}

class Rule extends StatelessWidget {
  const Rule({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: SoulColors.border);
}

class SoulCard extends StatelessWidget {
  const SoulCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.background,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? background;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? SoulColors.s1,
        border: Border.all(color: borderColor ?? SoulColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

/// The recessed block. Used for the one question and for an observation the
/// student can push back on.
class Inset extends StatelessWidget {
  const Inset({super.key, this.label, required this.body});
  final String? label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoulColors.s2,
        border: Border.all(color: SoulColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[Label(label!), const SizedBox(height: 6)],
          Text(body, style: SoulType.lead),
        ],
      ),
    );
  }
}

/// The student's own words, set apart. Always their transcript, never ours.
class Quote extends StatelessWidget {
  const Quote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: SoulColors.border2, width: 2)),
      ),
      child: Text(text, style: SoulType.secondary),
    );
  }
}

enum SoulButtonKind { outline, filled, ghost }

class SoulButton extends StatelessWidget {
  const SoulButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = SoulButtonKind.outline,
    this.alignLeft = false,
    this.height = 46,
  });

  final String label;
  final VoidCallback? onPressed;
  final SoulButtonKind kind;
  final bool alignLeft;
  final double height;

  @override
  Widget build(BuildContext context) {
    final filled = kind == SoulButtonKind.filled;
    final ghost = kind == SoulButtonKind.ghost;

    return SizedBox(
      width: double.infinity,
      height: ghost ? 34 : height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: alignLeft ? 16 : 8),
          alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
          backgroundColor: filled ? SoulColors.text : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: switch (kind) {
                SoulButtonKind.filled => SoulColors.text,
                SoulButtonKind.outline => SoulColors.border2,
                SoulButtonKind.ghost => Colors.transparent,
              },
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: SoulType.sans,
            fontSize: ghost ? 13 : 15,
            fontWeight: FontWeight.w300,
            color: switch (kind) {
              SoulButtonKind.filled => SoulColors.bg,
              SoulButtonKind.outline => SoulColors.text,
              SoulButtonKind.ghost => SoulColors.text3,
            },
          ),
        ),
      ),
    );
  }
}

/// Buttons side by side. Used where the choices are equal weight.
class ButtonRow extends StatelessWidget {
  const ButtonRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// The text field. Serif at 17 points, growing with the words rather than
/// scrolling inside itself, so a student can see everything they wrote.
class SoulField extends StatelessWidget {
  const SoulField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      style: SoulType.field,
      cursorColor: SoulColors.clay,
      minLines: 1,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: SoulColors.s2,
        hintText: hint,
        hintStyle: SoulType.field.copyWith(color: SoulColors.text3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SoulColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SoulColors.border2),
        ),
      ),
    );
  }
}

/// A screen body. Scrolls, pads for the keyboard by hand, and dismisses the
/// keyboard on a tap outside the field.
class Screen extends StatelessWidget {
  const Screen({
    super.key,
    required this.body,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(22, 26, 22, 26),
  });

  final List<Widget> body;
  final Widget? footer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: SoulColors.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: padding.copyWith(
                    bottom: padding.bottom + bottomInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: body,
                  ),
                ),
              ),
              if (footer != null && bottomInset == 0)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    padding.left,
                    0,
                    padding.right,
                    padding.bottom,
                  ),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
