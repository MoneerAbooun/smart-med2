class ParsedTimeOfDay {
  const ParsedTimeOfDay({required this.hour, required this.minute});

  final int hour;
  final int minute;
}

class LocalizedTimeParser {
  const LocalizedTimeParser._();

  static final RegExp _trailingMeridiemPattern = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(\S+)$',
  );
  static final RegExp _leadingMeridiemPattern = RegExp(
    r'^(\S+)\s+(\d{1,2}):(\d{2})$',
  );
  static final RegExp _twentyFourHourPattern = RegExp(r'^(\d{1,2}):(\d{2})$');
  static final RegExp _directionalMarksPattern = RegExp('[\u061C\u200E\u200F]');
  static final RegExp _arabicDiacriticsPattern = RegExp(
    '[\u064B-\u065F\u0670]',
  );

  static const String _arabicAmLetter = '\u0635';
  static const String _arabicPmLetter = '\u0645';
  static const String _arabicMorning = '\u0635\u0628\u0627\u062D';
  static const String _arabicEvening = '\u0645\u0633\u0627\u0621';

  static ParsedTimeOfDay parse(String value) {
    final normalized = _normalize(value);

    final trailingMeridiemMatch = _trailingMeridiemPattern.firstMatch(
      normalized,
    );
    if (trailingMeridiemMatch != null) {
      return _parseMeridiemTime(
        originalValue: value,
        hourText: trailingMeridiemMatch.group(1)!,
        minuteText: trailingMeridiemMatch.group(2)!,
        meridiemText: trailingMeridiemMatch.group(3)!,
      );
    }

    final leadingMeridiemMatch = _leadingMeridiemPattern.firstMatch(normalized);
    if (leadingMeridiemMatch != null) {
      return _parseMeridiemTime(
        originalValue: value,
        hourText: leadingMeridiemMatch.group(2)!,
        minuteText: leadingMeridiemMatch.group(3)!,
        meridiemText: leadingMeridiemMatch.group(1)!,
      );
    }

    final twentyFourHourMatch = _twentyFourHourPattern.firstMatch(normalized);
    if (twentyFourHourMatch != null) {
      final int hour = int.parse(twentyFourHourMatch.group(1)!);
      final int minute = int.parse(twentyFourHourMatch.group(2)!);

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        throw FormatException('Invalid time value: $value');
      }

      return ParsedTimeOfDay(hour: hour, minute: minute);
    }

    throw FormatException('Invalid time format: $value');
  }

  static ParsedTimeOfDay _parseMeridiemTime({
    required String originalValue,
    required String hourText,
    required String minuteText,
    required String meridiemText,
  }) {
    int hour = int.parse(hourText);
    final int minute = int.parse(minuteText);
    final String? period = _normalizeMeridiem(meridiemText);

    if (period == null) {
      throw FormatException('Invalid time format: $originalValue');
    }

    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) {
      throw FormatException('Invalid time value: $originalValue');
    }

    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return ParsedTimeOfDay(hour: hour, minute: minute);
  }

  static String _normalize(String value) {
    final buffer = StringBuffer();

    for (final rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else {
        buffer.writeCharCode(rune);
      }
    }

    return buffer
        .toString()
        .replaceAll(_directionalMarksPattern, '')
        .trim()
        .toUpperCase();
  }

  static String? _normalizeMeridiem(String value) {
    final compact = value
        .replaceAll(RegExp(r'[\s.]'), '')
        .replaceAll(_arabicDiacriticsPattern, '');

    if (compact == 'AM' ||
        compact == _arabicAmLetter ||
        compact == _arabicMorning ||
        compact == '$_arabicMorning\u0627') {
      return 'AM';
    }

    if (compact == 'PM' ||
        compact == _arabicPmLetter ||
        compact == _arabicEvening) {
      return 'PM';
    }

    return null;
  }
}
