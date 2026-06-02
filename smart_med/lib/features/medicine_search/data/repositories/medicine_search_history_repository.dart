import 'package:shared_preferences/shared_preferences.dart';

class MedicineSearchHistoryRepository {
  const MedicineSearchHistoryRepository();

  static const String _storageKey = 'medicine_search_history';
  static const int _maxItems = 3;

  Future<List<String>> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    return List<String>.from(preferences.getStringList(_storageKey) ?? const []);
  }

  Future<List<String>> saveSearch(String value) async {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      return loadHistory();
    }

    final preferences = await SharedPreferences.getInstance();
    final currentHistory =
        preferences.getStringList(_storageKey) ?? const <String>[];
    final normalizedKey = normalizedValue.toLowerCase();

    final updatedHistory = <String>[
      normalizedValue,
      ...currentHistory.where(
        (item) => item.trim().toLowerCase() != normalizedKey,
      ),
    ].take(_maxItems).toList(growable: false);

    await preferences.setStringList(_storageKey, updatedHistory);
    return updatedHistory;
  }
}

const medicineSearchHistoryRepository = MedicineSearchHistoryRepository();
