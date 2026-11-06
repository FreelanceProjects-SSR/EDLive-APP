List<dynamic> extractJsonList(
  dynamic value, {
  List<String> preferredKeys = const <String>[],
}) {
  final list = _findJsonList(value, preferredKeys, 0);
  if (list == null) {
    throw const FormatException('Expected a JSON list in the response');
  }
  return list;
}

Map<String, dynamic> asStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  throw const FormatException('Expected a JSON object in the response list');
}

List<dynamic>? _findJsonList(
  dynamic value,
  List<String> preferredKeys,
  int depth,
) {
  if (value is List) {
    return value;
  }

  if (value is! Map || depth >= 3) {
    return null;
  }

  final map = value;
  final orderedKeys = <String>[
    ...preferredKeys,
    'data',
    'items',
    'results',
    'rows',
    'records',
    'list',
    'achievements',
    'students',
  ];

  for (final key in orderedKeys) {
    if (!map.containsKey(key)) {
      continue;
    }

    final found = _findJsonList(map[key], preferredKeys, depth + 1);
    if (found != null) {
      return found;
    }
  }

  for (final nestedValue in map.values) {
    final found = _findJsonList(nestedValue, preferredKeys, depth + 1);
    if (found != null) {
      return found;
    }
  }

  return null;
}
