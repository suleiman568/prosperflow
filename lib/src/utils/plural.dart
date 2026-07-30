/// "1 sale" / "3 sales" / "0 sales" — a count with a correctly pluralized
/// noun, so captions never read "1 sales today". Pass [plural] for nouns
/// with irregular plurals; the default appends "s".
String countNoun(int count, String singular, {String? plural}) =>
    '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';
