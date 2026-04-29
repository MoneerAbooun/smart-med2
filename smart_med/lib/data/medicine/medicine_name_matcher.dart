import 'package:smart_med/data/medicine/medicine_name_entry.dart';

enum MedicineNameMatchKind {
  brandExact,
  genericExact,
  brandContains,
  genericContains,
}

class MedicineNameMatch {
  const MedicineNameMatch({
    required this.entry,
    required this.kind,
    required this.cleanedText,
    required this.cleanedCandidates,
  });

  final MedicineNameEntry entry;
  final MedicineNameMatchKind kind;
  final String cleanedText;
  final List<String> cleanedCandidates;

  bool get matchedOnBrand =>
      kind == MedicineNameMatchKind.brandExact ||
      kind == MedicineNameMatchKind.brandContains;

  String? get matchedBrandName =>
      entry.brandName.trim().isEmpty ? null : entry.brandName;

  String? get matchedGenericName =>
      entry.genericName.trim().isEmpty ? null : entry.genericName;

  String get preferredQuery {
    if (matchedOnBrand && matchedBrandName != null) {
      return matchedBrandName!;
    }

    if (matchedGenericName != null) {
      return matchedGenericName!;
    }

    return matchedBrandName ?? '';
  }

  List<String> get backendQueries {
    final queries = <String>[];
    final seen = <String>{};

    void addQuery(String? value) {
      final query = value?.trim();
      if (query == null || query.isEmpty) {
        return;
      }

      final key = query.toLowerCase();
      if (seen.add(key)) {
        queries.add(query);
      }
    }

    addQuery(preferredQuery);

    if (matchedOnBrand) {
      addQuery(matchedGenericName);
    } else {
      addQuery(matchedBrandName);
    }

    return List<String>.unmodifiable(queries);
  }
}

class MedicineNameMatcher {
  const MedicineNameMatcher();

  static const Set<String> _packageWords = <String>{
    'capsule',
    'capsules',
    'drug',
    'easy',
    'effective',
    'medicine',
    'oral',
    'pain',
    'relief',
    'swallow',
    'syrup',
    'tablet',
    'tablets',
  };

  String normalizeText(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }

    final withoutDosage = trimmed.replaceAll(
      RegExp(
        r'\b\d+(?:[.,]\d+)?(?:\s|-)?(?:mg|mcg|g|kg|ml|iu|%)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    final withoutPunctuation = withoutDosage.replaceAll(
      RegExp(r'[^a-z0-9\s]'),
      ' ',
    );
    final rawTokens = withoutPunctuation
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty);
    final filteredTokens = rawTokens.where((token) {
      if (RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(token)) {
        return false;
      }

      return !_packageWords.contains(token);
    });

