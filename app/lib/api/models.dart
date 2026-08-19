/// The wire contract, mirrored from api/src/contracts.ts.
///
/// Hand written rather than generated. There are five shapes and a code
/// generator would be a build step, a dependency and a lock file to keep the
/// two in step. When contracts.ts changes, change this file in the same commit.
library;

sealed class SubmitResult {
  const SubmitResult();

  static SubmitResult fromJson(Map<String, dynamic> json) {
    return switch (json['state'] as String) {
      'reflected' => Reflected(
          entryId: json['entryId'] as String,
          line: json['line'] as String,
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
