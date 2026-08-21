/// The wire contract, mirrored from api/src/contracts.ts.
///
/// Hand written rather than generated. There are a handful of shapes and a
/// code generator would be a build step, a dependency and a lock file to keep
/// the two in step. When contracts.ts changes, change this file in the same
/// commit.
library;

sealed class SubmitResult {
  const SubmitResult();

  static SubmitResult fromJson(Map<String, dynamic> json) {
    return switch (json['state'] as String) {
      'reflected' => Reflected(
          entryId: json['entryId'] as String,
          line: (json['line'] as String?) ?? '',
        ),
      'help' => HelpNeeded(
          entryId: json['entryId'] as String,
          heading: json['heading'] as String,
          body: json['body'] as String,
          contacts: [
            for (final c in json['contacts'] as List)
              (
                label: (c as Map)['label'] as String,
                detail: c['detail'] as String,
              ),
          ],
        ),
      'held' => Held(entryId: json['entryId'] as String),
      final other => throw FormatException('unknown state $other'),
    };
  }
}

/// The ordinary path. One line back.
final class Reflected extends SubmitResult {
  const Reflected({required this.entryId, required this.line});
  final String entryId;
  final String line;
}

/// The safety classifier flagged the entry. No reflection was generated.
final class HelpNeeded extends SubmitResult {
  const HelpNeeded({
    required this.entryId,
    required this.heading,
    required this.body,
    required this.contacts,
  });
  final String entryId;
  final String heading;
  final String body;
  final List<({String label, String detail})> contacts;
}

/// Consent does not cover this student. The entry is saved and nothing left.
final class Held extends SubmitResult {
  const Held({required this.entryId});
  final String entryId;
}

class MirrorResult {
  const MirrorResult({
    required this.tension,
    required this.underneath,
    required this.question,
    this.offered,
    this.candidateId,
    this.proposal,
  });

  final String tension;
  final String underneath;
  final String question;
  final String? offered;
  final String? candidateId;
  final String? proposal;

  static MirrorResult fromJson(Map<String, dynamic> json) {
    final candidate = json['patternCandidate'] as Map<String, dynamic>?;
    return MirrorResult(
      tension: json['tension'] as String,
      underneath: json['underneath'] as String,
      question: json['question'] as String,
      offered: json['offered'] as String?,
      candidateId: candidate?['candidateId'] as String?,
      proposal: candidate?['proposal'] as String?,
    );
  }
}

/// GET /week. The shape of the student's current week.
///
/// Every boundary in here was decided on the server, in the student's own
/// timezone. Nothing on the device works out where a week starts or which day
/// an evening entry belongs to.
/// What the student said they would do, once the day they named has passed
/// without an answer.
class Holding {
  const Holding({
    required this.decisionId,
    required this.chose,
    required this.horizon,
  });

  final String decisionId;
  final String chose;
  final String horizon;

  static Holding fromJson(Map<String, dynamic> json) => Holding(
        decisionId: json['decisionId'] as String,
        chose: json['chose'] as String,
        horizon: json['horizon'] as String,
      );
}

class WeekView {
  const WeekView({
    required this.moments,
    required this.themes,
    required this.days,
    this.holding,
  });

  /// Entries written this week.
  final int moments;

  /// At most four, highest first. Empty until the tagger has named something,
  /// which is the ordinary state of a week that has only just started.
  final List<WeekTheme> themes;

  /// Exactly seven, Monday first.
  final List<WeekDay> days;

  /// Null on almost every week. When it is not, the day the student named has
  /// come and gone and nobody has asked them how it went.
  final Holding? holding;

  static WeekView fromJson(Map<String, dynamic> json) => WeekView(
        moments: json['moments'] as int,
        themes: [
          for (final theme in json['themes'] as List)
            WeekTheme.fromJson(theme as Map<String, dynamic>),
        ],
        days: [
          for (final day in json['days'] as List)
            WeekDay.fromJson(day as Map<String, dynamic>),
        ],
        holding: json['holding'] == null
            ? null
            : Holding.fromJson(json['holding'] as Map<String, dynamic>),
      );
}

