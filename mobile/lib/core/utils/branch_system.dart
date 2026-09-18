/// Branch class system helpers.
///
/// All branches use the same standard level structure: Playgroup, IG1, IG2,
/// IG3. The underlying `system_type` field (sunkidz/normal) is still stored
/// per branch and still displayed, but no longer maps to two different sets
/// of grade names -- both resolve to the same standard levels below.

const String sunkidzSystem = 'sunkidz';
const String normalSystem = 'normal';

String normalizeBranchSystemType(String? raw) {
  final t = (raw ?? sunkidzSystem).toLowerCase();
  if (t == 'kreedo') return sunkidzSystem;
  return t;
}

String branchSystemTypeLabel(String? raw) {
  final t = normalizeBranchSystemType(raw);
  return t == normalSystem
      ? 'Normal (Playgroup/IG1/IG2/IG3)'
      : 'Sunkidz (Playgroup/IG1/IG2/IG3)';
}

bool isSunkidzSystem(String? raw) =>
    normalizeBranchSystemType(raw) == sunkidzSystem;

/// Fixed, controlled grade/class options used by every branch.
/// Values must be preserved exactly as-is wherever displayed or selected.
const List<String> kFixedGradeOptions = ['Playgroup', 'IG1', 'IG2', 'IG3'];

/// Kept as an alias of [kFixedGradeOptions] for source compatibility --
/// every branch now uses the same standard levels regardless of system type.
const List<String> kNormalGradeOptions = kFixedGradeOptions;

/// Returns the fixed grade options for a branch. Every branch uses the same
/// standard levels now, so [systemType] no longer changes the result; the
/// parameter is kept so existing call sites don't need to change.
List<String> gradeOptionsForSystem(String? systemType) => kFixedGradeOptions;

/// Maps a stored grade/class name to its canonical display label (e.g.
/// "ig1"/"1g1"/"lkg" -> "IG1", "nursery"/"playschool" -> "Playgroup").
/// [systemType] is kept for source compatibility with existing call sites
/// but no longer changes the mapping -- every branch uses the same standard
/// levels. Names that don't match a known legacy/current level are returned
/// unchanged.
String canonicalGradeLabel(String? raw, [String? systemType]) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return trimmed;
  final key = trimmed.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  const aliases = {
    'playgroup': 'Playgroup',
    'playschool': 'Playgroup',
    'nursery': 'Playgroup',
    'ig1': 'IG1',
    '1g1': 'IG1',
    'lkg': 'IG1',
    'ig2': 'IG2',
    '1g2': 'IG2',
    'ukg': 'IG2',
    'ig3': 'IG3',
    '1g3': 'IG3',
  };
  return aliases[key] ?? trimmed;
}

/// Fixed sort index for the canonical grade order: Playgroup(0) -> IG1(1) ->
/// IG2(2) -> IG3(3). Never alphabetical, never API/DB insertion order.
/// Names outside the standard 4 (e.g. a custom class) sort after them.
int gradeSortIndex(String? raw, [String? systemType]) {
  final label = canonicalGradeLabel(raw, systemType);
  final index = kFixedGradeOptions.indexOf(label);
  return index == -1 ? kFixedGradeOptions.length : index;
}

/// Sorts [items] by their grade in canonical order (Playgroup -> IG1 ->
/// IG2 -> IG3), using [nameOf] to read each item's raw class/grade name.
/// Stable: items with the same grade (or both unrecognized) keep their
/// relative order.
List<T> sortByCanonicalGrade<T>(
  List<T> items,
  String? Function(T item) nameOf, [
  String? systemType,
]) {
  final indexed = items.asMap().entries.toList();
  indexed.sort((a, b) {
    final cmp = gradeSortIndex(
      nameOf(a.value),
      systemType,
    ).compareTo(gradeSortIndex(nameOf(b.value), systemType));
    if (cmp != 0) return cmp;
    return a.key.compareTo(b.key); // stable tiebreaker
  });
  return indexed.map((e) => e.value).toList();
}