    return filteredTokens.join(' ').trim();
  }

  List<String> normalizeCandidates(Iterable<String> values) {
    final candidates = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final normalized = normalizeText(value);
      if (normalized.isEmpty) {
        continue;
      }

      if (seen.add(normalized)) {
        candidates.add(normalized);
      }
    }

    return List<String>.unmodifiable(candidates);
  }

  String normalizeCombinedText(Iterable<String> values) {
    return normalizeText(
      values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .join(' '),
    );
  }

  MedicineNameMatch? match({
    required List<String> ocrCandidates,
    required List<MedicineNameEntry> entries,
  }) {
    final cleanedCandidates = normalizeCandidates(ocrCandidates);
    final cleanedText = normalizeCombinedText(ocrCandidates);

    _ScoredMedicineNameMatch? bestMatch;

    for (final entry in entries) {
      final candidateMatch = _bestMatchForEntry(
        entry: entry,
        cleanedCandidates: cleanedCandidates,
        cleanedText: cleanedText,
      );
      if (candidateMatch == null) {
        continue;
      }

      if (bestMatch == null || candidateMatch.score > bestMatch.score) {
        bestMatch = candidateMatch;
      }
    }

    return bestMatch?.toMatch(
      cleanedText: cleanedText,
      cleanedCandidates: cleanedCandidates,
    );
  }

  _ScoredMedicineNameMatch? _bestMatchForEntry({
    required MedicineNameEntry entry,
    required List<String> cleanedCandidates,
    required String cleanedText,
  }) {
    _ScoredMedicineNameMatch? bestMatch;

    void consider(_ScoredMedicineNameMatch? match) {
      if (match == null) {
        return;
      }

      if (bestMatch == null || match.score > bestMatch!.score) {
        bestMatch = match;
      }
    }

    final normalizedBrandName = normalizeText(entry.brandName);
    final normalizedGenericName = normalizeText(entry.genericName);

    consider(
      _evaluateName(
        entry: entry,
        normalizedName: normalizedBrandName,
        kind: MedicineNameMatchKind.brandExact,
        cleanedCandidates: cleanedCandidates,
        cleanedText: cleanedText,
      ),
    );
    consider(
      _evaluateName(
        entry: entry,
        normalizedName: normalizedGenericName,
        kind: MedicineNameMatchKind.genericExact,
        cleanedCandidates: cleanedCandidates,
        cleanedText: cleanedText,
      ),
    );
    consider(
      _evaluateName(
        entry: entry,
        normalizedName: normalizedBrandName,
        kind: MedicineNameMatchKind.brandContains,
        cleanedCandidates: cleanedCandidates,
        cleanedText: cleanedText,
      ),
    );
    consider(
      _evaluateName(
        entry: entry,
        normalizedName: normalizedGenericName,
        kind: MedicineNameMatchKind.genericContains,
        cleanedCandidates: cleanedCandidates,
        cleanedText: cleanedText,
      ),
    );

    return bestMatch;
  }

  _ScoredMedicineNameMatch? _evaluateName({
    required MedicineNameEntry entry,
    required String normalizedName,
    required MedicineNameMatchKind kind,
    required List<String> cleanedCandidates,
    required String cleanedText,
  }) {
    if (normalizedName.isEmpty) {
      return null;
    }

    final exactMatch =
        kind == MedicineNameMatchKind.brandExact ||
        kind == MedicineNameMatchKind.genericExact;

    final matchesCandidate = cleanedCandidates.any((candidate) {
      if (exactMatch) {
        return candidate == normalizedName;
      }

      return _containsPhrase(candidate, normalizedName);
    });

    if (matchesCandidate) {
      return _ScoredMedicineNameMatch(
        entry: entry,
        kind: kind,
        score: _scoreFor(kind, normalizedName.length, fromCombinedText: false),
      );
    }

    final matchesCombinedText = exactMatch
        ? cleanedText == normalizedName
        : _containsPhrase(cleanedText, normalizedName);
    if (!matchesCombinedText) {
      return null;
    }

    return _ScoredMedicineNameMatch(
      entry: entry,
      kind: kind,
      score: _scoreFor(kind, normalizedName.length, fromCombinedText: true),
    );
  }

  bool _containsPhrase(String haystack, String needle) {
    if (haystack.isEmpty || needle.isEmpty) {
      return false;
    }

    return ' $haystack '.contains(' $needle ');
  }

  int _scoreFor(
    MedicineNameMatchKind kind,
    int nameLength, {
    required bool fromCombinedText,
  }) {
    final sourcePenalty = fromCombinedText ? -10 : 0;

    switch (kind) {
      case MedicineNameMatchKind.brandExact:
        return 400 + nameLength + sourcePenalty;
      case MedicineNameMatchKind.genericExact:
        return 390 + nameLength + sourcePenalty;
      case MedicineNameMatchKind.brandContains:
        return 300 + nameLength + sourcePenalty;
      case MedicineNameMatchKind.genericContains:
        return 290 + nameLength + sourcePenalty;
    }
  }
}

class _ScoredMedicineNameMatch {
  const _ScoredMedicineNameMatch({
    required this.entry,
    required this.kind,
    required this.score,
  });

  final MedicineNameEntry entry;
  final MedicineNameMatchKind kind;
  final int score;

  MedicineNameMatch toMatch({
    required String cleanedText,
    required List<String> cleanedCandidates,
  }) {
    return MedicineNameMatch(
      entry: entry,
      kind: kind,
      cleanedText: cleanedText,
      cleanedCandidates: cleanedCandidates,
    );
  }
}