/// One feeling and how often it came up this week.
class WeekTheme {
  const WeekTheme({required this.name, required this.count});
  final String name;
  final int count;

  static WeekTheme fromJson(Map<String, dynamic> json) => WeekTheme(
        name: json['name'] as String,
        count: json['count'] as int,
      );
}

/// One day of the week strip.
class WeekDay {
  const WeekDay({
    required this.date,
    required this.weekday,
    required this.count,
  });

  /// YYYY-MM-DD, kept as the server wrote it. It goes straight back out as the
  /// day to open, so it is never parsed into an instant and never rebuilt from
  /// the device clock.
  final String date;

  /// One letter, for under the dot.
  final String weekday;

  final int count;

  static WeekDay fromJson(Map<String, dynamic> json) => WeekDay(
        date: json['date'] as String,
        weekday: json['weekday'] as String,
        count: json['count'] as int,
      );
}

/// GET /day/:date. One day, as it was written, and what is being asked about
/// it.
class DayView {
  const DayView({
    required this.date,
    required this.entries,
    this.cards = const [],
  });

  final String date;

  /// In the order they were written, earliest first. The server decides the
  /// order and the screen does not sort.
  final List<DayEntry> entries;

  /// At most two, unanswered first, in the order the server sent them. Empty
  /// on any day where nothing the student wrote pointed forward, which is most
  /// days.
  final List<CueCard> cards;

  static DayView fromJson(Map<String, dynamic> json) => DayView(
        date: json['date'] as String,
        entries: [
          for (final entry in json['entries'] as List)
            DayEntry.fromJson(entry as Map<String, dynamic>),
        ],
        cards: [
          for (final card in (json['cards'] as List<dynamic>? ?? []))
            CueCard.fromJson(card as Map<String, dynamic>),
        ],
      );
}

/// One cue card, about something the student said was coming up.
///
/// The model wrote it from that student's own entries, and it only exists
/// because one of those entries named something ahead of them. Nothing here is
/// generated for a day that pointed nowhere.
///
/// The question takes yes or no and nothing else. It is about one thing the
/// student named that has not settled, so the card is asking whether they are
/// going to do it, not offering them ways to.
///
/// What they answered is not on the wire. A card carries the fact that it was
/// answered and no more, so the answer given in front of us is remembered by
/// the screen and a card answered on another day says only that it is done.
class CueCard {
  const CueCard({
    required this.id,
    required this.about,
    required this.question,
    required this.answered,
  });

  final String id;

  /// The thing itself, in the student's own frame. Something like the
  /// coursework due Friday.
  final String about;

  /// One question, and the only one the card asks.
  final String question;

  final bool answered;

  static CueCard fromJson(Map<String, dynamic> json) => CueCard(
        id: json['id'] as String,
        about: json['about'] as String,
        question: json['question'] as String,
        answered: json['answered'] as bool,
      );
}

class DayEntry {
  const DayEntry({
    required this.id,
    required this.at,
    required this.text,
    this.feeling,
    this.trigger,
  });

  final String id;

  /// When it was written, as the server sent it. Held because it is in the
  /// contract, not shown: reading a clock time off it would mean choosing a
  /// timezone here, and the order already says everything the screen needs.
  final String at;

  final String text;

  /// From the tagger, which runs after the reflection is already on screen. A
  /// fresh entry has neither of these yet.
  final String? feeling;
  final String? trigger;

  static DayEntry fromJson(Map<String, dynamic> json) => DayEntry(
        id: json['id'] as String,
        at: json['at'] as String,
        text: json['text'] as String,
        feeling: json['feeling'] as String?,
        trigger: json['trigger'] as String?,
      );
}

/// GET /patterns. What has come back often enough to say something about, and
/// what has not.
///
/// The two judged groups are the app taking a side, which it did not do
/// before. What sits under them did not change: a theme still carries the
/// count behind it and the day of the last one, so anything said about a
/// theme can still be walked back to entries the student wrote.
class PatternsView {
  const PatternsView({
    required this.reflections,
    required this.good,
    required this.bad,
    required this.forming,
  });

