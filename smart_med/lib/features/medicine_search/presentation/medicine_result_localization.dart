import 'package:smart_med/app/localization/app_localizations.dart';

enum MedicineResultSection {
  brandNames,
  activeIngredients,
  commonUses,
  dose,
  warnings,
  sideEffects,
  storage,
  disclaimer,
}

extension MedicineResultLocalizations on AppLocalizations {
  String medicineResultText(String value, {MedicineResultSection? section}) {
    final text = _normalizeResultText(value);
    if (text.isEmpty || !isArabic) {
      return text;
    }

    final exact = _arabicExactMedicineResultText[text];
    if (exact != null) {
      return exact;
    }

    if (section != null) {
      return _sectionSummary(text, section);
    }

    return isolate(text);
  }

  List<String> medicineResultTexts(
    Iterable<String> values, {
    MedicineResultSection? section,
  }) {
    final results = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final text = medicineResultText(value, section: section).trim();
      if (text.isEmpty) {
        continue;
      }

      if (seen.add(_dedupeKey(text))) {
        results.add(text);
      }
    }

    return results;
  }

  String medicineAlternativeLabel(String value) {
    final text = _normalizeResultText(value);
    if (text.isEmpty || !isArabic) {
      return text;
    }

    final match = RegExp(r'^(.+)\s+\((.+)\)$').firstMatch(text);
    if (match == null) {
      return medicineResultText(text);
    }

    final name = isolate(match.group(1)!.trim());
    final category = medicineResultText(match.group(2)!.trim());
    return '$name ($category)';
  }

  String _sectionSummary(String text, MedicineResultSection section) {
    switch (section) {
      case MedicineResultSection.brandNames:
      case MedicineResultSection.activeIngredients:
        return isolate(text);
      case MedicineResultSection.commonUses:
        return _commonUsesSummary(text);
      case MedicineResultSection.dose:
        return _doseSummary(text);
      case MedicineResultSection.warnings:
        return _warningSummary(text);
      case MedicineResultSection.sideEffects:
        return _sideEffectsSummary(text);
      case MedicineResultSection.storage:
        return _storageSummary(text);
      case MedicineResultSection.disclaimer:
        return _disclaimerSummary(text);
    }
  }

  String _commonUsesSummary(String text) {
    final normalized = text.toLowerCase();
    if (normalized.contains('pulmonary arterial hypertension')) {
      return 'يُستخدم هذا الدواء لعلاج ارتفاع ضغط الدم الشرياني الرئوي حسب ما تذكره النشرة العامة.';
    }
    if (normalized.contains('erectile dysfunction')) {
      return 'تذكر النشرة العامة أن هذا الدواء قد يُستخدم لعلاج ضعف الانتصاب عند وصفه من الطبيب.';
    }
    if (normalized.contains('pain') && normalized.contains('fever')) {
      return 'تذكر النشرة العامة أن هذا الدواء قد يُستخدم لتخفيف الألم أو خفض الحرارة.';
    }
    if (normalized.contains('pain')) {
      return 'تذكر النشرة العامة أن هذا الدواء قد يُستخدم لتخفيف الألم.';
    }
    if (normalized.contains('fever')) {
      return 'تذكر النشرة العامة أن هذا الدواء قد يُستخدم لخفض الحرارة.';
    }

    return 'توضح النشرة العامة دواعي استعمال هذا الدواء. استخدمه فقط حسب وصف الطبيب أو إرشادات الصيدلي.';
  }

  String _doseSummary(String text) {
    final doses = _doseMentions(text);
    final schedules = _scheduleMentions(text);
    final parts = <String>[];

    if (doses.isNotEmpty) {
      parts.add('تذكر النشرة جرعات مثل ${doses.map(isolate).join('، ')}');
    }
    if (schedules.isNotEmpty) {
      parts.add('وتكرارا مثل ${schedules.join(' أو ')}');
    }

    if (parts.isNotEmpty) {
      return '${parts.join(' ')}. اتبع الجرعة التي وصفها الطبيب ولا تغيّر الجرعة أو التكرار دون استشارة.';
    }

    return 'تحتوي النشرة على تعليمات الجرعة وطريقة الاستعمال. اتبع الجرعة التي وصفها الطبيب أو الصيدلي ولا تغيّرها من نفسك.';
  }

  String _warningSummary(String text) {
    final normalized = text.toLowerCase();
    if (normalized.contains('nitrate') ||
        normalized.contains('nitric oxide') ||
        normalized.contains('hypotensive')) {
      return 'تحذر النشرة من خطر انخفاض ضغط الدم، خصوصا مع النترات أو مانحات أكسيد النيتريك. راجع الطبيب أو الصيدلي قبل الجمع مع أي دواء آخر.';
    }
    if (normalized.contains('bleeding')) {
      return 'تذكر النشرة تحذيرات تتعلق بزيادة خطر النزيف. اطلب نصيحة طبية إذا ظهر نزيف غير معتاد أو كدمات شديدة.';
    }
    if (normalized.contains('allergic')) {
      return 'تذكر النشرة احتمال حدوث تفاعل تحسسي. أوقف الدواء واطلب مساعدة طبية إذا ظهرت حساسية شديدة أو صعوبة في التنفس.';
    }
    if (normalized.contains('heart') || normalized.contains('blood pressure')) {
      return 'تذكر النشرة تحذيرات متعلقة بالقلب أو ضغط الدم. راجع الطبيب إذا كانت لديك أمراض قلب أو ضغط أو أدوية مؤثرة على الضغط.';
    }

    return 'تحتوي النشرة على تحذيرات واحتياطات مهمة. راجع الطبيب أو الصيدلي قبل الاستخدام، خصوصا إذا لديك أمراض مزمنة أو أدوية أخرى.';
  }

  String _sideEffectsSummary(String text) {
    final normalized = text.toLowerCase();
    final effects = <String>[];
    if (normalized.contains('headache')) effects.add('الصداع');
    if (normalized.contains('flushing')) effects.add('احمرار الوجه');
    if (normalized.contains('dyspepsia') ||
        normalized.contains('indigestion')) {
      effects.add('اضطراب المعدة');
    }
    if (normalized.contains('dizziness')) effects.add('الدوخة');
    if (normalized.contains('nausea')) effects.add('الغثيان');
    if (normalized.contains('rash')) effects.add('الطفح الجلدي');
    if (normalized.contains('vision') || normalized.contains('visual')) {
      effects.add('تغيرات في النظر');
    }

    if (effects.isNotEmpty) {
      return 'تذكر النشرة آثارا جانبية محتملة مثل ${effects.join('، ')}. اطلب مساعدة طبية إذا كانت الأعراض شديدة أو مستمرة.';
    }

    return 'تذكر النشرة آثارا جانبية محتملة. اطلب مساعدة طبية إذا ظهرت أعراض شديدة أو غير معتادة.';
  }

  String _storageSummary(String text) {
    final normalized = text.toLowerCase();
    final notes = <String>[];
    if (normalized.contains('room temperature')) {
      notes.add('يُحفظ في درجة حرارة الغرفة');
    }
    if (normalized.contains('protect from light')) {
      notes.add('ويُحمى من الضوء');
    }
    if (normalized.contains('protect from moisture')) {
      notes.add('ويُحمى من الرطوبة');
    }
    if (normalized.contains('tightly closed')) {
      notes.add('مع إبقاء العبوة مغلقة بإحكام');
    }

    if (notes.isNotEmpty) {
      return '${notes.join(' ')}. اتبع تعليمات التخزين الموجودة على العبوة.';
    }

    return 'تحتوي النشرة على معلومات التخزين والتعامل. احفظ الدواء حسب تعليمات العبوة وبعيدا عن متناول الأطفال.';
  }

  String _disclaimerSummary(String text) {
    final exact = _arabicExactMedicineResultText[text];
    if (exact != null) {
      return exact;
    }

    return 'هذه المعلومات من نشرات ومراجع عامة ولا تغني عن نصيحة الطبيب أو الصيدلي.';
  }
}

