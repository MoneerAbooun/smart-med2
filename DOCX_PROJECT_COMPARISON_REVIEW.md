# Smart Med DOCX vs Project Review

Date: 2026-06-12

Reviewed document: `An_AI_Driven_Mobile_Application_for_Smart_Medication_Analysis_and.docx`

Reviewed project areas:
- Flutter app: `smart_med/`
- FastAPI backend: `smart_med_api/`
- Firebase rules, local JSON data, ML model files, repositories, tests, and API routes

Verification run:
- `flutter test --no-pub` in `smart_med/`: 71 tests passed.
- `python -m pytest` in `smart_med_api/`: 11 tests passed. Only warning was a pytest cache warning.

## Overall Verdict

The DOCX is mostly aligned with the real project. It correctly describes the core system as a Flutter mobile application with Firebase Authentication, Cloud Firestore, FastAPI backend services, OCR-based image recognition, local medicine matching, ML-based drug-name prediction/normalization, interaction checking, reminders, profile-based safety warnings, and alternative medication suggestions.

The biggest edits needed are not about the whole idea being wrong. The main problems are precision and evidence: the Firestore schema is simplified compared with the real code, the testing section is too general, the interaction checker should be described as rule/label-data based rather than a full clinical DDI engine, and several implemented app features are missing from the document.

## What Looks Good

1. The main project scope is accurate.
   - The DOCX correctly covers medication search, image scanning, OCR, drug details, drug-drug interaction checking, medication list management, reminders, profile management, allergy and condition warnings, and alternatives.

2. The document correctly avoids an important overclaim.
   - It repeatedly says that the project does not include a standalone drug-disease interaction checker.
   - This matches the code: safety checks happen during the medication adding workflow through `MedicationSafetyAssessmentService`.

3. The technology stack is mostly correct.
   - Flutter and Dart are used for the app.
   - Firebase Authentication is used for sign in/sign up.
   - Cloud Firestore is used for user data.
   - FastAPI provides backend routes for medicine information, drug details, alternatives, interactions, uploads, and ML prediction.
   - Google ML Kit Text Recognition is used for OCR.
   - `scikit-learn` and `joblib` are used for the drug-name model.

4. The medical safety tone is good.
   - The DOCX states that the app is assistive and does not replace doctors or pharmacists.
   - This is important and should stay.

5. The limitations and future work are generally honest.
   - Limited datasets, OCR accuracy, no standalone drug-disease checker, and need for real-user testing are all valid limitations.

6. The document includes useful design material.
   - Use cases, sequence/activity diagrams, Firestore model diagrams, prototype screens, final screens, and code screenshots are all suitable for a graduation project report.

## High Priority Edits Needed

### 1. Fix duplicated headings and captions

The extracted DOCX text shows repeated chapter headings:
- Paragraphs 124 and 125: `Chapter 1: Introduction`
- Paragraphs 175 and 176: `Chapter 2: Software Development Model`
- Paragraphs 366 and 367: `Chapter 3: System Design`
- Paragraphs 613 and 614: `Chapter 4: System Implementation and Testing`
- Paragraphs 676 and 677: `Chapter 5: Results and Discussion`

It also shows a duplicated caption:
- Paragraphs 666 and 667: `Figure 28: Profile-Based Medication Safety Warning Code`

Recommended edit:
- Remove the duplicate heading/caption paragraphs.
- Update the Table of Contents, List of Tables, and List of Figures after removing them.

### 2. Make the Firestore database design match the real schema

The DOCX Firestore section is directionally correct, but too simplified.

Real code includes these important paths:
- `users/{userId}`
- `users/{userId}/medications/{medicationId}`
- `users/{userId}/medication_history/{historyId}`
- `users/{userId}/reminders/{reminderId}`
- `users/{userId}/allergies/{allergyId}`
- `users/{userId}/medical_conditions/{conditionId}`
- `users/{userId}/interaction_history/{historyId}`
- `drug_catalog/{drugId}`
- `drug_catalog/{drugId}/alternatives/{alternativeId}`
- `drug_interactions/{pairKey}` in code, but current Firestore rules do not allow top-level access to it.