  /// Every entry this student has ever written.
  final int reflections;

  /// Themes that are doing them good, each with the sentence that says so.
  final List<JudgedTheme> good;

  /// Themes that are costing them. The same shape and the same amount of
  /// language as good, because a group carrying more words than the other
  /// would be the app leaning on one of them.
  final List<JudgedTheme> bad;

  /// Too little behind these to say either way, and they are named as forming
  /// rather than shown as a finding.
  final List<FormingPattern> forming;

  static PatternsView fromJson(Map<String, dynamic> json) => PatternsView(
        reflections: json['reflections'] as int,
        good: _judged(json['good']),
        bad: _judged(json['bad']),
        forming: [
          for (final pattern in (json['forming'] as List<dynamic>? ?? []))
            FormingPattern.fromJson(pattern as Map<String, dynamic>),
        ],
      );

  /// The contract sends all three arrays always, empty rather than absent.
  /// Read through a missing one anyway, so a client that is ahead of a server
  /// costs the student one section rather than the whole tab.
  static List<JudgedTheme> _judged(Object? group) => [
        for (final theme in (group as List<dynamic>? ?? []))
          JudgedTheme.fromJson(theme as Map<String, dynamic>),
      ];
}

/// Who decided what a theme is doing to the student.
enum PatternSource {
  /// The outcomes the student recorded themselves. Their reading of it beats
  /// ours and is never overruled.
  outcomes,

  /// The model read the theme, which only happens where the student has
  /// recorded no outcome to read.
  model,
}

/// One theme the app has taken a side on, and the one sentence it says.
class JudgedTheme {
  const JudgedTheme({
    required this.theme,
    required this.times,
    required this.lastAt,
    required this.line,
    required this.source,
  });

  final String theme;

  /// How many times it has come back. Counted on the server out of what the
  /// verdict rests on, so it is entries and answers rather than an estimate.
  final int times;

  /// When the last of them was, as the server sent it.
  final String lastAt;

  /// The sentence the student reads under the theme. It is written about
  /// their own situation, so it is never a line this screen could have
  /// supplied on its own.
  ///
  /// Empty when the server sent none, which the screen treats as nothing to
  /// say rather than as a theme with a blank under it.
  final String line;

  final PatternSource source;

  static JudgedTheme fromJson(Map<String, dynamic> json) => JudgedTheme(
        theme: json['theme'] as String,
        times: json['times'] as int,
        lastAt: json['lastAt'] as String,
        line: (json['line'] as String?) ?? '',
        // Anything that is not the student's own word falls to the model. The
        // screen says out loud which of the two spoke, and claiming their
        // voice for a string we did not recognise is the one mistake here
        // worth guarding against.
        source: json['source'] == 'outcomes'
            ? PatternSource.outcomes
            : PatternSource.model,
      );
}

class FormingPattern {
  const FormingPattern({
    required this.id,
    required this.theme,
    required this.supporting,
  });

  final String id;
  final String theme;
  final int supporting;

  static FormingPattern fromJson(Map<String, dynamic> json) => FormingPattern(
        id: json['id'] as String,
        theme: json['theme'] as String,
        supporting: json['supporting'] as int,
      );
}

/// One day that has something in it, for the list of days.
///
/// The feelings are the distinct ones on that day, so a day can be told apart
/// before it is opened.
class DayCount {
  const DayCount({
    required this.date,
    required this.weekday,
    required this.count,
    required this.feelings,
  });

  final String date;
  final String weekday;
  final int count;
  final List<String> feelings;

  factory DayCount.fromJson(Map<String, dynamic> json) => DayCount(
        date: json['date'] as String,
        weekday: json['weekday'] as String,
        count: json['count'] as int,
        feelings: [
          for (final feeling in (json['feelings'] as List<dynamic>? ?? []))
            feeling as String,
        ],
      );
}

/// One entry behind a reflection, on the page that shows where it came from.
class ReflectionEntry {
  const ReflectionEntry({
    required this.id,
    required this.at,
    required this.date,
    required this.text,
    this.feeling,
  });