String _normalizeResultText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _dedupeKey(String value) {
  return _normalizeResultText(value).toLowerCase();
}

List<String> _doseMentions(String text) {
  final matches = RegExp(
    r'\b\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml|mL|units?)\b',
    caseSensitive: false,
  ).allMatches(text);

  final seen = <String>{};
  return matches
      .map((match) => match.group(0)!.trim())
      .where((value) => seen.add(value.toLowerCase()))
      .take(3)
      .toList(growable: false);
}

List<String> _scheduleMentions(String text) {
  final normalized = text.toLowerCase();
  final schedules = <String>[];

  void addIfFound(String needle, String label) {
    if (normalized.contains(needle) && !schedules.contains(label)) {
      schedules.add(label);
    }
  }

  addIfFound('once daily', 'مرة واحدة يوميا');
  addIfFound('twice daily', 'مرتين يوميا');
  addIfFound('three times daily', 'ثلاث مرات يوميا');
  addIfFound('4 times daily', 'أربع مرات يوميا');
  addIfFound('four times daily', 'أربع مرات يوميا');
  addIfFound('per day', 'يوميا');
  addIfFound('daily', 'يوميا');

  return schedules.take(2).toList(growable: false);
}

const Map<String, String> _arabicExactMedicineResultText = <String, String>{
  'Please enter a medicine name.': 'يرجى إدخال اسم الدواء.',
  'Drug name is required': 'اسم الدواء مطلوب.',
  'Drug not found in RxNorm': 'لم يتم العثور على الدواء في RxNorm.',
  'No matching medicine was found. Try a brand name or generic name.':
      'لم يتم العثور على دواء مطابق. جرّب اسما تجاريا أو اسما علميا.',
  'No matching medicine name was found in the local medicine list for the text in this image. Try a clearer photo with the medicine name visible.':
      'لم يتم العثور على اسم دواء مطابق في قائمة الأدوية المحلية للنص الموجود في الصورة. جرّب صورة أوضح يظهر فيها اسم الدواء.',
  'No medicine name could be read from the image. Try a clearer photo with the label visible.':
      'تعذرت قراءة اسم الدواء من الصورة. جرّب صورة أوضح يظهر فيها الملصق.',
  'No medicine name could be read from the image. Try a clearer photo with the label or pill markings visible.':
      'تعذرت قراءة اسم الدواء من الصورة. جرّب صورة أوضح يظهر فيها الملصق أو علامات الحبة.',
  'Identified from OCR text by matching the local medicine list.':
      'تم التعرف عليه من نص الصورة بمطابقته مع قائمة الأدوية المحلية.',
  'This information comes from public medication references and is not a substitute for advice from a doctor or pharmacist.':
      'تأتي هذه المعلومات من مراجع أدوية عامة ولا تغني عن نصيحة الطبيب أو الصيدلي.',
  'This is not personal medical advice.': 'هذه ليست نصيحة طبية شخصية.',
  'Talk to a clinician for personal advice.':
      'تحدث مع طبيب للحصول على نصيحة شخصية.',
  'Use as directed on the label': 'استخدمه حسب التعليمات الموجودة على الملصق.',
  'Use as directed on the label.': 'استخدمه حسب التعليمات الموجودة على الملصق.',
  'Keep tightly closed': 'احفظ العبوة مغلقة بإحكام.',
  'Store at room temperature': 'يُحفظ في درجة حرارة الغرفة.',
  'Brand name': 'اسم تجاري',
  'Generic drug': 'دواء علمي',
  'Brand drug': 'دواء تجاري',
  'Generic pack': 'عبوة علمية',
  'Brand pack': 'عبوة تجارية',
  'Alternative': 'بديل',
};
