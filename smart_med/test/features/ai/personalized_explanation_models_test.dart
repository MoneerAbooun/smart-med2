import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med/features/ai/domain/models/personalized_explanation_models.dart';

void main() {
  test('PersonalizedExplanationResponse parses extended safety fields', () {
    final response = PersonalizedExplanationResponse.fromMap({
      'generated_at': '2026-04-23T10:15:00Z',
      'source': 'firestore+openai',
      'model': 'gpt-5.4-mini',
      'prompt_version': 'grounded-firestore-v2',
      'grounded_only': false,
      'quick_summary': 'You have 1 interaction alert and 2 profile-based cautions.',
      'overall_severity': 'Moderate',
      'caution_count': 2,
      'interaction_count': 1,
      'safer_behavior_tips': [
        'Take with food if your stomach feels irritated.',
      ],
      'medication_badges': [
        {
          'medication_id': 'med-1',
          'label': '1 caution',
          'severity': 'Moderate',
        },
      ],
      'profile_completeness': {
        'is_complete': false,
        'missing_fields': ['blood_pressure'],
        'summary': 'Some AI safety checks are limited.',
      },
      'overview': 'Overview text',
      'medication_explanations': [
        {
          'medication_id': 'med-1',
          'name': 'Ibuprofen',
          'generic_name': 'Ibuprofen',
          'explanation': 'Helps reduce pain and swelling.',
          'source_ids': ['medication:med-1'],
        },
      ],
      'interaction_alerts': [
        {
          'severity': 'Moderate',
          'title': 'Interaction alert',
          'detail': 'Interaction detail',
          'source_ids': ['interaction:abc'],
        },
      ],
      'personalized_risks': [
        {
          'severity': 'High',
          'title': 'Profile risk',
          'detail': 'Risk detail',
          'source_ids': ['profile'],
        },
      ],
      'questions_for_clinician': ['Should I ask about this combination?'],
      'missing_information': ['Blood pressure is missing.'],
      'evidence': [
        {
          'id': 'profile',
          'source_type': 'profile',
          'title': 'User profile',
          'detail': 'Profile detail',
        },
      ],
    });

    expect(response.quickSummary, contains('1 interaction alert'));
    expect(response.overallSeverity, 'Moderate');
    expect(response.cautionCount, 2);
    expect(response.interactionCount, 1);
    expect(response.saferBehaviorTips, hasLength(1));
    expect(response.medicationBadges.single.label, '1 caution');
    expect(response.profileCompleteness.isComplete, isFalse);
    expect(response.profileCompleteness.missingFields, ['blood_pressure']);
  });
}
