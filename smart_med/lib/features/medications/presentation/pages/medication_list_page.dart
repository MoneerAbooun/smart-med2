// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_med/app/localization/app_localizations.dart';
import 'package:smart_med/app/widgets/app_icon_badge.dart';
import 'package:smart_med/core/services/notification_service.dart';
import 'package:smart_med/features/medications/data/repositories/medication_repository.dart';
import 'package:smart_med/features/medications/domain/models/medication_record.dart';
import 'package:smart_med/features/medications/presentation/pages/add_medication_page.dart';
import 'package:smart_med/features/medications/presentation/pages/edit_medication_page.dart';
import 'package:smart_med/core/widgets/app_snack_bar.dart';

class MedicationListPage extends StatefulWidget {
  const MedicationListPage({super.key});

  @override
  State<MedicationListPage> createState() => _MedicationListPageState();
}

class _MedicationListPageState extends State<MedicationListPage> {
  MedicationRepository get _medicationRepository => medicationRepository;

  Future<void> deleteMedication(
    BuildContext context,
    MedicationRecord medication,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final medicationId = medication.id;

    if (user == null || medicationId == null) {
      AppSnackBar.show(
        context,
        context.l10n.text('medication.deleteError'),
        type: AppSnackBarType.error,
      );
      return;
    }

    try {
      await NotificationService.cancelNotifications(medication.notificationIds);
      await _medicationRepository.deleteMedication(
        uid: user.uid,
        medicationId: medicationId,
      );

      if (!context.mounted) return;

      AppSnackBar.show(
        context,
        context.l10n.text('medication.deleted'),
        type: AppSnackBarType.success,
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      AppSnackBar.show(
        context,
        e.message ?? context.l10n.text('medication.deleteError'),
        type: AppSnackBarType.error,
      );
    } catch (e) {
      if (!context.mounted) return;

      AppSnackBar.show(context, e.toString(), type: AppSnackBarType.error);
    }
  }

  Future<void> confirmDelete(
    BuildContext context,
    MedicationRecord medication,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.text('medication.deleteTitle')),
          content: Text(
            l10n.format('medication.deleteBody', <String, String>{
              'medicine': l10n.isolate(medication.name),
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.text('common.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.text('common.delete')),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await deleteMedication(context, medication);
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }

    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Widget buildMedicationInfo(BuildContext context, String title, String value) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          children: [
            TextSpan(
              text: '$title: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: l10n.isolate(value)),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationThumbnail(
    BuildContext context,
    MedicationRecord medication,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = medication.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 56,
        height: 56,
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return AppIconBadge(
                    icon: Icons.medication_outlined,
                    accentColor: colorScheme.primary,
                    size: 56,
                    iconSize: 28,
                    borderRadius: 16,
                  );
                },
              )
            : AppIconBadge(
                icon: Icons.medication_outlined,
                accentColor: colorScheme.primary,
                size: 56,
                iconSize: 28,
                borderRadius: 16,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = context.l10n;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.text('medication.list.title')),
          centerTitle: true,
        ),
        body: Center(child: Text(l10n.text('medication.signIn.view'))),
      );
    }

    final medicationsStream = _medicationRepository.watchMedicationRecords(
      uid: user.uid,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.text('medication.list.title')),
        centerTitle: true,
      ),
      body: StreamBuilder<List<MedicationRecord>>(
        stream: medicationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                l10n.format('medication.loadError', <String, String>{
                  'error': l10n.isolate(snapshot.error.toString()),
                }),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppIconBadge(
                      icon: Icons.medication_outlined,
                      size: 76,
                      iconSize: 36,
                      borderRadius: 24,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.text('medication.empty.title'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.text('medication.empty.body'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddMedicationPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: Text(l10n.text('common.addMedicine')),
                    ),
                  ],
                ),
              ),
            );
          }

          final medications = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: medications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final medication = medications[index];
              final startDate = _formatDate(medication.startDate);
              final finishDate = _formatDate(medication.endDate);

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMedicationThumbnail(context, medication),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.isolate(medication.name),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditMedicationPage(
                                    medication: medication,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () {
                              confirmDelete(context, medication);
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (medication.dosage.isNotEmpty)
                        buildMedicationInfo(
                          context,
                          l10n.text('medication.info.dose'),
                          medication.dosage,
                        ),
                      if (medication.frequency.isNotEmpty)
                        buildMedicationInfo(
                          context,
                          l10n.text('medication.info.howOften'),
                          medication.frequency,
                        ),
                      if (medication.reminderTimes.isNotEmpty)
                        buildMedicationInfo(
                          context,
                          l10n.text('medication.info.reminderTimes'),
                          medication.reminderTimes.join(', '),
                        ),
                      if (startDate.isNotEmpty)
                        buildMedicationInfo(
                          context,
                          l10n.text('medication.info.startDate'),
                          startDate,
                        ),
                      if (finishDate.isNotEmpty)
                        buildMedicationInfo(
                          context,
                          l10n.text('medication.info.finishDate'),
                          finishDate,
                        ),
                      if ((medication.notes ?? '').isNotEmpty)
                        buildMedicationInfo(
                          context,
                          l10n.text('medication.info.notes'),
                          medication.notes!,
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMedicationPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.text('common.addMedicine')),
      ),
    );
  }
}