What to fix in the DOCX:
- Add `medication_history`; it is used for taken/skipped dose history.
- Update `users/{userId}` fields. The real profile model includes `displayName`, `photoUrl`, `biologicalSex`, `weightKg`, `heightCm`, `systolicPressure`, `diastolicPressure`, `bloodGlucose`, `isPregnant`, `isBreastfeeding`, `allergyNames`, `medicalConditionNames`, and `hasCompletedQuickProfileSetup`.
- Update medication fields. The real medication model uses detailed fields such as `medicineId`, `genericName`, `brandName`, `activeIngredients`, `strength`, `doseAmount`, `doseUnit`, `frequencyPerDay`, `scheduledTimes`, `startDate`, `endDate`, `instructions`, `imageUrl`, `remindersEnabled`, `safetyWarningsAcknowledged`, `safetyWarningCount`, and `notificationIds`.
- Update reminder fields. The real reminder model stores `slotIndex`, `hour`, `minute`, `repeatDays`, `timezone`, `startDate`, `nextTriggerAt`, `lastTriggeredAt`, and `notificationId`, not just `reminderTime` and `repeatType`.
- Explain `drug_interactions` carefully. The Flutter app has a repository for saving shared interaction records, but current Firestore rules do not define read/write access for `drug_interactions`. The app catches persistence failures and still shows the live API result. So either update the rules or describe this collection as optional/planned/admin-controlled cache storage.

### 3. Improve the testing section

The DOCX testing section is too broad and does not show the real strength of the project.

Actual test coverage found:
- 20 Flutter test files.
- 70 Dart test cases by `rg`, with `flutter test --no-pub` reporting 71 passed.
- 6 backend pytest files.
- 11 backend tests passed.

Important tested areas:
- Alternative result filtering.
- Home medication status and schedule logic.
- Interaction result localization.
- Medication safety assessment logic.
- Medication safety localization.
- Medication schedule time parsing, including Arabic AM/PM markers and Arabic-Indic digits.
- Medicine result localization.
- Notification preferences and notification ID generation.
- Onboarding preferences.
- Drug catalog repository.
- Drug interaction lookup and Firestore interaction repository.
- Medication dose history repository.
- Medication repository.
- Medicine lookup repository, including OCR/local matching behavior.
- Profile repository.
- Reminder repository.
- Medication image autofill service.
- Backend config loading.
- Backend medicine information route/service.
- Backend ML route.
- Backend RxNorm matching helpers.
- Backend drug alternatives route.

Recommended edit:
- Replace the generic testing paragraphs with a table containing: test area, tested file/example, expected result, and status.
- Keep persona-based evaluation, but label it as internal/persona evaluation, not real user usability testing.
- Add that full real-user testing, full device/screen-size testing, and live external API reliability testing remain future work or manual checks.

### 4. Be more precise about the interaction checker

The DOCX should not imply that Smart Med uses a full clinical drug interaction database or ML model for DDI prediction.

What the backend really does:
- Resolves names through RxNorm.
- Retrieves DailyMed SPL metadata.
- Uses openFDA label sections.
- Compares contraindication, drug interaction, and warning text.
- Applies a small curated rule list for known risk groups such as warfarin plus NSAIDs, duplicate NSAIDs, nitrates plus PDE-5 inhibitors, and benzodiazepines plus opioids.
- Returns severity, summary, mechanism, warnings, recommendations, evidence, and source.

Recommended wording:
- Use: "rule-based and public-label-based interaction analysis using RxNorm, DailyMed, openFDA, and curated safety rules."
- Avoid: "machine-learning-based DDI prediction" when describing the implemented Smart Med feature.
- Keep ML DDI papers in related work, but make clear they motivate the domain rather than describe the implemented DDI algorithm.

### 5. Clarify the AI/ML claim

The project has real AI/ML-related components, but the DOCX should be specific.

Implemented:
- OCR through Google ML Kit Text Recognition.
- Local medicine-name matching.
- A trained `scikit-learn` pipeline using TF-IDF character n-grams and Logistic Regression for generic-name prediction/normalization.
- The ML model is loaded from `smart_med_api/models/drug_name_model.joblib`.
- Training data has 302 rows in `smart_med_api/data/drug_name_training.csv`.

Limitations to mention:
- The OCR reader uses `TextRecognitionScript.latin`, so image recognition is mainly for Latin-script medicine labels.
- The local medicine list has 151 records.
- The disease list has 41 records.
- The ML model supports name normalization, not medical diagnosis or full safety reasoning.

