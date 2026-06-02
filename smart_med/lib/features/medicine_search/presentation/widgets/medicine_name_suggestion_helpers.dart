import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/data/medicine/medicine_name_entry.dart';

String _normalizeMedicineSuggestionText(String value) {
  return value.trim().toLowerCase();
}

String medicineEntrySearchValue(MedicineNameEntry entry) {
  final brandName = entry.brandName.trim();
  if (brandName.isNotEmpty) {
    return brandName;
  }

  return entry.genericName.trim();
}

String medicineEntryDisplayTitle(MedicineNameEntry entry) {
  final brandName = entry.brandName.trim();
  if (brandName.isNotEmpty) {
    return brandName;
  }

  return entry.genericName.trim();
}

String? medicineEntryDisplaySubtitle(
  BuildContext context,
  MedicineNameEntry entry,
) {
  final brandName = entry.brandName.trim();
  final genericName = entry.genericName.trim();

  if (genericName.isEmpty) {
    return null;
  }

  if (brandName.isEmpty ||
      brandName.toLowerCase() == genericName.toLowerCase()) {
    return null;
  }

  final l10n = context.l10n;
  return '${l10n.text('common.generic')}: ${l10n.isolate(genericName)}';
}

List<MedicineNameEntry> filterMedicineNameSuggestions(
  List<MedicineNameEntry> entries,
  String query, {
  int limit = 5,
}) {
  final normalizedQuery = _normalizeMedicineSuggestionText(query);
  if (normalizedQuery.isEmpty) {
    return const <MedicineNameEntry>[];
  }

  final scoredSuggestions = <_ScoredMedicineSuggestion>[];
  final seen = <String>{};

  for (final entry in entries) {
    final brandName = entry.brandName.trim();
    final genericName = entry.genericName.trim();
    final displayValue = medicineEntrySearchValue(entry);
    if (displayValue.isEmpty) {
      continue;
    }

    final normalizedBrand = _normalizeMedicineSuggestionText(brandName);
    final normalizedGeneric = _normalizeMedicineSuggestionText(genericName);

    final brandStarts = normalizedBrand.startsWith(normalizedQuery);
    final genericStarts = normalizedGeneric.startsWith(normalizedQuery);
    final brandContains = normalizedBrand.contains(normalizedQuery);
    final genericContains = normalizedGeneric.contains(normalizedQuery);

    if (!brandContains && !genericContains) {
      continue;
    }

    final key = displayValue.toLowerCase();
    if (!seen.add(key)) {
      continue;
    }

    final score = brandStarts
        ? 0
        : genericStarts
        ? 1
        : brandContains
        ? 2
        : 3;

    scoredSuggestions.add(_ScoredMedicineSuggestion(entry, score));
  }

  scoredSuggestions.sort((first, second) {
    final scoreComparison = first.score.compareTo(second.score);
    if (scoreComparison != 0) {
      return scoreComparison;
    }

    return medicineEntryDisplayTitle(first.entry).toLowerCase().compareTo(
      medicineEntryDisplayTitle(second.entry).toLowerCase(),
    );
  });

  return scoredSuggestions
      .take(limit)
      .map((suggestion) => suggestion.entry)
      .toList(growable: false);
}

class MedicineNameSuggestionsList extends StatelessWidget {
  const MedicineNameSuggestionsList({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.disabled = false,
  });

  final List<MedicineNameEntry> suggestions;
  final ValueChanged<MedicineNameEntry> onSelected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text('common.suggestions'),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: suggestions
                .map((entry) {
                  final subtitle = medicineEntryDisplaySubtitle(context, entry);

                  return ListTile(
                    dense: true,
                    enabled: !disabled,
                    leading: const Icon(Icons.medication_outlined),
                    title: Text(
                      context.l10n.isolate(medicineEntryDisplayTitle(entry)),
                    ),
                    subtitle: subtitle == null ? null : Text(subtitle),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: disabled ? null : () => onSelected(entry),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _ScoredMedicineSuggestion {
  const _ScoredMedicineSuggestion(this.entry, this.score);

  final MedicineNameEntry entry;
  final int score;
}
