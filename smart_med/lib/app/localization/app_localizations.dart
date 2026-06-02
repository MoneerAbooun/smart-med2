import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  bool get isArabic => locale.languageCode == 'ar';

  String text(String key) {
    final values = isArabic ? _ar : _en;
    return values[key] ?? _en[key] ?? key;
  }

  String format(String key, Map<String, String> values) {
    var message = text(key);
    values.forEach((name, value) {
      message = message.replaceAll('{$name}', value);
    });
    return message;
  }

  String isolate(String value) {
    if (!isArabic || value.isEmpty) {
      return value;
    }

    return '\u2068$value\u2069';
  }

  String severity(String value) {
    final normalized = value.trim().toLowerCase();
    final key = switch (normalized) {
      'high' || 'major' || 'severe' => 'severity.high',
      'moderate' => 'severity.moderate',
      'low' => 'severity.low',
      'none' || 'no interaction' || 'no known interaction' => 'severity.none',
      'info' || 'information' => 'severity.info',
      'unknown' => 'severity.unknown',
      _ => null,
    };

    return key == null ? isolate(value) : text(key);
  }

  static const Map<String, String> _en = <String, String>{
    'app.name': 'Smart Med',
    'nav.home': 'Home',
    'nav.profile': 'Profile',
    'nav.settings': 'Settings',
    'common.ok': 'OK',
    'common.cancel': 'Cancel',
    'common.signOut': 'Sign out',
    'common.retry': 'Retry',
    'common.addMedicine': 'Add medicine',
    'common.medications': 'Medications',
    'common.search': 'Search',
    'common.clear': 'Clear',
    'common.camera': 'Camera',
    'common.gallery': 'Gallery',
    'common.viewAll': 'View All',
    'common.change': 'Change',
    'common.delete': 'Delete',
    'common.saveChanges': 'Save changes',
    'common.addPhoto': 'Add photo',
    'common.changePhoto': 'Change photo',
    'common.resetPhoto': 'Reset photo',
    'common.noPhotoSelected': 'No photo selected',
    'common.noImageSelected': 'No image selected',
    'common.useName': 'Use name',
    'common.usePhoto': 'Use photo',
    'common.useNameSearch': 'Use name search',
    'common.usePhotoSearch': 'Use photo search',
    'common.searching': 'Searching...',
    'common.checking': 'Checking...',
    'common.wait': 'Wait...',
    'common.capture': 'Capture',
    'common.recentSearches': 'Recent searches',
    'common.suggestions': 'Suggestions',
    'common.medicineName': 'Medicine name',
    'common.exampleIbuprofen': 'Example: ibuprofen',
    'common.brand': 'Brand',
    'common.generic': 'Generic',
    'common.activeIngredients': 'Active ingredients',
    'common.strength': 'Strength',
    'common.form': 'Form',
    'common.selected': 'selected',
    'common.unknownMedicine': 'Unknown medicine',
    'common.notAvailable': 'Not available',
    'common.oneItem': '1 item',
    'common.itemCount': '{count} items',
    'common.goBack': 'Go back',
    'severity.high': 'High',
    'severity.moderate': 'Moderate',
    'severity.low': 'Low',
    'severity.none': 'None',
    'severity.info': 'Info',
    'severity.unknown': 'Unknown',
    'common.english': 'English',
    'common.arabic': 'Arabic',
    'gate.loadingProfile': 'Getting your profile ready...',
    'gate.loadingTools': 'Loading your Smart Med tools...',
    'gate.profileError.title': 'We could not finish loading your profile.',
    'gate.profileError.retry':
        'Please retry. If this keeps happening, sign out and try again later.',
    'onboarding.title': 'Smart Med tour',
    'onboarding.skip': 'Skip',
    'onboarding.next': 'Next',
    'onboarding.getStarted': 'Get started',
    'onboarding.step': 'Step {current} of {total}',
    'onboarding.step.add.title': 'Add medicines quickly',
    'onboarding.step.add.description':
        'Save a medicine, add a photo when helpful, and keep the details in one place.',
    'onboarding.step.interactions.title': 'Check interactions',
    'onboarding.step.interactions.description':
        'Compare medicines before taking them together and review possible warnings early.',
    'onboarding.step.profile.title': 'Prepare your profile',
    'onboarding.step.profile.description':
        'Add health details, conditions, allergies, and current medicines so Smart Med can personalize safety checks.',
    'onboarding.step.photo.title': 'Search by photo',
    'onboarding.step.photo.description':
        'Use the camera or gallery to search from medicine packaging, labels, or pills when typing is inconvenient.',
    'onboarding.step.reminders.title': 'Get reminders',
    'onboarding.step.reminders.description':
        'Add reminder times while saving medicines so Smart Med can help you stay on schedule.',
    'settings.title': 'Settings',
    'settings.editProfile': 'Edit profile',
    'settings.darkMode': 'Dark mode',
    'settings.notifications': 'Notifications',
    'settings.language': 'Language',
    'settings.about': 'About Smart Med',
    'settings.about.body':
        'Smart Med helps you manage medicines, reminders, interaction checks, and medicine information in one place.',
    'settings.contact': 'Contact',
    'settings.contact.body': 'Email: smartmed@app.com\nPhone: +000 000 000 000',
    'settings.help': 'Help',
    'settings.help.body':
        'Help and frequently asked questions will be available in a future update.',
    'settings.version': 'App version',
    'settings.version.body': 'Smart Med v1.0.0',
    'settings.notifications.blocked':
        'Notifications are blocked. You can enable them in device settings.',
    'settings.notifications.ready': 'Reminder notifications are ready.',
    'settings.notifications.on':
        'Notifications are on. Your reminders were synced.',
    'settings.notifications.off':
        'Notifications are off. Reminder alerts were cleared.',
    'settings.signOut.title': 'Sign out?',
    'settings.signOut.body': 'You can sign in again anytime.',
    'auth.welcomeBack': 'Welcome back',
    'auth.signIn.subtitle': 'Sign in to manage your medicines and reminders.',
    'auth.email': 'Email',
    'auth.password': 'Password',
    'auth.emailHint': 'you@example.com',
    'auth.passwordHint': 'Your password',
    'auth.signIn': 'Sign in',
    'auth.forgotPassword': 'Forgot password?',
    'auth.createAccountPrompt': 'New to Smart Med? Create an account',
    'auth.createAccount': 'Create account',
    'auth.signup.subtitle': 'Create an account so your medicines stay saved.',
    'auth.fullName': 'Full name *',
    'auth.fullNameHint': 'Your full name',
    'auth.age': 'Age *',
    'auth.ageHint': 'Your age',
    'auth.passwordCreateHint': 'At least 6 characters',
    'auth.validation.emailPasswordRequired':
        'Please enter your email and password.',
    'auth.validation.validEmail': 'Please enter a valid email address.',
    'auth.validation.emailRequired': 'Please enter your email address.',
    'auth.validation.emailFirst': 'Enter your email address first.',
    'auth.validation.nameRequired': 'Please enter your full name.',
    'auth.validation.ageRequired': 'Please enter your age.',
    'auth.validation.ageNumber': 'Age must be a number.',
    'auth.validation.ageRange': 'Please enter an age between 1 and 120.',
    'auth.validation.passwordRequired': 'Please enter a password.',
    'auth.validation.passwordLength':
        'Use at least 6 characters for your password.',
    'auth.signIn.success': 'You are signed in.',
    'auth.signIn.invalidCredentials':
        'That email or password did not match. Please try again.',
    'auth.signIn.error': 'We could not sign you in. Please try again.',
    'auth.signIn.unexpected':
        'Something went wrong while signing in. Please try again.',
    'auth.reset.sent': 'Password reset email sent. Check your inbox.',
    'auth.reset.error': 'We could not send the reset email.',
    'auth.reset.unexpected': 'Something went wrong while sending the email.',
    'auth.signup.success': 'Your account is ready.',
    'auth.signup.error': 'We could not create your account.',
    'auth.signup.unexpected':
        'Something went wrong while creating your account.',
    'home.greeting.title': 'Hello, {name}',
    'home.greeting.fallback': 'there',
    'home.greeting.subtitle': 'Here is what needs your attention today.',
    'home.action.details': 'Medicine Details',
    'home.action.details.subtitle': 'Search by name or photo',
    'home.action.details.tooltip':
        'Find medicine details by name or image, then review key information before you take it.',
    'home.action.interactions': 'Check Interactions',
    'home.action.interactions.subtitle': 'Compare two medicines',
    'home.action.interactions.tooltip':
        'Compare medicines to catch interaction warnings and safety risks before combining them.',
    'home.action.medicines': 'My Medicines',
    'home.action.medicines.subtitle': 'Review saved medicines',
    'home.action.medicines.tooltip':
        'Open your current medication list to review details, reminders, and any edits you need to make.',
    'home.action.substitutes': 'Possible Substitutes',
    'home.action.substitutes.subtitle': 'Options to discuss',
    'home.action.substitutes.tooltip':
        'Search for related medicines you can discuss with a doctor or pharmacist before changing treatment.',
    'home.camera.openError': 'We could not open the camera. {error}',
    'home.camera.captureError': 'We could not capture the image. {error}',
    'home.schedule.loading': 'Loading today\'s medicine schedule...',
    'home.noMedicines.title': 'No medicines yet',
    'home.noMedicines.body':
        'Add your first medicine to see the next dose here.',
    'home.noDoses.title': 'No more doses today',
    'home.noDoses.body':
        'You are clear for the rest of today based on your current schedule.',
    'home.nextDose.title': 'Next dose',
    'home.dose.detail': '{dosage} at {time}',
    'home.dose.snoozed': 'Snoozed',
    'home.dose.overdue': 'Overdue',
    'home.dose.today': 'Today',
    'home.dose.tomorrow': 'Tomorrow',
    'home.dose.taken': 'Taken',
    'home.dose.snooze': 'Snooze',
    'home.dose.skip': 'Skip',
    'home.dose.markedTaken': '{medicine} marked as taken.',
    'home.dose.markedSkipped': '{medicine} marked as skipped.',
    'home.dose.snoozedUntil': '{medicine} snoozed until {time}.',
    'home.safety.missing.age': 'Age',
    'home.safety.missing.weight': 'Weight',
    'home.safety.missing.bloodPressure': 'Blood pressure',
    'home.safety.missing.saveSetup': 'Save setup',
    'home.safety.title': 'Safety status',
    'home.safety.loading': 'Loading your safety profile...',
    'home.safety.complete':
        'Your safety profile has the key details needed for better checks.',
    'home.safety.incomplete':
        'Profile {completed}/{total} complete. Add the missing details, or save setup if none apply.',
    'home.safety.summary':
        '{allergies} allergies, {conditions} conditions, {medicines} active medicines',
    'home.safety.checkMedicines': 'Check medicines',
    'home.safety.finishProfile': 'Finish profile',
    'home.quickStart.title': 'Quick start',
    'home.quickStart.scanPhoto': 'Scan photo',
    'home.today.title': 'Today\'s medicines',
    'home.today.noMedicines': 'No medicines yet.',
    'home.today.noMoreScheduled': 'No more scheduled doses today.',
    'home.tools.title': 'Tools',
    'home.scan.title': 'Search by photo',
    'home.scan.body':
        'Use the camera or gallery to identify a medicine from its label or package. Then search it or add it to your list.',
    'home.scan.holdOn': 'Hold on...',
    'home.scan.capture': 'Capture',
    'home.scan.photoReady': 'Photo selected and ready.',
    'home.scan.noPhoto': 'No photo selected',
    'home.scan.placeholder': 'Use the camera or gallery to search by photo.',
    'home.auth.signInPrompt': 'Please sign in to use Smart Med.',
    'profile.title': 'Profile',
    'profile.loadError': 'We could not load your profile.',
    'profile.photo.editRequired': 'Tap edit before changing the profile photo.',
    'profile.photo.change': 'Change photo',
    'profile.photo.add': 'Add photo',
    'profile.condition.duplicate': 'This condition is already in the profile.',
    'profile.allergy.duplicate': 'This allergy is already in the profile.',
    'profile.signInAgain': 'Please sign in again.',
    'profile.validation.nameRequired': 'Please enter your name.',
    'profile.validation.ageRequired': 'Please enter your age.',
    'profile.validation.ageNumber': 'Age must be a number.',
    'profile.validation.ageRange': 'Please enter an age between 1 and 120.',
    'profile.saved': 'Profile saved.',
    'profile.saveError': 'We could not save your profile.',
    'profile.yourName': 'Your name',
    'profile.ageLabel': 'Age: ',
    'profile.saveProfile': 'Save profile',
    'profile.conditions.title': 'Health conditions',
    'profile.conditions.subtitle':
        'Add long-term conditions that may affect medicine safety.',
    'profile.conditions.hint.view': 'Tap edit to add conditions',
    'profile.conditions.hint.loading': 'Loading conditions...',
    'profile.conditions.hint.empty': 'No conditions available',
    'profile.conditions.hint.select': 'Select a condition',
    'profile.conditions.loadError': 'We could not load the condition list.',
    'profile.conditions.retry': 'Retry loading conditions',
    'profile.conditions.add': 'Add condition',
    'profile.conditions.none': 'No health conditions added',
    'profile.allergies.title': 'Drug allergies',
    'profile.allergies.subtitle':
        'Add medicines that may cause an allergic reaction.',
    'profile.allergies.hint.view': 'Tap edit to add allergies',
    'profile.allergies.hint.loading': 'Loading medicines...',
    'profile.allergies.hint.empty': 'No medicines available',
    'profile.allergies.hint.select': 'Select a medicine',
    'profile.allergies.loadError': 'We could not load the medicine list.',
    'profile.allergies.retry': 'Retry loading medicines',
    'profile.allergies.add': 'Add allergy',
    'profile.allergies.none': 'No drug allergies added',
    'profile.health.title': 'Health details',
    'profile.health.subtitle':
        'These details help Smart Med personalize safety guidance.',
    'profile.health.biologicalSex': 'Biological sex',
    'profile.health.male': 'Male',
    'profile.health.female': 'Female',
    'profile.health.weight': 'Weight (kg)',
    'profile.health.height': 'Height (cm)',
    'profile.health.bloodPressure': 'Blood pressure',
    'profile.health.bloodPressureHelp':
        'SYS is the upper number. DIA is the lower number.',
    'profile.health.systolic': 'SYS / upper',
    'profile.health.diastolic': 'DIA / lower',
    'profile.health.bloodGlucose': 'Blood glucose',
    'profile.health.pregnant': 'Pregnant',
    'profile.health.breastfeeding': 'Breastfeeding',
    'profile.readiness.age': 'Age',
    'profile.readiness.allergies': 'Allergies',
    'profile.readiness.conditions': 'Conditions',
    'profile.readiness.weight': 'Weight',
    'profile.readiness.bloodPressure': 'Blood pressure',
    'profile.readiness.pregnancyStatus': 'Pregnancy status',
    'profile.readiness.title': 'Safety profile readiness',
    'profile.readiness.complete':
        'Your profile has the key details needed for better safety guidance.',
    'profile.readiness.incomplete':
        'Missing details can make warnings less personalized. Add what you can now and update the rest later.',
    'medication.add.title': 'Add medicine',
    'medication.edit.title': 'Edit medicine',
    'medication.list.title': 'My Medications',
    'medication.signIn.view': 'Please sign in to view medications.',
    'medication.nameRequired': 'Medicine name *',
    'medication.nameHelper':
        'Start typing, then choose the correct medicine from the list.',
    'medication.selectFromList': 'Select a medicine from the list.',
    'medication.noMatch':
        'No matching medicine found. Check the spelling or try the generic name.',
    'medication.searchListError':
        'We could not search the medicine list right now.',
    'medication.photo.title': 'Medicine photo',
    'medication.photo.addSubtitle':
        'Optional. Add a clear pill, bottle, or package photo to help fill the medicine name and dose.',
    'medication.photo.editSubtitle':
        'Optional. Add or change the photo used for this medicine.',
    'medication.photo.reading':
        'Reading the photo and matching it to the medicine list...',
    'medication.photo.filledNameDose':
        'Medicine name and dose were filled from the photo. Please review them before saving.',
    'medication.photo.filledName':
        'Medicine name was filled from the photo. Please review the dose before saving.',
    'medication.photo.unavailable':
        'Photo fill is unavailable right now. You can still enter the details manually.',
    'medication.doseAmountRequired': 'Dose amount *',
    'medication.doseAmount': 'Dose amount',
    'medication.doseUnitRequired': 'Dose unit *',
    'medication.doseUnit': 'Dose unit',
    'medication.timesPerDayRequired': 'Times per day (1-6) *',
    'medication.timesPerDay': 'Times per day',
    'medication.firstReminderRequired': 'First reminder time *',
    'medication.firstReminder': 'First reminder time',
    'medication.reminderHelper':
        'Smart Med will calculate the remaining reminders.',
    'medication.reminderChoose':
        'Choose the first reminder time. Smart Med will schedule the rest every {interval}.',
    'medication.reminderTimes': 'Reminder times: {times}',
    'medication.interval.minute': '1 minute',
    'medication.interval.minutes': '{count} minutes',
    'medication.interval.hour': '1 hour',
    'medication.interval.hours': '{count} hours',
    'medication.interval.hourMinute': '{hours} {minutes}',
    'medication.startDateRequired': 'Start date *',
    'medication.startDate': 'Start date',
    'medication.finishDate': 'Finish date',
    'medication.finishDateHelper': 'Optional. Reminders stop after this date.',
    'medication.clearFinishDate': 'Clear finish date',
    'medication.notes': 'Notes',
    'medication.validation.doseRequired': 'Enter the dose amount.',
    'medication.validation.validDose': 'Enter a valid dose number.',
    'medication.validation.timesRequired': 'Enter how many times per day.',
    'medication.validation.enterNumber': 'Enter a number.',
    'medication.validation.timesRange': 'Choose a number from 1 to 6.',
    'medication.validation.maxTimes': 'The maximum is 6 times per day.',
    'medication.validation.firstReminder': 'Choose the first reminder time.',
    'medication.validation.startDate': 'Choose a start date.',
    'medication.validation.finishDate': 'Choose a valid finish date.',
    'medication.validation.finishBeforeStart':
        'Finish date cannot be before the start date.',
    'medication.validation.signInSave':
        'Please sign in before saving medicines.',
    'medication.validation.signInUpdate':
        'Please sign in again before updating this medicine.',
    'medication.saved.off': 'Medicine added. Reminders are off in Settings.',
    'medication.saved': 'Medicine added.',
    'medication.saved.partial':
        'Medicine added, but some reminders could not be scheduled.',
    'medication.saved.noReminders':
        'Medicine added, but reminders could not be scheduled.',
    'medication.updated.off':
        'Medicine updated. Reminders are off in Settings.',
    'medication.updated': 'Medicine updated.',
    'medication.updated.partial':
        'Medicine updated, but some reminders could not be scheduled.',
    'medication.updated.noReminders':
        'Medicine updated, but reminders could not be scheduled.',
    'medication.saveError': 'We could not save this medicine right now.',
    'medication.saveErrorDetail': 'We could not save this medicine. {error}',
    'medication.updateError': 'We could not update this medicine right now.',
    'medication.updateErrorDetail':
        'We could not update this medicine. {error}',
    'medication.permissionSave':
        'You do not have permission to save this medicine.',
    'medication.permissionUpdate':
        'You do not have permission to update this medicine.',
    'medication.serviceUnavailable':
        'The service is temporarily unavailable. Please try again.',
    'medication.notificationBody': 'Time to take {medicine}',
    'medication.deleteError': 'We could not delete this medication.',
    'medication.deleted': 'Medication deleted.',
    'medication.deleteTitle': 'Delete medication?',
    'medication.deleteBody':
        'This will remove {medicine} and cancel its reminders.',
    'medication.loadError': 'We could not load your medications. {error}',
    'medication.empty.title': 'No medications yet',
    'medication.empty.body':
        'Add your first medicine so reminders and safety checks can use it.',
    'medication.info.dose': 'Dose',
    'medication.info.howOften': 'How often',
    'medication.info.reminderTimes': 'Reminder times',
    'medication.info.startDate': 'Start date',
    'medication.info.finishDate': 'Finish date',
    'medication.info.notes': 'Notes',
    'medicineSearch.title': 'Medicine details',
    'medicineSearch.mode.title': 'How would you like to find the medicine?',
    'medicineSearch.mode.subtitle':
        'Search by name or use a clear photo of the label, package, or pill.',
    'medicineSearch.name.title': 'Find details by name',
    'medicineSearch.name.subtitle':
        'Type a brand or generic name. Suggestions appear while you type.',
    'medicineSearch.name.button': 'Search by name',
    'medicineSearch.image.title': 'Find details by photo',
    'medicineSearch.image.subtitle':
        'Choose a clear photo of the pill, bottle, or package. Smart Med reads visible text, then searches for matching details.',
    'medicineSearch.image.button': 'Search by photo',
    'medicineSearch.choosePhoto': 'Choose or take a medicine photo first.',
    'medicineSearch.ready.title': 'Ready to search',
    'medicineSearch.ready.message':
        'Choose a search method, then search for a medicine to see details here.',
    'medicineSearch.error.title': 'Search did not finish',
    'medicineSearch.details.genericName': 'Generic name: {name}',
    'medicineSearch.details.searchedAs': 'Searched as: {query}',
    'medicineSearch.details.tap': 'Tap any section to open more details.',
    'medicineSearch.details.photoNote': 'Photo search note: {note}',
    'medicineSearch.section.brandNames': 'Brand names',
    'medicineSearch.section.activeIngredients': 'Active ingredients',
    'medicineSearch.section.commonUses': 'Common uses',
    'medicineSearch.section.doseInformation': 'Dose information',
    'medicineSearch.section.warnings': 'Warnings',
    'medicineSearch.section.sideEffects': 'Side effects',
    'medicineSearch.section.storage': 'Storage',
    'medicineSearch.section.disclaimer': 'Disclaimer',
    'medicineSearch.empty.brandNames':
        'No brand names were found in the public data.',
    'medicineSearch.empty.activeIngredients':
        'No active ingredients were found in the public data.',
    'medicineSearch.empty.commonUses':
        'No public label section for uses was found.',
    'medicineSearch.empty.doseInformation': 'No public dose section was found.',
    'medicineSearch.empty.warnings': 'No public warnings section was found.',
    'medicineSearch.empty.sideEffects':
        'No public side-effects section was found.',
    'medicineSearch.empty.storage': 'No public storage guidance was found.',
    'medicineSearch.empty.disclaimer':
        'Use a clinician or pharmacist for personal medical advice.',
    'medicineSearch.more': '{preview} (+{count} more)',
    'alternative.title': 'Possible substitutes',
    'alternative.mode.title': 'Find possible substitute medicines',
    'alternative.mode.subtitle':
        'Search by name or use a clear photo of the medicine.',
    'alternative.name.title': 'Find substitutes by name',
    'alternative.name.subtitle':
        'Enter a medicine name to find related options you can discuss with a doctor or pharmacist.',
    'alternative.name.button': 'Find substitutes',
    'alternative.image.title': 'Find substitutes by photo',
    'alternative.image.subtitle':
        'Take or choose a clear medicine photo. Smart Med reads the label, then searches for related options.',
    'alternative.enterName': 'Enter a medicine name first.',
    'alternative.ready.title': 'Ready to search',
    'alternative.ready.message':
        'Search a medicine to see possible substitutes here.',
    'alternative.empty.title': 'No substitutes found',
    'alternative.empty.message':
        'No related options were found in the public data checked for {medicine}.',
    'alternative.result.title': 'Possible substitutes for {medicine}',
    'alternative.important':
        'Important: this is for information only. Ask a doctor or pharmacist before replacing any medicine.',
    'interactions.title': 'Check interactions',
    'interactions.intro.title': 'Check if two medicines may interact',
    'interactions.intro.subtitle':
        'Enter two medicine names to review possible warnings and safer-use guidance.',
    'interactions.form.title': 'Medicines to compare',
    'interactions.form.subtitle':
        'Use a brand name or generic name. Suggestions appear while you type.',
    'interactions.firstMedicine': 'First medicine',
    'interactions.secondMedicine': 'Second medicine',
    'interactions.checkButton': 'Check interaction',
    'interactions.validation.enterName': 'Enter a medicine name.',
    'interactions.validation.different': 'Enter two different medicines.',
    'interactions.source.public':
        'Checked against RxNorm, OpenFDA, and DailyMed public data.',
    'interactions.result.errorTitle': 'Interaction check did not finish',
    'interactions.result.readyTitle': 'Ready to check',
    'interactions.result.readyMessage':
        'Enter two medicines to see possible interaction warnings here.',
    'interactions.result.medicineNamesChecked': 'Medicine names checked',
    'interactions.result.first': 'First',
    'interactions.result.second': 'Second',
    'interactions.result.matchedAppList': 'Matched in app list: {details}',
    'interactions.result.checkedAs': 'Checked as: {name}',
    'interactions.result.publicGeneric': 'Public data generic name: {name}',
    'interactions.result.why': 'Why this matters',
    'interactions.result.warnings': 'Warnings',
    'interactions.result.next': 'What to do next',
    'interactions.result.evidence': 'Evidence',
    'patientInteractions.title': 'Check saved medicines',
    'patientInteractions.signIn': 'Please sign in to check medicines.',
    'patientInteractions.loadError':
        'We could not load your saved medicines. {error}',
    'patientInteractions.intro.title':
        'Check a new medicine with a saved medicine',
    'patientInteractions.intro.subtitle':
        'Choose a medicine from the patient list, then enter the new medicine you want to compare.',
    'patientInteractions.saved.title': 'Saved medicines',
    'patientInteractions.saved.empty':
        'No saved medicines yet. Add a medicine first, or use the regular interaction checker to type two medicine names.',
    'patientInteractions.saved.choose':
        'Choose one saved medicine to compare with the new medicine.',
    'patientInteractions.saved.oneSelected': '1 selected',
    'patientInteractions.saved.selectOne': 'Select one',
    'patientInteractions.new.title': 'New medicine',
    'patientInteractions.new.subtitle':
        'Type a brand or generic name. Suggestions appear while you type.',
    'patientInteractions.new.validation':
        'Enter the medicine you want to check.',
    'patientInteractions.new.selectSaved': 'Select one saved medicine first.',
    'patientInteractions.new.button': 'Check this medicine',
    'patientInteractions.result.error': 'We could not check this medicine.',
    'patientInteractions.results.title': 'Interaction results',
    'patientInteractions.results.summary':
        '{safeCount} of {totalCount} checked medicines show low or no listed severity. Review every result before taking the medicine.',
    'quickProfile.title': 'Finish your health profile',
    'quickProfile.subtitle':
        'This takes about a minute and helps Smart Med personalize interaction warnings, alternatives, and medicine safety guidance.',
    'quickProfile.callout':
        'Add health details, conditions, allergies, and current medicines so the profile is ready for safer checks.',
    'quickProfile.saveContinue': 'Save and continue',
    'quickProfile.skip.title': 'Skip health setup?',
    'quickProfile.skip.body':
        'Some safety checks are less personal until you add health details, allergies, conditions, and current medicines.',
    'quickProfile.skip.button': 'Skip for now',
    'quickProfile.saveError':
        'We could not save your health profile right now.',
    'quickProfile.skipError': 'We could not skip the setup right now.',
    'quickProfile.conditionDuplicate':
        'That condition is already in your profile.',
    'quickProfile.allergyDuplicate': 'That allergy is already in your profile.',
    'quickProfile.conditions.title': 'Health conditions',
    'quickProfile.conditions.subtitle':
        'Add long-term conditions such as diabetes, hypertension, asthma, or any condition that may affect medicine safety. Leave it blank only if none apply.',
    'quickProfile.conditions.search': 'Search or add a health condition',
    'quickProfile.conditions.loadError':
        'We could not load the health condition list right now.',
    'quickProfile.conditions.none': 'No chronic diseases selected yet.',
    'quickProfile.allergies.title': 'Drug allergies',
    'quickProfile.allergies.subtitle':
        'Search by brand or generic name, then add each allergy that matters for safety checks.',
    'quickProfile.allergies.search': 'Search a medication allergy',
    'quickProfile.allergies.loadError':
        'We could not load the medicine allergy list.',
    'quickProfile.allergies.none': 'No allergies selected yet.',
    'quickProfile.noExact':
        'No exact match found. You can still add it manually.',
    'quickProfile.addNamed': 'Add "{name}"',
    'quickProfile.medicines.title': 'Current medicines',
    'quickProfile.medicines.subtitle':
        'Optional, but helpful because interaction checks can use your real medicine list.',
    'quickProfile.medicines.none': 'No current medicines added yet.',
    'quickProfile.medicines.oneLinked': '1 medicine linked to your account.',
    'quickProfile.medicines.countLinked':
        '{count} medicines linked to your account.',
    'quickProfile.medicines.more': '+{count} more in your medicine list',
    'quickProfile.medicines.review': 'Review list',
    'quickProfile.health.selectSex': 'Select biological sex',
    'ai.title': 'Medicine guide',
    'ai.guideSettings': 'Guide settings',
    'ai.simpleOn': 'Simple language is on',
    'ai.simpleOff': 'Simple language is off',
    'ai.selectedMedicine': 'Selected medicine',
    'ai.allMedicines': 'All medicines',
    'ai.quickSummary': 'Quick summary',
    'ai.interactions': 'Interactions',
    'ai.cautions': 'Cautions',
    'ai.source': 'Source',
    'ai.rules': 'Rules',
    'ai.aiRules': 'AI + Rules',
    'ai.metric': '{label}: {value}',
    'ai.profileDetailsToAdd': 'Profile details to add',
    'ai.profileReady': 'Profile ready',
    'ai.whyAppears': 'Why this appears: {sources}',
    'ai.medicineOverview': 'Medicine overview',
    'ai.generic': 'Generic: {name}',
    'ai.evidence': 'Evidence',
    'ai.evidenceDetails': 'Evidence details',
    'ai.showEvidence': 'Show evidence',
    'ai.rulesGuide': 'Rules-based safety guide',
    'ai.aiGuide': 'AI-assisted safety guide',
    'ai.rulesGuideBody':
        'Smart Med used stored facts and safety rules because AI guidance was unavailable.',
    'ai.aiGuideBody':
        'AI simplified this explanation, while warnings still come from grounded app data.',
    'ai.sourceLine': 'Source: {value}',
    'ai.modelLine': 'Model: {value}',
    'ai.generatedLine': 'Generated: {value}',
    'ai.warningsForYou': 'Warnings for you',
    'ai.interactionSummary': 'Interaction summary',
    'ai.saferSteps': 'Safer steps',
    'ai.questionsForClinician': 'Questions for your clinician',
    'ai.informationToAdd': 'Information to add',
    'ai.errorTitle': 'We could not generate the medicine guide.',
    'ai.emptyGuide': 'The medicine guide was empty.',
    'ai.safetyPreview': 'Safety preview',
    'ai.warnings': 'Warnings',
  };

  static const Map<String, String> _ar = <String, String>{
    'app.name': 'سمارت ميد',
    'nav.home': 'الرئيسية',
    'nav.profile': 'الملف الشخصي',
    'nav.settings': 'الإعدادات',
    'common.ok': 'حسنا',
    'common.cancel': 'إلغاء',
    'common.signOut': 'تسجيل الخروج',
    'common.retry': 'إعادة المحاولة',
    'common.addMedicine': 'إضافة دواء',
    'common.medications': 'الأدوية',
    'common.search': 'بحث',
    'common.clear': 'مسح',
    'common.camera': 'الكاميرا',
    'common.gallery': 'المعرض',
    'common.viewAll': 'عرض الكل',
    'common.change': 'تغيير',
    'common.delete': 'حذف',
    'common.saveChanges': 'حفظ التغييرات',
    'common.addPhoto': 'إضافة صورة',
    'common.changePhoto': 'تغيير الصورة',
    'common.resetPhoto': 'إعادة ضبط الصورة',
    'common.noPhotoSelected': 'لم يتم اختيار صورة',
    'common.noImageSelected': 'لم يتم اختيار صورة',
    'common.useName': 'استخدام الاسم',
    'common.usePhoto': 'استخدام الصورة',
    'common.useNameSearch': 'استخدام البحث بالاسم',
    'common.usePhotoSearch': 'استخدام البحث بالصورة',
    'common.searching': 'جار البحث...',
    'common.checking': 'جار الفحص...',
    'common.wait': 'انتظر...',
    'common.capture': 'التقاط',
    'common.recentSearches': 'عمليات البحث الأخيرة',
    'common.suggestions': 'اقتراحات',
    'common.medicineName': 'اسم الدواء',
    'common.exampleIbuprofen': 'مثال: ibuprofen',
    'common.brand': 'الاسم التجاري',
    'common.generic': 'الاسم العلمي',
    'common.activeIngredients': 'المكونات الفعالة',
    'common.strength': 'التركيز',
    'common.form': 'الشكل',
    'common.selected': 'تم اختياره',
    'common.unknownMedicine': 'دواء غير معروف',
    'common.notAvailable': 'غير متوفر',
    'common.oneItem': 'عنصر واحد',
    'common.itemCount': '{count} عناصر',
    'common.goBack': 'العودة',
    'severity.high': 'مرتفع',
    'severity.moderate': 'متوسط',
    'severity.low': 'منخفض',
    'severity.none': 'لا يوجد',
    'severity.info': 'معلومة',
    'severity.unknown': 'غير معروف',
    'common.english': 'الإنجليزية',
    'common.arabic': 'العربية',
    'gate.loadingProfile': 'جار تجهيز ملفك الشخصي...',
    'gate.loadingTools': 'جار تحميل أدوات سمارت ميد...',
    'gate.profileError.title': 'تعذر إكمال تحميل ملفك الشخصي.',
    'gate.profileError.retry':
        'يرجى إعادة المحاولة. إذا استمرت المشكلة، سجّل الخروج وحاول لاحقا.',
    'onboarding.title': 'جولة سمارت ميد',
    'onboarding.skip': 'تخطي',
    'onboarding.next': 'التالي',
    'onboarding.getStarted': 'ابدأ',
    'onboarding.step': 'الخطوة {current} من {total}',
    'onboarding.step.add.title': 'أضف الأدوية بسرعة',
    'onboarding.step.add.description':
        'احفظ الدواء، وأضف صورة عند الحاجة، واحتفظ بالتفاصيل في مكان واحد.',
    'onboarding.step.interactions.title': 'افحص التداخلات',
    'onboarding.step.interactions.description':
        'قارن الأدوية قبل تناولها معا وراجع التحذيرات المحتملة مبكرا.',
    'onboarding.step.profile.title': 'جهز ملفك الشخصي',
    'onboarding.step.profile.description':
        'أضف التفاصيل الصحية والحالات والحساسيات والأدوية الحالية حتى يخصص سمارت ميد فحوصات السلامة.',
    'onboarding.step.photo.title': 'ابحث بالصورة',
    'onboarding.step.photo.description':
        'استخدم الكاميرا أو المعرض للبحث من عبوات الأدوية أو الملصقات أو الحبوب عندما تكون الكتابة غير مريحة.',
    'onboarding.step.reminders.title': 'احصل على التذكيرات',
    'onboarding.step.reminders.description':
        'أضف أوقات التذكير أثناء حفظ الأدوية ليساعدك سمارت ميد على الالتزام بالجدول.',
    'settings.title': 'الإعدادات',
    'settings.editProfile': 'تعديل الملف الشخصي',
    'settings.darkMode': 'الوضع الداكن',
    'settings.notifications': 'الإشعارات',
    'settings.language': 'اللغة',
    'settings.about': 'حول سمارت ميد',
    'settings.about.body':
        'يساعدك سمارت ميد على تنظيم الأدوية والتذكيرات وفحص التداخلات ومعلومات الدواء في مكان واحد.',
    'settings.contact': 'التواصل',
    'settings.contact.body':
        'البريد الإلكتروني: smartmed@app.com\nالهاتف: +000 000 000 000',
    'settings.help': 'المساعدة',
    'settings.help.body': 'ستتوفر المساعدة والأسئلة الشائعة في تحديث قادم.',
    'settings.version': 'إصدار التطبيق',
    'settings.version.body': 'Smart Med v1.0.0',
    'settings.notifications.blocked':
        'الإشعارات محظورة. يمكنك تفعيلها من إعدادات الجهاز.',
    'settings.notifications.ready': 'إشعارات التذكير جاهزة.',
    'settings.notifications.on': 'تم تشغيل الإشعارات ومزامنة التذكيرات.',
    'settings.notifications.off': 'تم إيقاف الإشعارات ومسح تذكيرات التنبيه.',
    'settings.signOut.title': 'هل تريد تسجيل الخروج؟',
    'settings.signOut.body': 'يمكنك تسجيل الدخول مرة أخرى في أي وقت.',
    'auth.welcomeBack': 'مرحبا بعودتك',
    'auth.signIn.subtitle': 'سجل الدخول لإدارة أدويتك وتذكيراتك.',
    'auth.email': 'البريد الإلكتروني',
    'auth.password': 'كلمة المرور',
    'auth.emailHint': 'you@example.com',
    'auth.passwordHint': 'كلمة المرور',
    'auth.signIn': 'تسجيل الدخول',
    'auth.forgotPassword': 'نسيت كلمة المرور؟',
    'auth.createAccountPrompt': 'جديد في سمارت ميد؟ أنشئ حسابا',
    'auth.createAccount': 'إنشاء حساب',
    'auth.signup.subtitle': 'أنشئ حسابا حتى تبقى أدويتك محفوظة.',
    'auth.fullName': 'الاسم الكامل *',
    'auth.fullNameHint': 'اسمك الكامل',
    'auth.age': 'العمر *',
    'auth.ageHint': 'عمرك',
    'auth.passwordCreateHint': '6 أحرف على الأقل',
    'auth.validation.emailPasswordRequired':
        'يرجى إدخال البريد الإلكتروني وكلمة المرور.',
    'auth.validation.validEmail': 'يرجى إدخال عنوان بريد إلكتروني صالح.',
    'auth.validation.emailRequired': 'يرجى إدخال عنوان بريدك الإلكتروني.',
    'auth.validation.emailFirst': 'أدخل عنوان بريدك الإلكتروني أولا.',
    'auth.validation.nameRequired': 'يرجى إدخال اسمك الكامل.',
    'auth.validation.ageRequired': 'يرجى إدخال عمرك.',
    'auth.validation.ageNumber': 'يجب أن يكون العمر رقما.',
    'auth.validation.ageRange': 'يرجى إدخال عمر بين 1 و120.',
    'auth.validation.passwordRequired': 'يرجى إدخال كلمة مرور.',
    'auth.validation.passwordLength': 'استخدم 6 أحرف على الأقل لكلمة المرور.',
    'auth.signIn.success': 'تم تسجيل الدخول.',
    'auth.signIn.invalidCredentials':
        'البريد الإلكتروني أو كلمة المرور غير مطابقين. يرجى المحاولة مرة أخرى.',
    'auth.signIn.error': 'تعذر تسجيل الدخول. يرجى المحاولة مرة أخرى.',
    'auth.signIn.unexpected':
        'حدث خطأ أثناء تسجيل الدخول. يرجى المحاولة مرة أخرى.',
    'auth.reset.sent': 'تم إرسال رسالة إعادة تعيين كلمة المرور. تحقق من بريدك.',
    'auth.reset.error': 'تعذر إرسال رسالة إعادة التعيين.',
    'auth.reset.unexpected': 'حدث خطأ أثناء إرسال الرسالة.',
    'auth.signup.success': 'حسابك جاهز.',
    'auth.signup.error': 'تعذر إنشاء حسابك.',
    'auth.signup.unexpected': 'حدث خطأ أثناء إنشاء حسابك.',
    'home.greeting.title': 'مرحبا، {name}',
    'home.greeting.fallback': 'بك',
    'home.greeting.subtitle': 'إليك ما يحتاج إلى انتباهك اليوم.',
    'home.action.details': 'تفاصيل الدواء',
    'home.action.details.subtitle': 'ابحث بالاسم أو بالصورة',
    'home.action.details.tooltip':
        'ابحث عن تفاصيل الدواء بالاسم أو بالصورة وراجع أهم المعلومات قبل استخدامه.',
    'home.action.interactions': 'فحص التداخلات',
    'home.action.interactions.subtitle': 'قارن بين دواءين',
    'home.action.interactions.tooltip':
        'قارن بين الأدوية لاكتشاف تحذيرات التداخلات ومخاطر السلامة قبل الجمع بينها.',
    'home.action.medicines': 'أدويتي',
    'home.action.medicines.subtitle': 'راجع الأدوية المحفوظة',
    'home.action.medicines.tooltip':
        'افتح قائمة أدويتك الحالية لمراجعة التفاصيل والتذكيرات وأي تعديلات تحتاجها.',
    'home.action.substitutes': 'بدائل محتملة',
    'home.action.substitutes.subtitle': 'خيارات للمناقشة',
    'home.action.substitutes.tooltip':
        'ابحث عن أدوية مشابهة يمكنك مناقشتها مع الطبيب أو الصيدلي قبل تغيير العلاج.',
    'home.camera.openError': 'تعذر فتح الكاميرا. {error}',
    'home.camera.captureError': 'تعذر التقاط الصورة. {error}',
    'home.schedule.loading': 'جار تحميل جدول أدوية اليوم...',
    'home.noMedicines.title': 'لا توجد أدوية بعد',
    'home.noMedicines.body': 'أضف أول دواء لديك لعرض الجرعة التالية هنا.',
    'home.noDoses.title': 'لا توجد جرعات أخرى اليوم',
    'home.noDoses.body': 'أنت جاهز لبقية اليوم حسب جدولك الحالي.',
    'home.nextDose.title': 'الجرعة التالية',
    'home.dose.detail': 'الجرعة {dosage} في {time}',
    'home.dose.snoozed': 'مؤجلة',
    'home.dose.overdue': 'متأخرة',
    'home.dose.today': 'اليوم',
    'home.dose.tomorrow': 'غدا',
    'home.dose.taken': 'تم أخذها',
    'home.dose.snooze': 'تأجيل',
    'home.dose.skip': 'تخطي',
    'home.dose.markedTaken': 'تم تسجيل {medicine} كجرعة مأخوذة.',
    'home.dose.markedSkipped': 'تم تخطي جرعة {medicine}.',
    'home.dose.snoozedUntil': 'تم تأجيل {medicine} حتى {time}.',
    'home.safety.missing.age': 'العمر',
    'home.safety.missing.weight': 'الوزن',
    'home.safety.missing.bloodPressure': 'ضغط الدم',
    'home.safety.missing.saveSetup': 'حفظ الإعداد',
    'home.safety.title': 'حالة السلامة',
    'home.safety.loading': 'جار تحميل ملف السلامة...',
    'home.safety.complete':
        'يحتوي ملف السلامة على التفاصيل الأساسية لفحوصات أفضل.',
    'home.safety.incomplete':
        'اكتمل الملف {completed}/{total}. أضف التفاصيل الناقصة أو احفظ الإعداد إذا لم تنطبق.',
    'home.safety.summary':
        'الحساسيات: {allergies}، الحالات: {conditions}، الأدوية النشطة: {medicines}',
    'home.safety.checkMedicines': 'فحص الأدوية',
    'home.safety.finishProfile': 'إكمال الملف',
    'home.quickStart.title': 'بدء سريع',
    'home.quickStart.scanPhoto': 'مسح صورة',
    'home.today.title': 'أدوية اليوم',
    'home.today.noMedicines': 'لا توجد أدوية بعد.',
    'home.today.noMoreScheduled': 'لا توجد جرعات مجدولة أخرى اليوم.',
    'home.tools.title': 'الأدوات',
    'home.scan.title': 'البحث بالصورة',
    'home.scan.body':
        'استخدم الكاميرا أو المعرض للتعرف على الدواء من الملصق أو العبوة، ثم ابحث عنه أو أضفه إلى قائمتك.',
    'home.scan.holdOn': 'انتظر قليلا...',
    'home.scan.capture': 'التقاط',
    'home.scan.photoReady': 'تم اختيار الصورة وهي جاهزة.',
    'home.scan.noPhoto': 'لم يتم اختيار صورة',
    'home.scan.placeholder': 'استخدم الكاميرا أو المعرض للبحث بالصورة.',
    'home.auth.signInPrompt': 'يرجى تسجيل الدخول لاستخدام سمارت ميد.',
    'profile.title': 'الملف الشخصي',
    'profile.loadError': 'تعذر تحميل ملفك الشخصي.',
    'profile.photo.editRequired': 'اضغط على التعديل قبل تغيير صورة الملف.',
    'profile.photo.change': 'تغيير الصورة',
    'profile.photo.add': 'إضافة صورة',
    'profile.condition.duplicate': 'هذه الحالة موجودة بالفعل في الملف.',
    'profile.allergy.duplicate': 'هذه الحساسية موجودة بالفعل في الملف.',
    'profile.signInAgain': 'يرجى تسجيل الدخول مرة أخرى.',
    'profile.validation.nameRequired': 'يرجى إدخال اسمك.',
    'profile.validation.ageRequired': 'يرجى إدخال عمرك.',
    'profile.validation.ageNumber': 'يجب أن يكون العمر رقما.',
    'profile.validation.ageRange': 'يرجى إدخال عمر بين 1 و120.',
    'profile.saved': 'تم حفظ الملف الشخصي.',
    'profile.saveError': 'تعذر حفظ ملفك الشخصي.',
    'profile.yourName': 'اسمك',
    'profile.ageLabel': 'العمر: ',
    'profile.saveProfile': 'حفظ الملف',
    'profile.conditions.title': 'الحالات الصحية',
    'profile.conditions.subtitle':
        'أضف الحالات طويلة الأمد التي قد تؤثر في سلامة الأدوية.',
    'profile.conditions.hint.view': 'اضغط تعديل لإضافة الحالات',
    'profile.conditions.hint.loading': 'جار تحميل الحالات...',
    'profile.conditions.hint.empty': 'لا توجد حالات متاحة',
    'profile.conditions.hint.select': 'اختر حالة',
    'profile.conditions.loadError': 'تعذر تحميل قائمة الحالات.',
    'profile.conditions.retry': 'إعادة تحميل الحالات',
    'profile.conditions.add': 'إضافة حالة',
    'profile.conditions.none': 'لم تتم إضافة حالات صحية',
    'profile.allergies.title': 'حساسيات الأدوية',
    'profile.allergies.subtitle': 'أضف الأدوية التي قد تسبب رد فعل تحسسي.',
    'profile.allergies.hint.view': 'اضغط تعديل لإضافة الحساسية',
    'profile.allergies.hint.loading': 'جار تحميل الأدوية...',
    'profile.allergies.hint.empty': 'لا توجد أدوية متاحة',
    'profile.allergies.hint.select': 'اختر دواء',
    'profile.allergies.loadError': 'تعذر تحميل قائمة الأدوية.',
    'profile.allergies.retry': 'إعادة تحميل الأدوية',
    'profile.allergies.add': 'إضافة حساسية',
    'profile.allergies.none': 'لم تتم إضافة حساسيات أدوية',
    'profile.health.title': 'التفاصيل الصحية',
    'profile.health.subtitle':
        'تساعد هذه التفاصيل سمارت ميد على تخصيص إرشادات السلامة.',
    'profile.health.biologicalSex': 'الجنس البيولوجي',
    'profile.health.male': 'ذكر',
    'profile.health.female': 'أنثى',
    'profile.health.weight': 'الوزن (كغ)',
    'profile.health.height': 'الطول (سم)',
    'profile.health.bloodPressure': 'ضغط الدم',
    'profile.health.bloodPressureHelp':
        'SYS هو الرقم العلوي وDIA هو الرقم السفلي.',
    'profile.health.systolic': 'SYS / العلوي',
    'profile.health.diastolic': 'DIA / السفلي',
    'profile.health.bloodGlucose': 'سكر الدم',
    'profile.health.pregnant': 'حامل',
    'profile.health.breastfeeding': 'مرضع',
    'profile.readiness.age': 'العمر',
    'profile.readiness.allergies': 'الحساسيات',
    'profile.readiness.conditions': 'الحالات',
    'profile.readiness.weight': 'الوزن',
    'profile.readiness.bloodPressure': 'ضغط الدم',
    'profile.readiness.pregnancyStatus': 'حالة الحمل',
    'profile.readiness.title': 'جاهزية ملف السلامة',
    'profile.readiness.complete':
        'يحتوي ملفك على التفاصيل الأساسية اللازمة لإرشادات سلامة أفضل.',
    'profile.readiness.incomplete':
        'قد تجعل التفاصيل الناقصة التحذيرات أقل تخصيصا. أضف ما تستطيع الآن وحدث الباقي لاحقا.',
    'medication.add.title': 'إضافة دواء',
    'medication.edit.title': 'تعديل الدواء',
    'medication.list.title': 'أدويتي',
    'medication.signIn.view': 'يرجى تسجيل الدخول لعرض الأدوية.',
    'medication.nameRequired': 'اسم الدواء *',
    'medication.nameHelper': 'ابدأ بالكتابة، ثم اختر الدواء الصحيح من القائمة.',
    'medication.selectFromList': 'اختر دواء من القائمة.',
    'medication.noMatch':
        'لم يتم العثور على دواء مطابق. تحقق من الإملاء أو جرب الاسم العلمي.',
    'medication.searchListError': 'تعذر البحث في قائمة الأدوية الآن.',
    'medication.photo.title': 'صورة الدواء',
    'medication.photo.addSubtitle':
        'اختياري. أضف صورة واضحة للحبة أو العبوة للمساعدة في تعبئة اسم الدواء والجرعة.',
    'medication.photo.editSubtitle':
        'اختياري. أضف أو غيّر الصورة المستخدمة لهذا الدواء.',
    'medication.photo.reading':
        'جار قراءة الصورة ومطابقتها مع قائمة الأدوية...',
    'medication.photo.filledNameDose':
        'تم تعبئة اسم الدواء والجرعة من الصورة. يرجى مراجعتهما قبل الحفظ.',
    'medication.photo.filledName':
        'تم تعبئة اسم الدواء من الصورة. يرجى مراجعة الجرعة قبل الحفظ.',
    'medication.photo.unavailable':
        'تعبئة الصورة غير متاحة الآن. يمكنك إدخال التفاصيل يدويا.',
    'medication.doseAmountRequired': 'كمية الجرعة *',
    'medication.doseAmount': 'كمية الجرعة',
    'medication.doseUnitRequired': 'وحدة الجرعة *',
    'medication.doseUnit': 'وحدة الجرعة',
    'medication.timesPerDayRequired': 'المرات في اليوم (1-6) *',
    'medication.timesPerDay': 'المرات في اليوم',
    'medication.firstReminderRequired': 'وقت التذكير الأول *',
    'medication.firstReminder': 'وقت التذكير الأول',
    'medication.reminderHelper': 'سيحسب سمارت ميد بقية التذكيرات.',
    'medication.reminderChoose':
        'اختر وقت التذكير الأول. سيجدول سمارت ميد البقية كل {interval}.',
    'medication.reminderTimes': 'أوقات التذكير: {times}',
    'medication.interval.minute': 'دقيقة واحدة',
    'medication.interval.minutes': '{count} دقائق',
    'medication.interval.hour': 'ساعة واحدة',
    'medication.interval.hours': '{count} ساعات',
    'medication.interval.hourMinute': '{hours} و{minutes}',
    'medication.startDateRequired': 'تاريخ البدء *',
    'medication.startDate': 'تاريخ البدء',
    'medication.finishDate': 'تاريخ الانتهاء',
    'medication.finishDateHelper': 'اختياري. تتوقف التذكيرات بعد هذا التاريخ.',
    'medication.clearFinishDate': 'مسح تاريخ الانتهاء',
    'medication.notes': 'ملاحظات',
    'medication.validation.doseRequired': 'أدخل كمية الجرعة.',
    'medication.validation.validDose': 'أدخل رقما صالحا للجرعة.',
    'medication.validation.timesRequired': 'أدخل عدد مرات أخذ الدواء في اليوم.',
    'medication.validation.enterNumber': 'أدخل رقما.',
    'medication.validation.timesRange': 'اختر رقما من 1 إلى 6.',
    'medication.validation.maxTimes': 'الحد الأقصى هو 6 مرات في اليوم.',
    'medication.validation.firstReminder': 'اختر وقت التذكير الأول.',
    'medication.validation.startDate': 'اختر تاريخ البدء.',
    'medication.validation.finishDate': 'اختر تاريخ انتهاء صالحا.',
    'medication.validation.finishBeforeStart':
        'لا يمكن أن يكون تاريخ الانتهاء قبل تاريخ البدء.',
    'medication.validation.signInSave': 'يرجى تسجيل الدخول قبل حفظ الأدوية.',
    'medication.validation.signInUpdate':
        'يرجى تسجيل الدخول مرة أخرى قبل تحديث هذا الدواء.',
    'medication.saved.off': 'تمت إضافة الدواء. التذكيرات متوقفة في الإعدادات.',
    'medication.saved': 'تمت إضافة الدواء.',
    'medication.saved.partial':
        'تمت إضافة الدواء، لكن تعذر جدولة بعض التذكيرات.',
    'medication.saved.noReminders':
        'تمت إضافة الدواء، لكن تعذر جدولة التذكيرات.',
    'medication.updated.off': 'تم تحديث الدواء. التذكيرات متوقفة في الإعدادات.',
    'medication.updated': 'تم تحديث الدواء.',
    'medication.updated.partial':
        'تم تحديث الدواء، لكن تعذر جدولة بعض التذكيرات.',
    'medication.updated.noReminders':
        'تم تحديث الدواء، لكن تعذر جدولة التذكيرات.',
    'medication.saveError': 'تعذر حفظ هذا الدواء الآن.',
    'medication.saveErrorDetail': 'تعذر حفظ هذا الدواء. {error}',
    'medication.updateError': 'تعذر تحديث هذا الدواء الآن.',
    'medication.updateErrorDetail': 'تعذر تحديث هذا الدواء. {error}',
    'medication.permissionSave': 'ليس لديك إذن لحفظ هذا الدواء.',
    'medication.permissionUpdate': 'ليس لديك إذن لتحديث هذا الدواء.',
    'medication.serviceUnavailable':
        'الخدمة غير متاحة مؤقتا. يرجى المحاولة مرة أخرى.',
    'medication.notificationBody': 'حان وقت أخذ {medicine}',
    'medication.deleteError': 'تعذر حذف هذا الدواء.',
    'medication.deleted': 'تم حذف الدواء.',
    'medication.deleteTitle': 'حذف الدواء؟',
    'medication.deleteBody': 'سيؤدي هذا إلى إزالة {medicine} وإلغاء تذكيراته.',
    'medication.loadError': 'تعذر تحميل أدويتك. {error}',
    'medication.empty.title': 'لا توجد أدوية بعد',
    'medication.empty.body':
        'أضف أول دواء لديك حتى تستخدمه التذكيرات وفحوصات السلامة.',
    'medication.info.dose': 'الجرعة',
    'medication.info.howOften': 'كم مرة',
    'medication.info.reminderTimes': 'أوقات التذكير',
    'medication.info.startDate': 'تاريخ البدء',
    'medication.info.finishDate': 'تاريخ الانتهاء',
    'medication.info.notes': 'ملاحظات',
    'medicineSearch.title': 'تفاصيل الدواء',
    'medicineSearch.mode.title': 'كيف تريد العثور على الدواء؟',
    'medicineSearch.mode.subtitle':
        'ابحث بالاسم أو استخدم صورة واضحة للملصق أو العبوة أو الحبة.',
    'medicineSearch.name.title': 'العثور على التفاصيل بالاسم',
    'medicineSearch.name.subtitle':
        'اكتب اسما تجاريا أو علميا. ستظهر الاقتراحات أثناء الكتابة.',
    'medicineSearch.name.button': 'البحث بالاسم',
    'medicineSearch.image.title': 'العثور على التفاصيل بالصورة',
    'medicineSearch.image.subtitle':
        'اختر صورة واضحة للحبة أو العبوة. يقرأ سمارت ميد النص الظاهر ثم يبحث عن التفاصيل المطابقة.',
    'medicineSearch.image.button': 'البحث بالصورة',
    'medicineSearch.choosePhoto': 'اختر أو التقط صورة للدواء أولا.',
    'medicineSearch.ready.title': 'جاهز للبحث',
    'medicineSearch.ready.message':
        'اختر طريقة البحث، ثم ابحث عن دواء لعرض التفاصيل هنا.',
    'medicineSearch.error.title': 'لم يكتمل البحث',
    'medicineSearch.details.genericName': 'الاسم العلمي: {name}',
    'medicineSearch.details.searchedAs': 'تم البحث باسم: {query}',
    'medicineSearch.details.tap': 'اضغط على أي قسم لعرض مزيد من التفاصيل.',
    'medicineSearch.details.photoNote': 'ملاحظة البحث بالصورة: {note}',
    'medicineSearch.section.brandNames': 'الأسماء التجارية',
    'medicineSearch.section.activeIngredients': 'المكونات الفعالة',
    'medicineSearch.section.commonUses': 'الاستخدامات الشائعة',
    'medicineSearch.section.doseInformation': 'معلومات الجرعة',
    'medicineSearch.section.warnings': 'تحذيرات',
    'medicineSearch.section.sideEffects': 'الآثار الجانبية',
    'medicineSearch.section.storage': 'التخزين',
    'medicineSearch.section.disclaimer': 'تنبيه',
    'medicineSearch.empty.brandNames':
        'لم يتم العثور على أسماء تجارية في البيانات العامة.',
    'medicineSearch.empty.activeIngredients':
        'لم يتم العثور على مكونات فعالة في البيانات العامة.',
    'medicineSearch.empty.commonUses':
        'لم يتم العثور على قسم استخدامات في النشرة العامة.',
    'medicineSearch.empty.doseInformation': 'لم يتم العثور على قسم جرعات عام.',
    'medicineSearch.empty.warnings': 'لم يتم العثور على قسم تحذيرات عام.',
    'medicineSearch.empty.sideEffects':
        'لم يتم العثور على قسم آثار جانبية عام.',
    'medicineSearch.empty.storage': 'لم يتم العثور على إرشادات تخزين عامة.',
    'medicineSearch.empty.disclaimer':
        'استشر طبيبا أو صيدليا للحصول على نصيحة طبية شخصية.',
    'medicineSearch.more': '{preview} (+{count} إضافية)',
    'alternative.title': 'بدائل محتملة',
    'alternative.mode.title': 'العثور على أدوية بديلة محتملة',
    'alternative.mode.subtitle': 'ابحث بالاسم أو استخدم صورة واضحة للدواء.',
    'alternative.name.title': 'العثور على بدائل بالاسم',
    'alternative.name.subtitle':
        'أدخل اسم دواء للعثور على خيارات مشابهة يمكنك مناقشتها مع الطبيب أو الصيدلي.',
    'alternative.name.button': 'البحث عن بدائل',
    'alternative.image.title': 'العثور على بدائل بالصورة',
    'alternative.image.subtitle':
        'التقط أو اختر صورة واضحة للدواء. يقرأ سمارت ميد الملصق ثم يبحث عن خيارات مشابهة.',
    'alternative.enterName': 'أدخل اسم الدواء أولا.',
    'alternative.ready.title': 'جاهز للبحث',
    'alternative.ready.message': 'ابحث عن دواء لعرض البدائل المحتملة هنا.',
    'alternative.empty.title': 'لم يتم العثور على بدائل',
    'alternative.empty.message':
        'لم يتم العثور على خيارات مشابهة في البيانات العامة المفحوصة لـ {medicine}.',
    'alternative.result.title': 'بدائل محتملة لـ {medicine}',
    'alternative.important':
        'مهم: هذه المعلومات للاطلاع فقط. اسأل طبيبا أو صيدليا قبل استبدال أي دواء.',
    'interactions.title': 'فحص التداخلات',
    'interactions.intro.title': 'فحص احتمال تداخل دواءين',
    'interactions.intro.subtitle':
        'أدخل اسمَي دواءين لمراجعة التحذيرات المحتملة وإرشادات الاستخدام الآمن.',
    'interactions.form.title': 'الأدوية للمقارنة',
    'interactions.form.subtitle':
        'استخدم اسما تجاريا أو علميا. ستظهر الاقتراحات أثناء الكتابة.',
    'interactions.firstMedicine': 'الدواء الأول',
    'interactions.secondMedicine': 'الدواء الثاني',
    'interactions.checkButton': 'فحص التداخل',
    'interactions.validation.enterName': 'أدخل اسم دواء.',
    'interactions.validation.different': 'أدخل دواءين مختلفين.',
    'interactions.source.public':
        'تم الفحص مقابل بيانات RxNorm وOpenFDA وDailyMed العامة.',
    'interactions.result.errorTitle': 'لم يكتمل فحص التداخل',
    'interactions.result.readyTitle': 'جاهز للفحص',
    'interactions.result.readyMessage':
        'أدخل دواءين لعرض تحذيرات التداخل المحتملة هنا.',
    'interactions.result.medicineNamesChecked': 'أسماء الأدوية التي تم فحصها',
    'interactions.result.first': 'الأول',
    'interactions.result.second': 'الثاني',
    'interactions.result.matchedAppList': 'مطابق في قائمة التطبيق: {details}',
    'interactions.result.checkedAs': 'تم الفحص باسم: {name}',
    'interactions.result.publicGeneric':
        'الاسم العلمي في البيانات العامة: {name}',
    'interactions.result.why': 'لماذا هذا مهم',
    'interactions.result.warnings': 'تحذيرات',
    'interactions.result.next': 'ما الخطوة التالية',
    'interactions.result.evidence': 'الأدلة',
    'patientInteractions.title': 'فحص الأدوية المحفوظة',
    'patientInteractions.signIn': 'يرجى تسجيل الدخول لفحص الأدوية.',
    'patientInteractions.loadError': 'تعذر تحميل الأدوية المحفوظة. {error}',
    'patientInteractions.intro.title': 'فحص دواء جديد مع دواء محفوظ',
    'patientInteractions.intro.subtitle':
        'اختر دواء من قائمة المريض، ثم أدخل الدواء الجديد الذي تريد مقارنته.',
    'patientInteractions.saved.title': 'الأدوية المحفوظة',
    'patientInteractions.saved.empty':
        'لا توجد أدوية محفوظة بعد. أضف دواء أولا، أو استخدم فاحص التداخلات العادي لكتابة اسمَي دواءين.',
    'patientInteractions.saved.choose':
        'اختر دواء محفوظا واحدا لمقارنته مع الدواء الجديد.',
    'patientInteractions.saved.oneSelected': 'تم اختيار 1',
    'patientInteractions.saved.selectOne': 'اختر واحدا',
    'patientInteractions.new.title': 'دواء جديد',
    'patientInteractions.new.subtitle':
        'اكتب اسما تجاريا أو علميا. ستظهر الاقتراحات أثناء الكتابة.',
    'patientInteractions.new.validation': 'أدخل الدواء الذي تريد فحصه.',
    'patientInteractions.new.selectSaved': 'اختر دواء محفوظا واحدا أولا.',
    'patientInteractions.new.button': 'فحص هذا الدواء',
    'patientInteractions.result.error': 'تعذر فحص هذا الدواء.',
    'patientInteractions.results.title': 'نتائج التداخل',
    'patientInteractions.results.summary':
        '{safeCount} من {totalCount} أدوية مفحوصة تظهر شدة منخفضة أو لا توجد شدة مسجلة. راجع كل نتيجة قبل أخذ الدواء.',
    'quickProfile.title': 'أكمل ملفك الصحي',
    'quickProfile.subtitle':
        'يستغرق هذا نحو دقيقة ويساعد سمارت ميد على تخصيص تحذيرات التداخل والبدائل وإرشادات سلامة الأدوية.',
    'quickProfile.callout':
        'أضف التفاصيل الصحية والحالات والحساسيات والأدوية الحالية حتى يكون الملف جاهزا لفحوصات أكثر أمانا.',
    'quickProfile.saveContinue': 'حفظ ومتابعة',
    'quickProfile.skip.title': 'تخطي إعداد الصحة؟',
    'quickProfile.skip.body':
        'تكون بعض فحوصات السلامة أقل تخصيصا حتى تضيف التفاصيل الصحية والحساسيات والحالات والأدوية الحالية.',
    'quickProfile.skip.button': 'تخطي الآن',
    'quickProfile.saveError': 'تعذر حفظ ملفك الصحي الآن.',
    'quickProfile.skipError': 'تعذر تخطي الإعداد الآن.',
    'quickProfile.conditionDuplicate': 'هذه الحالة موجودة بالفعل في ملفك.',
    'quickProfile.allergyDuplicate': 'هذه الحساسية موجودة بالفعل في ملفك.',
    'quickProfile.conditions.title': 'الحالات الصحية',
    'quickProfile.conditions.subtitle':
        'أضف الحالات طويلة الأمد مثل السكري أو ارتفاع الضغط أو الربو أو أي حالة قد تؤثر في سلامة الدواء. اتركها فارغة فقط إذا لم توجد حالات.',
    'quickProfile.conditions.search': 'ابحث أو أضف حالة صحية',
    'quickProfile.conditions.loadError':
        'تعذر تحميل قائمة الحالات الصحية الآن.',
    'quickProfile.conditions.none': 'لم يتم اختيار أمراض مزمنة بعد.',
    'quickProfile.allergies.title': 'حساسيات الأدوية',
    'quickProfile.allergies.subtitle':
        'ابحث بالاسم التجاري أو العلمي، ثم أضف كل حساسية مهمة لفحوصات السلامة.',
    'quickProfile.allergies.search': 'ابحث عن حساسية دواء',
    'quickProfile.allergies.loadError': 'تعذر تحميل قائمة حساسيات الأدوية.',
    'quickProfile.allergies.none': 'لم يتم اختيار حساسيات بعد.',
    'quickProfile.noExact':
        'لم يتم العثور على تطابق دقيق. ما زال بإمكانك إضافته يدويا.',
    'quickProfile.addNamed': 'إضافة "{name}"',
    'quickProfile.medicines.title': 'الأدوية الحالية',
    'quickProfile.medicines.subtitle':
        'اختياري، لكنه مفيد لأن فحوصات التداخل يمكنها استخدام قائمة أدويتك الحقيقية.',
    'quickProfile.medicines.none': 'لم تتم إضافة أدوية حالية بعد.',
    'quickProfile.medicines.oneLinked': 'دواء واحد مرتبط بحسابك.',
    'quickProfile.medicines.countLinked': '{count} أدوية مرتبطة بحسابك.',
    'quickProfile.medicines.more': '+{count} أخرى في قائمة أدويتك',
    'quickProfile.medicines.review': 'مراجعة القائمة',
    'quickProfile.health.selectSex': 'اختر الجنس البيولوجي',
    'ai.title': 'دليل الدواء',
    'ai.guideSettings': 'إعدادات الدليل',
    'ai.simpleOn': 'اللغة المبسطة مفعلة',
    'ai.simpleOff': 'اللغة المبسطة متوقفة',
    'ai.selectedMedicine': 'الدواء المحدد',
    'ai.allMedicines': 'كل الأدوية',
    'ai.quickSummary': 'ملخص سريع',
    'ai.interactions': 'التداخلات',
    'ai.cautions': 'تنبيهات',
    'ai.source': 'المصدر',
    'ai.rules': 'القواعد',
    'ai.aiRules': 'الذكاء الاصطناعي + القواعد',
    'ai.metric': '{label}: {value}',
    'ai.profileDetailsToAdd': 'تفاصيل الملف التي يجب إضافتها',
    'ai.profileReady': 'الملف جاهز',
    'ai.whyAppears': 'سبب الظهور: {sources}',
    'ai.medicineOverview': 'نظرة عامة على الدواء',
    'ai.generic': 'الاسم العلمي: {name}',
    'ai.evidence': 'الأدلة',
    'ai.evidenceDetails': 'تفاصيل الأدلة',
    'ai.showEvidence': 'عرض الأدلة',
    'ai.rulesGuide': 'دليل سلامة مبني على القواعد',
    'ai.aiGuide': 'دليل سلامة بمساعدة الذكاء الاصطناعي',
    'ai.rulesGuideBody':
        'استخدم سمارت ميد الحقائق المحفوظة وقواعد السلامة لأن إرشادات الذكاء الاصطناعي غير متاحة.',
    'ai.aiGuideBody':
        'بسّط الذكاء الاصطناعي هذا الشرح، بينما لا تزال التحذيرات تأتي من بيانات التطبيق الموثوقة.',
    'ai.sourceLine': 'المصدر: {value}',
    'ai.modelLine': 'النموذج: {value}',
    'ai.generatedLine': 'تم الإنشاء: {value}',
    'ai.warningsForYou': 'تحذيرات تخصك',
    'ai.interactionSummary': 'ملخص التداخلات',
    'ai.saferSteps': 'خطوات أكثر أمانا',
    'ai.questionsForClinician': 'أسئلة للطبيب',
    'ai.informationToAdd': 'معلومات يجب إضافتها',
    'ai.errorTitle': 'تعذر إنشاء دليل الدواء.',
    'ai.emptyGuide': 'كان دليل الدواء فارغا.',
    'ai.safetyPreview': 'معاينة السلامة',
    'ai.warnings': 'تحذيرات',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final languageCode = isSupported(locale) ? locale.languageCode : 'en';
    return AppLocalizations(Locale(languageCode));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
