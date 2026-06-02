import 'package:shared_preferences/shared_preferences.dart';

class AiPreferences {
  const AiPreferences({
    required this.simpleLanguageMode,
    required this.showSaferUseTips,
    required this.showQuestionsForClinician,
    required this.showEvidenceByDefault,
  });

  final bool simpleLanguageMode;
  final bool showSaferUseTips;
  final bool showQuestionsForClinician;
  final bool showEvidenceByDefault;
}

class AiPreferencesRepository {
  static const String _simpleLanguageKey = 'ai.simple_language_mode';
  static const String _showSaferUseTipsKey = 'ai.show_safer_use_tips';
  static const String _showQuestionsKey = 'ai.show_questions_for_clinician';
  static const String _showEvidenceKey = 'ai.show_evidence_by_default';

  Future<AiPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return AiPreferences(
      simpleLanguageMode: prefs.getBool(_simpleLanguageKey) ?? true,
      showSaferUseTips: prefs.getBool(_showSaferUseTipsKey) ?? true,
      showQuestionsForClinician: prefs.getBool(_showQuestionsKey) ?? true,
      showEvidenceByDefault: prefs.getBool(_showEvidenceKey) ?? false,
    );
  }

  Future<void> setSimpleLanguageMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_simpleLanguageKey, value);
  }

  Future<void> setShowSaferUseTips(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSaferUseTipsKey, value);
  }

  Future<void> setShowQuestionsForClinician(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showQuestionsKey, value);
  }

  Future<void> setShowEvidenceByDefault(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showEvidenceKey, value);
  }
}

final AiPreferencesRepository aiPreferencesRepository =
    AiPreferencesRepository();
