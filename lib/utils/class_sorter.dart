int compareClassLabels(String? a, String? b) {
  final normalizedA = _normalizeClassLabel(a);
  final normalizedB = _normalizeClassLabel(b);
  final rankA = _classRank(normalizedA);
  final rankB = _classRank(normalizedB);

  final rankCompare = rankA.compareTo(rankB);
  if (rankCompare != 0) return rankCompare;

  return normalizedA.compareTo(normalizedB);
}

int compareClassAndSection({
  required String? classA,
  required String? sectionA,
  required String? classB,
  required String? sectionB,
}) {
  final classCompare = compareClassLabels(classA, classB);
  if (classCompare != 0) return classCompare;

  return _normalizeClassLabel(
    sectionA,
  ).compareTo(_normalizeClassLabel(sectionB));
}

int _classRank(String label) {
  const namedRanks = {
    'PREKG': 0,
    'PRE KG': 0,
    'PRE-KG': 0,
    'NURSERY': 1,
    'LKG': 2,
    'UKG': 3,
  };

  final namedRank = namedRanks[label];
  if (namedRank != null) return namedRank;

  final numberMatch = RegExp(r'\d+').firstMatch(label);
  if (numberMatch != null) {
    return 100 + int.parse(numberMatch.group(0)!);
  }

  return 1000;
}

String _normalizeClassLabel(String? value) {
  return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
}
