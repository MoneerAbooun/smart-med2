import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/app/localization/app_localizations.dart';

void main() {
  group('medication safety localization', () {
    test('uses Arabic strings for the add-medicine safety panel', () {
      const l10n = AppLocalizations(Locale('ar'));

      expect(l10n.text('medication.safety.title'), isNot('Safety check'));
      expect(
        l10n.text('medication.safety.signal.directAllergy.title'),
        contains('حساسية'),
      );

      final detail = l10n.format(
        'medication.safety.signal.directAllergy.detail',
        <String, String>{
          'medicine': l10n.isolate('Trofin'),
          'allergy': l10n.isolate('Ibuprofen'),
        },
      );

      expect(detail, isNot(contains('matches')));
      expect(detail, contains('Trofin'));
      expect(detail, contains('Ibuprofen'));
    });
  });
}
