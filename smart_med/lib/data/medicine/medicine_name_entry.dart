String? _textOrNull(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}

class MedicineNameEntry {
  const MedicineNameEntry({
    this.id,
    required this.brandName,
    required this.genericName,
  });

  final String? id;
  final String brandName;
  final String genericName;

  factory MedicineNameEntry.fromMap(Map<String, dynamic> map) {
    final brandName = _textOrNull(map['brandName'] ?? map['brand_name']) ?? '';
    final genericName =
        _textOrNull(map['genericName'] ?? map['generic_name']) ?? '';

    if (brandName.isEmpty && genericName.isEmpty) {
      throw const FormatException(
        'Medicine entry must include a brand name or generic name.',
      );
    }

    return MedicineNameEntry(
      id: _textOrNull(map['id']),
      brandName: brandName,
      genericName: genericName,
    );
  }
}
