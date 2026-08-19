import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';

/// The baseline set.
///
/// Ten questions across five sections, asked once at first run. The purpose is
/// pattern awareness and readiness, not diagnosis and not treatment. Nothing
/// here is scored, nothing is shown back as a result, and no answer produces a
/// label for the student.
///
/// Every question is skippable and the whole set is skippable. A student who is
/// here because an adult sent them needs a way through that is not answering.
/// How a question is answered.
///
/// Ten screens of the same four tiles is a form with paint on it. The shape of
/// the options decides the shape of the answer: long phrases read better in a
/// list, an agreement question is a scale you drag, single words want to be
/// picked up rather than ticked.
enum Answering { orb, list, scale, blank, words }

class BaselineQuestion {
  const BaselineQuestion({
    required this.section,
    required this.text,
    required this.options,
    required this.style,
    this.lead,
    this.ends,
  });

  final String section;
  final String text;
  final List<String> options;
  final Answering style;

  /// For a fill in the blank question, the sentence the chosen words complete.
  /// The blank is written as an underscore run.
  final String? lead;

  /// For a scale, the words at either end.
  final (String, String)? ends;
}

/// Each section carries a mark and a colour, so a student can see they have
/// moved from one part of the set to another without being told.
const sectionMarks = <String, (IconData, Color)>{
  'Decision timing': (Icons.schedule, SoulColors.clay),
  'Responsibility and agency': (Icons.flag_outlined, SoulColors.amber),
  'Emotion and action': (Icons.waves, SoulColors.violet),
  'Patterns and repetition': (Icons.replay, SoulColors.moss),
  'Readiness': (Icons.arrow_outward, SoulColors.clay),
};

const baselineVersion = 'set-b-v1';

const baseline = <BaselineQuestion>[
  BaselineQuestion(
    section: 'Decision timing',
    text: 'When I feel pressure to decide, I tend to',
    options: [
      'Act quickly to get relief',
      'Delay it as long as possible',
      'Ask others what they think',
      'Pause and think it through',
    ],
    style: Answering.orb,
  ),
  BaselineQuestion(
    section: 'Decision timing',
    text: 'I usually feel most comfortable making decisions',
    options: [
      'Under urgency',
      'When everything feels calm',
      'When someone reassures me',
      'After time to reflect',
    ],
    style: Answering.list,
  ),
  BaselineQuestion(
    section: 'Responsibility and agency',
    text: 'When facing an important decision, I often wait for',
    options: [
      'More certainty',
      'External validation',
      'Circumstances to change',
      'My own clarity to increase',
    ],
    style: Answering.list,
  ),
  BaselineQuestion(
    section: 'Responsibility and agency',
    text: 'I generally believe good decisions come from',
    options: [
      'Feeling confident',
      'Thinking carefully',
      'Avoiding mistakes',
      'Taking responsibility even without certainty',
    ],
    style: Answering.orb,
  ),
  BaselineQuestion(
    section: 'Emotion and action',
    text: 'Strong emotions usually',
    options: [
      'Push me to act quickly',
      'Make me avoid deciding',
      'Prompt me to seek reassurance',
      'Help me notice what matters',
    ],
    style: Answering.orb,
  ),
  BaselineQuestion(
    section: 'Emotion and action',
    text: 'After deciding under emotional pressure, I often',
    options: [
      'Feel relieved but unsure',
      'Feel confident',
      'Question myself',
      'Avoid thinking about it',
    ],
    style: Answering.list,
  ),
  BaselineQuestion(
    section: 'Patterns and repetition',
    text: 'I have faced similar decisions before',
    options: ['Strongly agree', 'Somewhat agree', 'Not sure', 'Disagree'],
    style: Answering.scale,
    ends: ('Not at all', 'Every time'),
  ),
  BaselineQuestion(
    section: 'Patterns and repetition',
    text: 'Looking back at past decisions, I notice that',
    options: [
      'I repeat similar patterns',
      'I tend to change my approach',
      'Outcomes surprise me',
      'I avoid reflecting on them',
    ],
    style: Answering.blank,
    lead: 'Looking back, I ______.',
  ),
  BaselineQuestion(
    section: 'Readiness',
    text: 'Right now, I feel most ready to',
    options: [
      'Pause and reflect',
      'Take a small next step',
      'Gather more information',
      'Wait before deciding',
    ],
    style: Answering.orb,
  ),
  BaselineQuestion(
    section: 'Readiness',
    text: 'What I want most right now is',
    options: [
      'Calm',
      'Direction',
      'Confidence',
      'Understanding my pattern',
    ],
    style: Answering.words,
  ),
];

/// One colour per position, so the four choices are told apart by colour as
/// well as by words. The same colour sits in the same corner on every
/// question, which makes the set feel like one thing rather than ten.
const baselineColours = <Color>[
  SoulColors.clay,
  SoulColors.amber,
  SoulColors.violet,
  SoulColors.moss,
];
