String? _stringOrNull(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    final seen = <String>{};
    final results = <String>[];

    for (final item in value) {
      final text = _stringOrNull(item);
      if (text == null) {
        continue;
      }

      final key = text.toLowerCase();
      if (seen.add(key)) {
        results.add(text);
      }
    }

    return List<String>.unmodifiable(results);
  }

  final text = _stringOrNull(value);
  if (text == null) {
    return const <String>[];
  }

  return List<String>.unmodifiable(<String>[text]);
}

class LocalMedicine {
  const LocalMedicine({
    this.id,
    this.brandName,
    this.genericName,
    this.activeIngredients = const <String>[],
    this.strength,
    this.form,
    this.category,
    this.searchNames = const <String>[],
  });

  final String? id;
  final String? brandName;
  final String? genericName;
  final List<String> activeIngredients;
  final String? strength;
  final String? form;
  final String? category;
  final List<String> searchNames;

  factory LocalMedicine.fromMap(Map<String, dynamic> map) {
    return LocalMedicine(
      id: _stringOrNull(map['id']),
      brandName: _stringOrNull(map['brandName'] ?? map['brand_name']),
      genericName: _stringOrNull(map['genericName'] ?? map['generic_name']),
      activeIngredients: _stringList(
        map['activeIngredients'] ?? map['active_ingredients'],
      ),
      strength: _stringOrNull(map['strength']),
      form: _stringOrNull(map['form']),
      category: _stringOrNull(map['category']),
      searchNames: _stringList(map['searchNames'] ?? map['search_names']),
    );
  }

  List<String> get searchableTerms {
    final seen = <String>{};
    final results = <String>[];

    void addValue(String? value) {
      final text = _stringOrNull(value);
      if (text == null) {
        return;
      }

      final key = text.toLowerCase();
      if (seen.add(key)) {
        results.add(text);
      }
    }

    addValue(brandName);
    addValue(genericName);

    for (final ingredient in activeIngredients) {
      addValue(ingredient);
    }

    for (final name in searchNames) {
      addValue(name);
    }

    return List<String>.unmodifiable(results);
  }
}
