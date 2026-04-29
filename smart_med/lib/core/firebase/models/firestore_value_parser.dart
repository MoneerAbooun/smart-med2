import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreValueParser {
  const FirestoreValueParser._();

  static DateTime? dateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static String? stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? intOrNull(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString().trim());
  }

  static double? doubleOrNull(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim());
  }

  static bool boolOrDefault(dynamic value, {bool defaultValue = false}) {
    if (value == null) {
      return defaultValue;
    }

    if (value is bool) {
      return value;
    }

    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }

    if (normalized == 'false') {
      return false;
    }

    return defaultValue;
  }

  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }

    return <String, dynamic>{};
  }

  static List<String> stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map(stringOrNull)
          .whereType<String>()
          .toList(growable: false);
    }

    return const <String>[];
  }

  static List<int> intList(dynamic value) {
    if (value is Iterable) {
      return value
          .map(intOrNull)
          .whereType<int>()
          .toList(growable: false);
    }

    return const <int>[];
  }

  static Map<String, dynamic> withoutNulls(Map<String, dynamic> value) {
    final result = <String, dynamic>{};

    value.forEach((key, item) {
      if (item != null) {
        result[key] = item;
      }
    });

    return result;
  }
}