Recommended wording:
- "AI-assisted" or "AI-supported" is safer than implying every safety decision is generated by AI.
- Keep the title if required, but qualify the implementation in the abstract and Chapter 4.

### 6. Clarify alternative medication suggestions

The DOCX says the system suggests alternative medications when available. That is true, but the mechanism should be described carefully.

Actual implementation:
- Alternatives come from RxNorm related concepts and the medicine information result.
- The app filters out same-medicine/dose-variant alternatives.
- The app may add a generic option when the user searched by brand.

Recommended wording:
- Use "related medication options or possible substitutes to discuss with a doctor/pharmacist."
- Avoid wording that sounds like the system guarantees therapeutic equivalence or recommends switching treatment.

### 7. Add implemented features that are missing or under-described

The code includes useful features that the DOCX barely mentions:
- Onboarding and quick profile setup.
- Safety profile readiness on the home screen.
- Next-dose card.
- Today/tomorrow dose timeline.
- Taken/skipped dose history.
- Snooze action for due doses.
- Patient medication interaction checker: compare a new medicine against one saved medication.
- Profile photo upload.
- Medication image upload and saved image URL.
- Settings for dark mode, notifications, language, about/contact/help/version.
- Notification preference syncing on auth changes.
- Local recent search history.
- API image upload endpoints protected with Firebase ID tokens.

Recommended edit:
- Add a short paragraph in Chapter 4.2 or Chapter 5 describing these as final implementation enhancements.
- Add `medication_history` to the Firestore model and testing section.

### 8. Clarify image storage/upload architecture

The current app does not upload profile/medication photos directly to Firebase Storage through the Flutter Firebase Storage SDK.

Actual implementation:
- Flutter calls FastAPI multipart endpoints:
  - `/api/uploads/profile-image`
  - `/api/uploads/medication-image`
- The backend verifies the Firebase ID token.
- Images are saved under the backend `uploads/` directory and served through the mounted `/uploads` path.

Recommended edit:
- If the DOCX mentions image upload/storage, say "FastAPI-authorized image upload using Firebase Authentication tokens."
- Avoid saying image files are stored in Cloud Firestore.
- Avoid saying Firebase Storage is the active storage layer unless the implementation is changed.

## Medium Priority Edits

### 9. Tighten non-functional requirements

Some non-functional requirements are valid goals but not measured in the project.

Recommended edits:
- Performance: say "designed for reasonable response time" unless you include measured timings.
- Security: say Firebase Auth and Firestore rules protect user-owned records, but do not claim full medical-grade compliance.
- Privacy: say user data is separated under authenticated user paths; avoid HIPAA-style claims unless audited.
- Compatibility: say the project focuses on Android/mobile usage. OCR from photos is Android/iOS only in code.
- Scalability: say the architecture can support expansion, not that scalability has been load-tested.

### 10. Improve references and source attribution

The reference list includes good sources, but it should be polished.

Recommended edits:
- Add access dates if your university format requires them.
- Make capitalization consistent: Flutter, Firebase, FastAPI, Google ML Kit, openFDA, RxNorm, DailyMed.
- Ensure every source cited in text appears in the references and vice versa.
- Add direct references for DailyMed/openFDA/RxNorm if the implementation relies on them in Chapter 4.

### 11. Fix wording and grammar

Suggested cleanup:
- "Table Of Contents" -> "Table of Contents"
- "Result" -> "Results"
- "Limitation" -> "Limitations"
- "The Medication List screen allow users" -> "The Medication List screen allows users"
- "No SQL database" -> "No relational SQL database"
- "Use-Case" vs "Use Case": choose one style and use it consistently.
- "Drug-Drug" and "drug-drug": use one style consistently.
- "doctor or pharmacist" wording should appear near alternative suggestions and interaction results.

### 12. Update implementation screenshots if needed

Because the code has changed beyond the simplified DOCX description, make sure screenshots/code figures show current files:
- `lib/main.dart`
- `lib/app/main_app.dart`
- `lib/features/auth/data/repositories/auth_repository.dart`
- `lib/features/reminders/data/reminder_repository.dart`
- `lib/features/medicine_search/data/services/medicine_image_text_recognizer.dart`
- `lib/features/medicine_search/data/repositories/medicine_lookup_repository.dart`
- `lib/features/interactions/data/drug_interaction_lookup_repository.dart`
- `lib/features/medications/data/services/medication_safety_assessment_service.dart`
- `smart_med_api/app/main.py`
- `smart_med_api/app/routers/drug_interaction.py`
- `smart_med_api/app/services/medicine_information_service.py`

