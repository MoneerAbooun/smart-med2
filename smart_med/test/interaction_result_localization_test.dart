import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/features/interactions/presentation/interaction_result_localization.dart';

void main() {
  group('InteractionResultLocalizations', () {
    test('keeps interaction result text unchanged for English', () {
      const l10n = AppLocalizations(Locale('en'));

      expect(
        l10n.interactionResultText(
          'A named warning mention was found in public labeling for this pair.',
        ),
        'A named warning mention was found in public labeling for this pair.',
      );
    });

    test('localizes warning interaction result text for Arabic', () {
      const l10n = AppLocalizations(Locale('ar'));

      expect(
        l10n.interactionResultText(
          'A named warning mention was found in public labeling for this pair.',
        ),
        contains('تحذير'),
      );
      expect(
        l10n.interactionResultText(
          "One medicine appears by name in the other medicine's warning text.",
        ),
        contains('نص التحذيرات'),
      );
      expect(
        l10n.interactionResultText('Direct warning mention: warfarin.'),
        contains('\u2068warfarin\u2069'),
      );
    });
  });
}
