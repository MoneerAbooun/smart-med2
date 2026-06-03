import 'package:smart_med/features/medicine_search/domain/models/medicine_lookup_result.dart';

const Set<String> _genericProductRxNormTermTypes = <String>{'SCD', 'GPCK'};

const Set<String> _brandProductRxNormTermTypes = <String>{'SBD', 'BPCK', 'BN'};

const Set<String> _doseAndFormWords = <String>{
  'actuat',
  'aerosol',
  'cap',
  'capsule',
  'chewable',
  'cream',
  'delayed',
  'dose',
  'dr',
  'ec',
  'er',
  'extended',
  'film',
  'g',
  'gel',
  'hr',
  'im',
  'inhalant',
  'injection',
  'ir',
  'iu',
  'iv',
  'mcg',
  'mg',
  'ml',
  'oral',
  'patch',
  'powder',
  'release',
  'solution',
  'sublingual',
  'suspension',
  'syrup',
  'tab',
  'tablet',
  'topical',
  'xr',
};

MedicineLookupResult removeSameMedicineAlternatives(
  MedicineLookupResult result,
) {
  final referenceNames = _referenceNames(
    result,
  ).map(_normalizedDrugName).where((name) => name.isNotEmpty).toSet();
  final searchedNames = _searchedNames(
    result,
  ).map(_normalizedDrugName).where((name) => name.isNotEmpty).toSet();

  final alternatives = result.alternatives
      .where((alternative) {
        return !_isSameMedicineAlternative(
          alternative,
          referenceNames,
          searchedNames,
        );
      })
      .toList(growable: false);
  final withGenericAlternative = _addGenericAlternativeForBrandSearch(
    result,
    alternatives,
  );

  if (withGenericAlternative.length == result.alternatives.length &&
      _sameAlternatives(withGenericAlternative, result.alternatives)) {
    return result;
  }

  return result.copyWith(alternatives: withGenericAlternative);
}

Iterable<String> _referenceNames(MedicineLookupResult result) sync* {
  yield result.query;
  yield result.medicineName;
  yield result.matchedName ?? '';
  yield result.genericName ?? '';
  yield* result.brandNames;
  yield* result.activeIngredients;
}

Iterable<String> _searchedNames(MedicineLookupResult result) sync* {
  yield result.query;
  yield result.medicineName;
  yield result.matchedName ?? '';
}

bool _isSameMedicineAlternative(
  MedicineAlternativeItem alternative,
  Set<String> referenceNames,
  Set<String> searchedNames,
) {
  final termType = alternative.termType?.trim().toUpperCase();
  final normalizedName = _normalizedDrugName(alternative.name);
  if (normalizedName.isEmpty) {
    return false;
  }

  if (_isGenericProductAlternative(alternative, termType)) {
    return referenceNames.any((referenceName) {
      return _namesReferToSameMedicine(normalizedName, referenceName);
    });
  }

  if (_isBrandProductAlternative(alternative, termType)) {
    return searchedNames.any((searchedName) {
      return _namesReferToSameMedicine(normalizedName, searchedName);
    });
  }

  return referenceNames.any((referenceName) {
    return _namesReferToSameMedicine(normalizedName, referenceName);
  });
}

bool _isGenericProductAlternative(
  MedicineAlternativeItem alternative,
  String? termType,
) {
  if (termType != null && _genericProductRxNormTermTypes.contains(termType)) {
    return true;
  }

  final category = alternative.category.trim().toLowerCase();
  return category == 'generic drug' || category == 'generic pack';
}

bool _isBrandProductAlternative(
  MedicineAlternativeItem alternative,
  String? termType,
) {
  if (termType != null && _brandProductRxNormTermTypes.contains(termType)) {
    return true;
  }

  final category = alternative.category.trim().toLowerCase();
  return category == 'brand drug' ||
      category == 'brand pack' ||
      category == 'brand name';
}

List<MedicineAlternativeItem> _addGenericAlternativeForBrandSearch(
  MedicineLookupResult result,
  List<MedicineAlternativeItem> alternatives,
) {
  final genericName = result.genericName?.trim();
  if (genericName == null || genericName.isEmpty) {
    return alternatives;
  }

  final normalizedGenericName = _normalizedDrugName(genericName);
  if (normalizedGenericName.isEmpty) {
    return alternatives;
  }

  final knownBrandNames = result.brandNames
      .map(_normalizedDrugName)
      .where((name) => name.isNotEmpty)
      .toSet();
  final searchedNames = <String>{
    _normalizedDrugName(result.query),
    _normalizedDrugName(result.medicineName),
    _normalizedDrugName(result.matchedName ?? ''),
  }..removeWhere((name) => name.isEmpty);

  final searchedKnownBrand = searchedNames.any((searchedName) {
    return knownBrandNames.any((brandName) {
      return _namesReferToSameMedicine(searchedName, brandName);
    });
  });
  final allSearchedNamesAreGeneric =
      searchedNames.isNotEmpty &&
      searchedNames.every((searchedName) {
        return _namesReferToSameMedicine(searchedName, normalizedGenericName);
      });

  if (!searchedKnownBrand && allSearchedNamesAreGeneric) {
    return alternatives;
  }

  final hasDistinctBrandName =
      searchedNames.any((searchedName) {
        return !_namesReferToSameMedicine(searchedName, normalizedGenericName);
      }) ||
      knownBrandNames.any((brandName) {
        return !_namesReferToSameMedicine(brandName, normalizedGenericName);
      });

  if (!hasDistinctBrandName) {
    return alternatives;
  }

  final alreadyIncluded = alternatives.any((alternative) {
    final alternativeName = _normalizedDrugName(alternative.name);
    return alternativeName.isNotEmpty &&
        _namesReferToSameMedicine(alternativeName, normalizedGenericName);
  });

  if (alreadyIncluded) {
    return alternatives;
  }

  return <MedicineAlternativeItem>[
    MedicineAlternativeItem(name: genericName, category: 'Generic drug'),
    ...alternatives,
  ];
}

bool _sameAlternatives(
  List<MedicineAlternativeItem> first,
  List<MedicineAlternativeItem> second,
) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index += 1) {
    final firstItem = first[index];
    final secondItem = second[index];

    if (firstItem.name != secondItem.name ||
        firstItem.category != secondItem.category ||
        firstItem.rxcui != secondItem.rxcui ||
        firstItem.termType != secondItem.termType) {
      return false;
    }
  }

  return true;
}

bool _namesReferToSameMedicine(String left, String right) {
  if (left == right) {
    return true;
  }

  final leftTokens = left.split(' ').where((item) => item.isNotEmpty).toSet();
  final rightTokens = right.split(' ').where((item) => item.isNotEmpty).toSet();

  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return false;
  }

  return leftTokens.containsAll(rightTokens) ||
      rightTokens.containsAll(leftTokens);
}

String _normalizedDrugName(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  final tokens = normalized
      .split(' ')
      .where((token) {
        if (token.isEmpty) {
          return false;
        }

        if (int.tryParse(token) != null) {
          return false;
        }

        return !_doseAndFormWords.contains(token);
      })
      .toList(growable: false);

  return tokens.join(' ');
}