## Feature-by-Feature Comparison

| Area | DOCX status | Project status | Edit needed |
| --- | --- | --- | --- |
| Authentication | Mostly accurate | Firebase email/password auth, password reset, account/profile bootstrap | Mention password reset if desired |
| Profile | Accurate but simplified | Stores profile, allergies, conditions, vitals, pregnancy/breastfeeding, profile photo | Expand schema and implementation text |
| Onboarding | Under-described | Onboarding and quick profile setup exist | Add to implementation/results |
| Medicine search | Accurate | Name search, local matching, backend medicine info | Add exact route `/medicine-information` |
| OCR image search | Accurate but broad | Google ML Kit Latin OCR, local candidate parsing/matching | Clarify Latin-script limitation |
| ML model | Mostly accurate | `scikit-learn` drug-name prediction/normalization only | Do not imply ML DDI prediction |
| Drug details | Accurate | RxNorm, DailyMed, openFDA data sections | Mention exact sources |
| Interactions | Needs precision | Public-label and curated-rule heuristic, not clinical DDI DB | Rewrite interaction algorithm description |
| Saved-med interaction check | Missing | App can compare a new medicine against a saved medication | Add as implemented feature |
| Medication list | Accurate but simplified | Detailed dosage, schedule, photo, warning acknowledgement, status | Expand fields |
| Reminders | Accurate but simplified | Local notifications, timezone support, notification IDs, auth-change sync | Expand implementation/testing |
| Dose history | Missing | Taken/skipped history and scheduled window repository exist | Add to Firestore model and results |
| Alternatives | Accurate but needs safety wording | RxNorm related concepts plus filtering | Say "options to discuss," not direct substitution advice |
| Image upload | Missing/unclear | FastAPI upload endpoints with Firebase token verification | Add architecture note |
| Localization | Accurate | English and Arabic UI support | Mention OCR is not Arabic OCR |
| Testing | Too generic | 71 Flutter tests and 11 backend tests passed | Add concrete test table |
| Security rules | Partly accurate | User subcollections protected; catalog admin-only; no rule for top-level `drug_interactions` | Fix rules or adjust DOCX wording |

## Suggested Replacement Paragraphs

Use these as safe replacement text where the DOCX currently sounds too broad.

Interaction checker:

> The implemented interaction feature resolves medication names using RxNorm, retrieves public medication label information through DailyMed and openFDA, and applies rule-based comparison with selected curated safety rules. The result includes severity, summary, warnings, recommendations, mechanism, evidence, and source information when available. This feature is an assistive safety-awareness tool and does not replace a clinical drug interaction database or professional review.

ML support:

> Machine learning support in Smart Med is used for drug-name prediction and normalization. The backend loads a trained scikit-learn model based on TF-IDF character n-grams and Logistic Regression. The model helps map noisy, brand, or misspelled input to a generic drug name when the confidence is sufficient.

Alternative medicines:

> Alternative medication suggestions are generated from related RxNorm concepts and filtered to remove duplicate dose/form variants where possible. These suggestions are shown as possible options to discuss with a doctor or pharmacist, not as automatic replacement recommendations.

Testing:

> Automated testing was performed for both the Flutter application and the FastAPI backend. The Flutter test suite passed 71 tests covering repositories, medication safety assessment, OCR/local matching behavior, reminders, dose history, localization, and UI startup. The backend pytest suite passed 11 tests covering configuration, RxNorm helpers, ML prediction route, medicine information service/route, and drug alternative route behavior. Additional manual and real-user usability testing is recommended for future work.

## Final Recommendation

The DOCX is usable and close to the actual project, but it should be revised before submission. Focus first on:

1. Removing duplicate headings/captions and updating generated lists.
2. Correcting the Firestore schema and security description.
3. Rewriting the testing section with real test evidence.
4. Clarifying that interaction analysis is public-label/rule-based, while ML is for drug-name normalization.
5. Adding under-documented implemented features such as onboarding, dose history, saved-med interaction checking, photo uploads, notification syncing, and safety profile readiness.

After those edits, the document will represent the codebase much more accurately and will sound stronger academically because it will be specific instead of overgeneral.
