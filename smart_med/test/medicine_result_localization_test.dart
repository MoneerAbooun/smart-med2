import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/features/medicine_search/presentation/medicine_result_localization.dart';

void main() {
  group('MedicineResultLocalizations', () {
    test('keeps result text unchanged for English', () {
      const l10n = AppLocalizations(Locale('en'));

      expect(
        l10n.medicineResultText('INDICATIONS AND USAGE Sildenafil citrate'),
        'INDICATIONS AND USAGE Sildenafil citrate',
      );
    });

    test('summarizes public label sections cleanly for Arabic', () {
      const l10n = AppLocalizations(Locale('ar'));

      final text = l10n.medicineResultText(
        'INDICATIONS AND USAGE Sildenafil citrate is indicated for the treatment of pulmonary arterial hypertension.',
        section: MedicineResultSection.commonUses,
      );

      expect(text, contains('يُستخدم هذا الدواء لعلاج'));
      expect(text, contains('ارتفاع ضغط الدم الشرياني الرئوي'));
      expect(text, isNot(contains('INDICATIONS AND USAGE')));
      expect(text, isNot(contains('Sildenafil citrate')));
    });

    test('does not word-translate long dose labels for Arabic', () {
      const l10n = AppLocalizations(Locale('ar'));

      final text = l10n.medicineResultText(
        'DOSAGE AND ADMINISTRATION The recommended dose is 20 mg three times daily.',
        section: MedicineResultSection.dose,
      );

      expect(text, contains('20 mg'));
      expect(text, contains('ثلاث مرات يوميا'));
      expect(text, isNot(contains('recommended dose')));
      expect(text, isNot(contains('DOSAGE AND ADMINISTRATION')));
    });

    test('deduplicates repeated Arabic section summaries', () {
      const l10n = AppLocalizations(Locale('ar'));

      final warnings = l10n.medicineResultTexts(const <String>[
        'WARNINGS AND PRECAUTIONS Patients with bleeding risk should seek advice.',
        'PRECAUTIONS Bleeding events have been reported in some patients.',
      ], section: MedicineResultSection.warnings);
      final disclaimers = l10n.medicineResultTexts(const <String>[
        'Questions? ask your doctor.',
        'Pregnancy or breast-feeding information should be reviewed.',
        'Questions? ask your pharmacist.',
      ], section: MedicineResultSection.disclaimer);

      expect(warnings, hasLength(1));
      expect(disclaimers, hasLength(1));
    });

    test('localizes medicine lookup errors for Arabic', () {
      const l10n = AppLocalizations(Locale('ar'));

      expect(
        l10n.medicineResultText(
          'No matching medicine was found. Try a brand name or generic name.',
        ),
        contains('لم يتم العثور'),
      );
    });

    test('localizes alternative category labels for Arabic', () {
      const l10n = AppLocalizations(Locale('ar'));

      expect(
        l10n.medicineAlternativeLabel('Sildenafil (Brand name)'),
        contains('(اسم تجاري)'),
      );
    });
  });
}
