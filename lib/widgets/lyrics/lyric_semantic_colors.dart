import 'package:flutter/material.dart';

/// Maps AI-selected lyric keywords back onto renderer-specific text units.
///
/// A unit can be a grapheme (default/浮名) or a Chinese grapheme / Latin word
/// token (流光). Longest keywords win so a meaningful phrase is not
/// overwritten by one of its shorter words.
List<Color?> lyricSemanticColorsForUnits(
  List<String> units,
  Map<String, Color> keywordColors, {
  String? sourceText,
}) {
  if (units.isEmpty || keywordColors.isEmpty) {
    return List<Color?>.filled(units.length, null, growable: false);
  }

  final starts = <int>[];
  final ends = <int>[];
  final source = (sourceText ?? units.join()).toLowerCase();
  var searchFrom = 0;
  for (final unit in units) {
    final normalizedUnit = unit.toLowerCase();
    final locatedStart = sourceText == null
        ? searchFrom
        : source.indexOf(normalizedUnit, searchFrom);
    if (locatedStart < 0) {
      starts.add(-1);
      ends.add(-1);
      continue;
    }
    starts.add(locatedStart);
    ends.add(locatedStart + normalizedUnit.length);
    searchFrom = locatedStart + normalizedUnit.length;
  }
  final result = List<Color?>.filled(units.length, null);
  final entries = keywordColors.entries.toList(growable: false)
    ..sort((a, b) => b.key.runes.length.compareTo(a.key.runes.length));

  for (final entry in entries) {
    final keyword = entry.key.trim().toLowerCase();
    if (keyword.isEmpty) continue;
    var searchFrom = 0;
    while (searchFrom < source.length) {
      final matchStart = source.indexOf(keyword, searchFrom);
      if (matchStart < 0) break;
      final matchEnd = matchStart + keyword.length;
      searchFrom = matchEnd;
      if (!_hasLatinWordBoundaries(source, keyword, matchStart, matchEnd)) {
        continue;
      }
      for (var index = 0; index < units.length; index++) {
        if (result[index] != null) continue;
        if (starts[index] < 0) continue;
        if (ends[index] > matchStart && starts[index] < matchEnd) {
          result[index] = entry.value;
        }
      }
    }
  }
  return List.unmodifiable(result);
}

bool _hasLatinWordBoundaries(
  String source,
  String keyword,
  int start,
  int end,
) {
  final beginsWithLatin = _isLatinWordCodeUnit(keyword.codeUnitAt(0));
  final endsWithLatin = _isLatinWordCodeUnit(
    keyword.codeUnitAt(keyword.length - 1),
  );
  if (beginsWithLatin &&
      start > 0 &&
      _isLatinWordCodeUnit(source.codeUnitAt(start - 1))) {
    return false;
  }
  if (endsWithLatin &&
      end < source.length &&
      _isLatinWordCodeUnit(source.codeUnitAt(end))) {
    return false;
  }
  return true;
}

bool _isLatinWordCodeUnit(int value) {
  return (value >= 0x30 && value <= 0x39) ||
      (value >= 0x41 && value <= 0x5A) ||
      (value >= 0x61 && value <= 0x7A) ||
      value == 0x5F;
}
