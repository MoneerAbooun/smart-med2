import 'package:smart_med/core/firebase/models/firestore_value_parser.dart';
import 'package:smart_med/features/medications/domain/models/medication_schedule_time.dart';

class MedicationRecord {
  MedicationRecord({
    this.id,
    required this.userId,
    required this.name,
    this.medicineId,
    this.genericName,
    this.brandName,
    this.activeIngredients = const <String>[],
    this.strength,
    this.drugCatalogId,
    required this.doseAmount,
    required this.doseUnit,
    this.form,
    required this.frequencyPerDay,
    required this.scheduledTimes,
    this.startDate,
    this.endDate,
    this.instructions,
    this.notes,
    this.imageUrl,
    required this.remindersEnabled,
    required this.status,
    this.notificationIds = const <int>[],
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userId;
  final String name;
  final String? medicineId;
  final String? genericName;
  final String? brandName;
  final List<String> activeIngredients;
  final String? strength;
  final String? drugCatalogId;
  final double doseAmount;
  final String doseUnit;
  final String? form;
  final int frequencyPerDay;
  final List<MedicationScheduleTime> scheduledTimes;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? instructions;
  final String? notes;
  final String? imageUrl;
  final bool remindersEnabled;
  final String status;
  final List<int> notificationIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get dosage {
    final formattedDose = _formatDoseAmount(doseAmount);
    final normalizedUnit = doseUnit.trim();

    return normalizedUnit.isEmpty
        ? formattedDose
        : '$formattedDose $normalizedUnit';
  }

  String get frequency {
    final count = frequencyPerDay <= 0 ? 1 : frequencyPerDay;
    final suffix = count == 1 ? 'time' : 'times';
    return '$count $suffix per day';
  }

  List<String> get reminderTimes {
    return scheduledTimes
        .map((item) => item.toDisplayString())
        .toList(growable: false);
  }

  factory MedicationRecord.fromMap(String id, Map<String, dynamic> map) {
    final scheduledTimes = _parseScheduledTimes(map);
    final dosageInfo = _parseDosageInfo(map);

    return MedicationRecord(
      id: id,
      userId: FirestoreValueParser.stringOrNull(map['userId']) ?? '',
      name: FirestoreValueParser.stringOrNull(map['name']) ?? 'Unknown',
      medicineId: FirestoreValueParser.stringOrNull(
        map['medicineId'] ?? map['localMedicineId'],
      ),
      genericName: FirestoreValueParser.stringOrNull(map['genericName']),
      brandName: FirestoreValueParser.stringOrNull(map['brandName']),
      activeIngredients: FirestoreValueParser.stringList(
        map['activeIngredients'] ?? map['active_ingredients'],
      ),
      strength: FirestoreValueParser.stringOrNull(map['strength']),
      drugCatalogId: FirestoreValueParser.stringOrNull(map['drugCatalogId']),
      doseAmount: dosageInfo.amount,
      doseUnit: dosageInfo.unit,
      form: FirestoreValueParser.stringOrNull(map['form']),
      frequencyPerDay: _parseFrequencyPerDay(map, scheduledTimes.length),
      scheduledTimes: scheduledTimes,
      startDate:
          FirestoreValueParser.dateTime(map['startDate']) ??
          FirestoreValueParser.dateTime(map['startedAt']),
      endDate: FirestoreValueParser.dateTime(map['endDate']),
      instructions: FirestoreValueParser.stringOrNull(map['instructions']),
      notes:
          FirestoreValueParser.stringOrNull(map['notes']) ??
          FirestoreValueParser.stringOrNull(map['note']),
      imageUrl: FirestoreValueParser.stringOrNull(map['imageUrl']),
      remindersEnabled: FirestoreValueParser.boolOrDefault(
        map['remindersEnabled'],
        defaultValue: true,
      ),
      status: FirestoreValueParser.stringOrNull(map['status']) ?? 'active',
      notificationIds: FirestoreValueParser.intList(map['notificationIds']),
      createdAt: FirestoreValueParser.dateTime(map['createdAt']),
      updatedAt: FirestoreValueParser.dateTime(map['updatedAt']),
    );
  }

  MedicationRecord copyWith({
    String? id,
    String? userId,
    String? name,
    String? medicineId,
    String? genericName,
    String? brandName,
    List<String>? activeIngredients,
    String? strength,
    String? drugCatalogId,
    double? doseAmount,
    String? doseUnit,
    String? form,
    int? frequencyPerDay,
    List<MedicationScheduleTime>? scheduledTimes,
    DateTime? startDate,
    DateTime? endDate,
    String? instructions,
    String? notes,
    String? imageUrl,
    bool? remindersEnabled,
    String? status,
    List<int>? notificationIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      medicineId: medicineId ?? this.medicineId,
      genericName: genericName ?? this.genericName,
      brandName: brandName ?? this.brandName,
      activeIngredients: activeIngredients ?? this.activeIngredients,
      strength: strength ?? this.strength,
      drugCatalogId: drugCatalogId ?? this.drugCatalogId,
      doseAmount: doseAmount ?? this.doseAmount,
      doseUnit: doseUnit ?? this.doseUnit,
      form: form ?? this.form,
      frequencyPerDay: frequencyPerDay ?? this.frequencyPerDay,
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      instructions: instructions ?? this.instructions,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      status: status ?? this.status,
      notificationIds: notificationIds ?? this.notificationIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreValueParser.withoutNulls({
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'reminderTimes': reminderTimes,
      'medicineId': medicineId,
      'genericName': genericName,
      'brandName': brandName,
      'activeIngredients': activeIngredients,
      'strength': strength,
      'drugCatalogId': drugCatalogId,
      'doseAmount': doseAmount,
      'doseUnit': doseUnit,
      'form': form,
      'frequencyPerDay': frequencyPerDay,
      'scheduledTimes': scheduledTimes.map((item) => item.toMap()).toList(),
      'startDate': startDate,
      'endDate': endDate,
      'instructions': instructions,
      'notes': notes,
      'imageUrl': imageUrl,
      'remindersEnabled': remindersEnabled,
      'status': status,
      'notificationIds': notificationIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,

      // Compatibility fields while the UI is still being migrated.
      'dose': doseAmount,
      'timesPerDay': frequencyPerDay,
      'times': reminderTimes,
      'note': notes,
    });
  }

  static List<MedicationScheduleTime> _parseScheduledTimes(
    Map<String, dynamic> map,
  ) {
    final dynamic scheduledTimesValue = map['scheduledTimes'];

    if (scheduledTimesValue is Iterable) {
      return scheduledTimesValue
          .map(
            (item) =>
                MedicationScheduleTime.fromMap(FirestoreValueParser.map(item)),
          )
          .toList(growable: false);
    }

    final reminderTimes = FirestoreValueParser.stringList(map['reminderTimes']);
    if (reminderTimes.isNotEmpty) {
      return reminderTimes
          .map(MedicationScheduleTime.tryFromDisplayString)
          .whereType<MedicationScheduleTime>()
          .toList(growable: false);
    }

    return FirestoreValueParser.stringList(map['times'])
        .map(MedicationScheduleTime.tryFromDisplayString)
        .whereType<MedicationScheduleTime>()
        .toList(growable: false);
  }

  static _ParsedDosage _parseDosageInfo(Map<String, dynamic> map) {
    final numericDose =
        FirestoreValueParser.doubleOrNull(map['doseAmount']) ??
        FirestoreValueParser.doubleOrNull(map['dose']);
    final explicitUnit = FirestoreValueParser.stringOrNull(map['doseUnit']);

    if (numericDose != null || explicitUnit != null) {
      return _ParsedDosage(
        amount: numericDose ?? 0,
        unit: explicitUnit ?? 'mg',
      );
    }

    final dosageText = FirestoreValueParser.stringOrNull(map['dosage']);
    if (dosageText == null) {
      return const _ParsedDosage(amount: 0, unit: 'mg');
    }

    final match = RegExp(
      r'^([0-9]+(?:\.[0-9]+)?)\s*(.*)$',
    ).firstMatch(dosageText);

    if (match == null) {
      return const _ParsedDosage(amount: 0, unit: 'mg');
    }

    final parsedAmount = double.tryParse(match.group(1) ?? '') ?? 0;
    final parsedUnit = match.group(2)?.trim();

    return _ParsedDosage(
      amount: parsedAmount,
      unit: (parsedUnit == null || parsedUnit.isEmpty) ? 'mg' : parsedUnit,
    );
  }

  static int _parseFrequencyPerDay(
    Map<String, dynamic> map,
    int reminderCount,
  ) {
    final explicitFrequency =
        FirestoreValueParser.intOrNull(map['frequencyPerDay']) ??
        FirestoreValueParser.intOrNull(map['timesPerDay']);

    if (explicitFrequency != null && explicitFrequency > 0) {
      return explicitFrequency;
    }

    final frequencyText = FirestoreValueParser.stringOrNull(map['frequency']);
    final match = RegExp(r'(\d+)').firstMatch(frequencyText ?? '');
    if (match != null) {
      return int.parse(match.group(1)!);
    }

    return reminderCount > 0 ? reminderCount : 1;
  }

  static String _formatDoseAmount(double value) {
    final hasNoFraction = value == value.truncateToDouble();
    return hasNoFraction ? value.toStringAsFixed(0) : value.toString();
  }
}

class _ParsedDosage {
  const _ParsedDosage({required this.amount, required this.unit});

  final double amount;
  final String unit;
}
