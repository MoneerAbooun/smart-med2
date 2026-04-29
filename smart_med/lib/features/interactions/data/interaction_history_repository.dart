import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_med/core/firebase/firestore_paths.dart';
import 'package:smart_med/features/interactions/data/models/interaction_history_record.dart';

class InteractionHistoryRepository {
  InteractionHistoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirestorePaths.interactionHistoryCollection(_firestore, uid);
  }

  Stream<List<InteractionHistoryRecord>> watchHistory({required String uid}) {
    return _collection(uid).orderBy('checkedAt', descending: true).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => InteractionHistoryRecord.fromMap(doc.id, doc.data()))
          .toList(growable: false),
    );
  }

  Future<List<InteractionHistoryRecord>> listHistory({
    required String uid,
  }) async {
    final snapshot = await _collection(uid)
        .orderBy('checkedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => InteractionHistoryRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<void> saveEntry({
    required String uid,
    required InteractionHistoryRecord entry,
    String? historyId,
  }) async {
    final docRef = historyId == null
        ? _collection(uid).doc()
        : FirestorePaths.interactionHistoryDoc(_firestore, uid, historyId);

    final existing = await docRef.get();
    final payload = entry.toMap();
    payload['userId'] = uid;
    payload['checkedAt'] = entry.checkedAt ?? FieldValue.serverTimestamp();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['createdAt'] = existing.exists
        ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
        : (entry.createdAt ?? FieldValue.serverTimestamp());

    await docRef.set(payload, SetOptions(merge: true));
  }
}

final InteractionHistoryRepository interactionHistoryRepository =
    InteractionHistoryRepository();