  final String id;
  final String at;
  final String date;
  final String text;
  final String? feeling;

  static ReflectionEntry fromJson(Map<String, dynamic> json) => ReflectionEntry(
        id: json['id'] as String,
        at: json['at'] as String,
        date: json['date'] as String,
        text: json['text'] as String,
        feeling: json['feeling'] as String?,
      );
}

/// What the student decided about this theme, and how it went if they said.
class ReflectionDecision {
  const ReflectionDecision({required this.chose, required this.at, this.felt});

  final String chose;
  final String at;
  final String? felt;

  static ReflectionDecision fromJson(Map<String, dynamic> json) =>
      ReflectionDecision(
        chose: json['chose'] as String,
        at: json['at'] as String,
        felt: json['felt'] as String?,
      );
}

/// One reflection, opened. The claim and everything behind it.
class ReflectionView {
  const ReflectionView({
    required this.theme,
    required this.verdict,
    required this.line,
    required this.source,
    required this.times,
    required this.entries,
    required this.decisions,
  });

  final String theme;

  /// good, bad, or unsettled. Unsettled is a theme that keeps returning and
  /// has not been judged either way, which is most of them.
  final String verdict;

  final String line;

  /// outcomes when the student's own check backs decided it, model otherwise.
  final String source;

  final int times;
  final List<ReflectionEntry> entries;
  final List<ReflectionDecision> decisions;

  static ReflectionView fromJson(Map<String, dynamic> json) => ReflectionView(
        theme: json['theme'] as String,
        verdict: json['verdict'] as String,
        line: json['line'] as String,
        source: json['source'] as String,
        times: json['times'] as int,
        entries: [
          for (final entry in json['entries'] as List)
            ReflectionEntry.fromJson(entry as Map<String, dynamic>),
        ],
        decisions: [
          for (final decision in json['decisions'] as List)
            ReflectionDecision.fromJson(decision as Map<String, dynamic>),
        ],
      );
}

/// Somebody the student writes about, in the list.
class PersonRow {
  const PersonRow({
    required this.id,
    required this.name,
    required this.mentions,
    this.relation,
    this.lastAt,
  });

  final String id;
  final String name;
  final String? relation;
  final int mentions;
  final String? lastAt;

  static PersonRow fromJson(Map<String, dynamic> json) => PersonRow(
        id: json['id'] as String,
        name: json['name'] as String,
        relation: json['relation'] as String?,
        mentions: json['mentions'] as int,
        lastAt: json['lastAt'] as String?,
      );
}

/// One of the student's own entries, on a person's page.
class PersonMention {
  const PersonMention({
    required this.entryId,
    required this.at,
    required this.text,
  });

  final String entryId;
  final String at;
  final String text;

  static PersonMention fromJson(Map<String, dynamic> json) => PersonMention(
        entryId: json['entryId'] as String,
        at: json['at'] as String,
        text: json['text'] as String,
      );
}

/// One person, opened.
class PersonView {
  const PersonView({
    required this.id,
    required this.name,
    required this.mentions,
    required this.said,
    this.relation,
    this.profile,
    this.reach,
  });

  final String id;
  final String name;

  /// Written by the model unless the student has said otherwise, and then it
  /// is theirs and stays theirs.
  final String? relation;

  /// What happens between the student and this person, from the student's own
  /// entries. Empty until somebody has come up twice.
  final String? profile;

  /// The student's own note on how they would reach them. Only ever theirs.
  final String? reach;

  final int mentions;
  final List<PersonMention> said;

  static PersonView fromJson(Map<String, dynamic> json) => PersonView(
        id: json['id'] as String,
        name: json['name'] as String,
        relation: json['relation'] as String?,
        profile: json['profile'] as String?,
        reach: json['reach'] as String?,
        mentions: json['mentions'] as int,
        said: [
          for (final mention in json['said'] as List? ?? [])
            PersonMention.fromJson(mention as Map<String, dynamic>),
        ],
      );
}
