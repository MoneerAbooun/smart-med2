# DOCX Accuracy-First Edit Change Note

Edited copy:
`An_AI_Driven_Mobile_Application_for_Smart_Medication_Analysis_and_review_aligned.docx`

Original kept unchanged:
`An_AI_Driven_Mobile_Application_for_Smart_Medication_Analysis_and.docx`

## Changed Sections

- Fixed duplicated chapter heading text and the duplicated Figure 28 caption.
- Corrected generated/document wording such as `Table of Contents`, `Results`, `Limitations`, `Use Case`, `No relational SQL database`, and consistent `drug-drug` wording.
- Updated Chapter 3 Firestore design to include the real profile, medication, reminder, medication history, interaction history, drug catalog, alternatives, and optional/shared `drug_interactions` behavior.
- Updated Chapter 4 implementation text for protected FastAPI image uploads, Google ML Kit OCR scope, scikit-learn drug-name normalization, public-label/rule-based interaction analysis, onboarding, dose history, snooze, profile photo upload, settings, recent search history, and saved-medication interaction checking.
- Replaced the generic Chapter 4.5 testing text with a concrete automated testing table covering Flutter and FastAPI test areas.
- Updated Chapter 5 results/discussion and persona evaluation wording to keep the medical safety tone assistive and accurate.

## Verification

- `flutter test --no-pub` in `smart_med/`: 71 tests passed.
- `python -m pytest` in `smart_med_api/`: 11 tests passed, with only the existing pytest cache warning.
- Edited DOCX XML was searched for repeated heading/caption text and old inconsistent terms.
- The DOCX settings were marked with `updateFields=true` so Word can refresh generated lists on open.

## Manual Follow-Up

- Open the edited DOCX in Microsoft Word and update fields if prompted.
- Confirm the Table of Contents, List of Tables, and List of Figures page numbers after Word recalculates layout.
