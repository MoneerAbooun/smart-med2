import 'package:smart_med/app/localization/app_localizations.dart';

extension InteractionResultLocalizations on AppLocalizations {
  String interactionResultText(String value) {
    final text = value.trim();
    if (text.isEmpty || !isArabic) {
      return text;
    }

    return _arabicInteractionResultText[text] ??
        _localizedDynamicInteractionText(text) ??
        isolate(text);
  }

  List<String> interactionResultTexts(Iterable<String> values) {
    return values
        .map(interactionResultText)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String? _localizedDynamicInteractionText(String text) {
    final curatedMatch = RegExp(
      r'^Curated safety rule matched for (.+) and (.+)\.$',
    ).firstMatch(text);
    if (curatedMatch != null) {
      return 'تمت مطابقة قاعدة سلامة معتمدة لـ ${isolate(curatedMatch.group(1)!)} و${isolate(curatedMatch.group(2)!)}.';
    }

    final directContraindication = _valueAfter(
      text,
      'Direct contraindication mention: ',
    );
    if (directContraindication != null) {
      return 'ذُكر منع استخدام مباشر: ${isolate(directContraindication)}.';
    }

    final directInteraction = _valueAfter(
      text,
      'Direct drug-interaction mention: ',
    );
    if (directInteraction != null) {
      return 'ذُكر تداخل دوائي مباشر: ${isolate(directInteraction)}.';
    }

    final directWarning = _valueAfter(text, 'Direct warning mention: ');
    if (directWarning != null) {
      return 'ذُكر تحذير مباشر: ${isolate(directWarning)}.';
    }

    final sameRxcui = _valueAfter(
      text,
      'Both names resolved to the same RXCUI: ',
    );
    if (sameRxcui != null) {
      return 'تم ربط الاسمين بنفس رمز RXCUI: ${isolate(sameRxcui)}.';
    }

    final sameGeneric = _valueAfter(
      text,
      'Both records point to the same generic ingredient: ',
    );
    if (sameGeneric != null) {
      return 'يشير السجلان إلى نفس المكوّن العلمي: ${isolate(sameGeneric)}.';
    }

    return null;
  }
}

String? _valueAfter(String text, String prefix) {
  if (!text.startsWith(prefix)) {
    return null;
  }

  final value = text.substring(prefix.length).trim();
  return value.endsWith('.') ? value.substring(0, value.length - 1) : value;
}

const Map<String, String> _arabicInteractionResultText = <String, String>{
  'Please enter both medicine names.': 'يرجى إدخال اسمَي الدواءين.',
  'Please enter two different medicines.': 'يرجى إدخال دواءين مختلفين.',
  'Both medicine names are required': 'اسمَا الدواءين مطلوبان.',
  'One or both medicines could not be resolved in RxNorm':
      'تعذر العثور على أحد الدواءين أو كليهما في RxNorm.',
  'This combination can increase bleeding risk.':
      'قد يزيد هذا الجمع بين الدواءين من خطر النزيف.',
  'Concurrent anticoagulant and NSAID therapy can increase gastrointestinal and other bleeding.':
      'قد يؤدي استخدام مضاد تخثر مع مضاد التهاب غير ستيرويدي إلى زيادة نزيف الجهاز الهضمي وأنواع أخرى من النزيف.',
  'Watch closely for bruising, black stools, unusual bleeding, or dizziness.':
      'راقب ظهور كدمات، أو براز أسود، أو نزيف غير معتاد، أو دوخة.',
  'This combination often needs clinician review before routine use.':
      'غالبا ما يحتاج هذا الجمع إلى مراجعة الطبيب قبل الاستخدام المنتظم.',
  'Avoid self-starting this combination without clinician advice.':
      'تجنب بدء هذا الجمع من تلقاء نفسك دون نصيحة الطبيب.',
  'If it is prescribed, monitoring and a safer pain-relief plan may be needed.':
      'إذا وُصف هذا الجمع، فقد تحتاج إلى متابعة وخطة أكثر أمانا لتخفيف الألم.',
  'Using two NSAID-type pain medicines together can raise stomach, kidney, and bleeding risks.':
      'استخدام دواءين من نوع مضادات الالتهاب غير الستيرويدية معا قد يزيد مخاطر المعدة والكلى والنزيف.',
  'NSAIDs can overlap in side effects without usually adding enough benefit to justify combining them.':
      'قد تتداخل الآثار الجانبية لمضادات الالتهاب غير الستيرويدية دون فائدة كافية غالبا تبرر الجمع بينها.',
  'Stomach irritation, ulcers, kidney stress, and bleeding risk can increase.':
      'قد يزداد تهيج المعدة، والقرحات، وإجهاد الكلى، وخطر النزيف.',
  'Avoid combining two NSAIDs unless a clinician specifically instructed you to do so.':
      'تجنب الجمع بين دواءين من مضادات الالتهاب غير الستيرويدية إلا إذا طلب الطبيب ذلك صراحة.',
  'Use only one NSAID product at a time unless you have professional advice.':
      'استخدم منتجا واحدا فقط من مضادات الالتهاب غير الستيرويدية في كل مرة، إلا إذا كانت لديك نصيحة طبية.',
  'This combination can cause a dangerous drop in blood pressure.':
      'قد يسبب هذا الجمع انخفاضا خطيرا في ضغط الدم.',
  'PDE-5 inhibitors and nitrates both increase vasodilation and can cause severe hypotension together.':
      'مثبطات PDE-5 والنترات كلاهما يزيد توسع الأوعية، وقد يسببان معا انخفاضا شديدا في ضغط الدم.',
  'This is generally treated as a major contraindicated combination.':
      'يُعامل هذا الجمع عادة كمنع استخدام مهم.',
  'Do not combine these medicines unless a clinician explicitly instructs you to do so.':
      'لا تجمع بين هذين الدواءين إلا إذا طلب الطبيب ذلك صراحة.',
  'Seek urgent medical help if severe dizziness, fainting, or chest symptoms occur.':
      'اطلب مساعدة طبية عاجلة إذا ظهرت دوخة شديدة، أو إغماء، أو أعراض في الصدر.',
  'This combination can cause excessive sedation and breathing problems.':
      'قد يسبب هذا الجمع تهدئة زائدة ومشكلات في التنفس.',
  'Benzodiazepines and opioids both suppress the central nervous system and respiratory drive.':
      'كل من البنزوديازيبينات والأفيونات يثبط الجهاز العصبي المركزي ودافع التنفس.',
  'Sleepiness, confusion, slowed breathing, and overdose risk can increase.':
      'قد يزداد النعاس، والارتباك، وبطء التنفس، وخطر الجرعة الزائدة.',
  'Use only if a prescriber knows about both medicines and has decided the combination is necessary.':
      'استخدمهما معا فقط إذا كان الطبيب الواصف يعرف الدواءين وقرر أن الجمع بينهما ضروري.',
  'Avoid alcohol and other sedating medicines while taking this combination.':
      'تجنب الكحول والأدوية المهدئة الأخرى أثناء استخدام هذا الجمع.',
  'A direct contraindication mention was found in public labeling for this pair.':
      'تم العثور على ذكر مباشر لمنع الاستخدام في النشرات العامة لهذا الزوج من الأدوية.',
  'The public labeling suggests this combination should be avoided or used only with specialist guidance.':
      'تشير النشرات العامة إلى وجوب تجنب هذا الجمع أو استخدامه فقط بتوجيه مختص.',
  "One medicine appears by name in the other medicine's contraindication text.":
      'يظهر أحد الدواءين بالاسم في نص منع الاستخدام للدواء الآخر.',
  'Treat this as a high-priority clinician review before taking the two medicines together.':
      'تعامل مع هذا كحالة تحتاج مراجعة طبية ذات أولوية عالية قبل تناول الدواءين معا.',
  'A direct drug-interaction mention was found in public labeling for this pair.':
      'تم العثور على ذكر مباشر لتداخل دوائي في النشرات العامة لهذا الزوج من الأدوية.',
  'The public labeling flags a named interaction that may require caution, dose adjustment, or monitoring.':
      'تشير النشرات العامة إلى تداخل مسمى قد يتطلب الحذر، أو تعديل الجرعة، أو المتابعة.',
  "One medicine appears by name in the other medicine's interaction section.":
      'يظهر أحد الدواءين بالاسم في قسم التداخلات للدواء الآخر.',
  'Review this combination with a clinician or pharmacist before routine use.':
      'راجع هذا الجمع مع طبيب أو صيدلي قبل الاستخدام المنتظم.',
  'Follow label instructions and monitoring advice if the combination is prescribed.':
      'اتبع تعليمات النشرة ونصائح المتابعة إذا كان هذا الجمع موصوفا لك.',
  'A named warning mention was found in public labeling for this pair.':
      'تم العثور على ذكر تحذير بالاسم في النشرات العامة لهذا الزوج من الأدوية.',
  'The public labeling suggests caution with the named medicine, even if it is not framed as a formal contraindication.':
      'تشير النشرات العامة إلى ضرورة الحذر مع الدواء المذكور، حتى إذا لم يُعرض كمنع استخدام رسمي.',
  "One medicine appears by name in the other medicine's warning text.":
      'يظهر أحد الدواءين بالاسم في نص التحذيرات للدواء الآخر.',
  'Use this combination only with label-aware caution and clinician advice when needed.':
      'استخدم هذا الجمع فقط مع الحذر بناء على النشرة واستشارة الطبيب عند الحاجة.',
  'No direct pair-specific interaction signal was found in the free public sources checked for this pair.':
      'لم يتم العثور على إشارة مباشرة خاصة بهذا الزوج من الأدوية في المصادر العامة المجانية التي تم فحصها.',
  'This result comes from free public labeling sources and rule-based comparison, not from a dedicated clinical interaction database.':
      'هذه النتيجة مبنية على نشرات عامة مجانية ومقارنة قائمة على القواعد، وليست من قاعدة بيانات سريرية متخصصة للتداخلات.',
  'Absence of a signal here does not guarantee the combination is risk-free.':
      'عدم ظهور إشارة هنا لا يضمن أن الجمع بين الدواءين خال من المخاطر.',
  'Still check dose limits, overlapping ingredients, and patient-specific risks such as pregnancy, kidney disease, liver disease, and allergies.':
      'مع ذلك تحقق من حدود الجرعة، والمكونات المتداخلة، والمخاطر الخاصة بالمريض مثل الحمل، وأمراض الكلى، وأمراض الكبد، والحساسيات.',
  'Escalate to a clinician or pharmacist for uncertain or high-risk cases.':
      'استشر طبيبا أو صيدليا في الحالات غير الواضحة أو عالية الخطورة.',
  'No direct pair-specific name match was found in contraindications, interaction sections, or warnings from the public labels reviewed.':
      'لم يتم العثور على تطابق مباشر بالاسم لهذا الزوج في موانع الاستخدام أو أقسام التداخلات أو التحذيرات في النشرات العامة التي تمت مراجعتها.',
  'Interaction analysis could not be completed from the available public records.':
      'تعذر إكمال تحليل التداخل من السجلات العامة المتاحة.',
  'At least one drug did not return enough public labeling data for a meaningful free-source comparison.':
      'لم يرجع أحد الدواءين على الأقل بيانات نشرات عامة كافية لإجراء مقارنة مفيدة من المصادر المجانية.',
  'This is an incomplete result rather than a clean negative interaction check.':
      'هذه نتيجة غير مكتملة وليست فحصا سلبيا واضحا للتداخل.',
  'Try a more specific drug name or use a clinician/pharmacist review for safety-critical decisions.':
      'جرّب اسم دواء أكثر تحديدا أو راجع طبيبا أو صيدليا للقرارات المهمة المتعلقة بالسلامة.',
  'Public labeling data was incomplete for at least one of the queried medicines.':
      'كانت بيانات النشرات العامة غير مكتملة لأحد الدواءين المطلوبين على الأقل.',
  'These medicines appear to refer to the same or equivalent active medicine. Taking both may duplicate therapy and increase overdose or side-effect risk.':
      'يبدو أن هذين الاسمين يشيران إلى نفس الدواء الفعّال أو دواء مكافئ. تناولهما معا قد يكرر العلاج ويزيد خطر الجرعة الزائدة أو الآثار الجانبية.',
  'The two names resolved to the same normalized medicine or to the same generic ingredient in the public drug sources checked.':
      'تم ربط الاسمين بنفس الدواء الموحّد أو بنفس المكوّن العلمي في مصادر الأدوية العامة التي تم فحصها.',
  'Using two names for the same medicine can accidentally double the dose.':
      'استخدام اسمين لنفس الدواء قد يضاعف الجرعة بالخطأ.',
  'Do not combine them unless a clinician clearly confirmed they are meant to be taken together.':
      'لا تجمع بينهما إلا إذا أكد الطبيب بوضوح أنهما مقصودان للاستخدام معا.',
  'Check the active ingredient and total daily dose carefully.':
      'تحقق بعناية من المكوّن الفعّال والجرعة اليومية الكلية.',
  'No direct pair-specific interaction signal found.':
      'لم يتم العثور على إشارة تداخل مباشرة خاصة بهذا الزوج.',
  'Still check dose limits.': 'مع ذلك تحقق من حدود الجرعة.',
  'Ask a pharmacist if unsure.': 'اسأل صيدليا إذا لم تكن متأكدا.',
  'Public labels checked.': 'تم فحص النشرات العامة.',
  'Watch for unusual bleeding.': 'راقب أي نزيف غير معتاد.',
  'Review this combination with a clinician.': 'راجع هذا الجمع مع طبيب.',
  'Concurrent anticoagulant and NSAID therapy can increase bleeding.':
      'قد يؤدي استخدام مضاد تخثر مع مضاد التهاب غير ستيرويدي إلى زيادة النزيف.',
  'Curated safety rule matched.': 'تمت مطابقة قاعدة سلامة معتمدة.',
};
