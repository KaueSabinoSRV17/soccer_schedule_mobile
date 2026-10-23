import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/schedule.dart';
import 'live_review_repository.dart';
import 'review_codec.dart';
import 'review_repository.dart';

class FirestoreReviewRepository implements LiveReviewRepository {
  FirestoreReviewRepository(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  DocumentReference<Map<String, dynamic>> _review(String id) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(id)) {
      throw const FormatException('Invalid review ID');
    }
    return db.collection('dailyReviews').doc(id);
  }

  @override
  Future<DailyReview> loadReview() async {
    final current = await db
        .doc('state/current')
        .get(const GetOptions(source: Source.server));
    final id = current.data()?['reviewId'];
    if (id is! String) {
      throw const ReviewUnavailable(
        'A análise diária ainda não está disponível.',
      );
    }
    return loadReviewById(id);
  }

  @override
  Future<DailyReview> loadReviewById(String id) async {
    final snapshot = await _review(id)
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) {
      throw const ReviewUnavailable('Esta análise não está disponível.');
    }
    return decodeReview(id, data);
  }

  ReviewChoices? _choices(Map<String, dynamic>? data) => data == null
      ? null
      : ReviewChoices(
          selectedIds: (data['selectedIds'] as List<dynamic>)
              .cast<int>()
              .toSet(),
          skippedGroups: (data['skippedGroupIds'] as List<dynamic>)
              .cast<String>()
              .toSet(),
        );

  @override
  Future<ReviewChoices?> loadChoices(DailyReview review) async {
    final parent = await _review(review.id)
        .get(const GetOptions(source: Source.server));
    final accepted = parent.data()?['acceptedSubmissionId'];
    if (accepted is String) {
      return _choices(
        (await _review(
          review.id,
        ).collection('submissions').doc(accepted).get()).data(),
      );
    }
    final latest = await _review(review.id)
        .collection('submissions')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    return latest.docs.isEmpty ? null : _choices(latest.docs.first.data());
  }

  @override
  Future<void> saveChoices(DailyReview review, ReviewChoices choices) async {
    final user = auth.currentUser;
    if (user?.email == null || !user!.emailVerified) {
      throw StateError('Authentication required');
    }
    final ref = _review(review.id).collection('submissions').doc();
    // Transactions fail offline instead of leaving an invisible queued write.
    await db.runTransaction((transaction) async {
      final parent = await transaction.get(_review(review.id));
      if (parent.data()?['status'] != 'ready' ||
          parent.data()?['revision'] != review.revision ||
          parent.data()?['acceptedSubmissionId'] != null) {
        throw const ReviewUnavailable(
          'Esta análise já foi enviada ou mudou. Atualize a tela.',
        );
      }
      transaction.set(ref, {
        'reviewRevision': review.revision,
        'selectedIds': choices.selectedIds.toList()..sort(),
        'skippedGroupIds': choices.skippedGroups.toList()..sort(),
        'ownerEmail': user.email!.toLowerCase(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }, timeout: const Duration(seconds: 20));
  }

  @override
  Stream<ReviewSyncState> watchSubmission(DailyReview review) {
    late StreamController<ReviewSyncState> stream;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? parent;
    StreamSubscription<dynamic>? submission;
    String? watched;
    void emit(Map<String, dynamic>? data) {
      final name = data?['status'];
      final status =
          ReviewSyncStatus.values.where((s) => s.name == name).firstOrNull ??
          ReviewSyncStatus.draft;
      stream.add(ReviewSyncState(status, choices: _choices(data)));
    }

    stream = StreamController<ReviewSyncState>(
      onListen: () {
        parent = _review(review.id).snapshots().listen((snapshot) {
          final accepted = snapshot.data()?['acceptedSubmissionId'] as String?;
          final key = accepted ?? 'latest';
          if (watched == key) return;
          watched = key;
          final previous = submission;
          if (previous != null) unawaited(previous.cancel());
          if (accepted != null) {
            submission = _review(review.id)
                .collection('submissions')
                .doc(accepted)
                .snapshots()
                .listen((doc) {
                  if (watched == key) emit(doc.data());
                }, onError: stream.addError);
          } else {
            submission = _review(review.id)
                .collection('submissions')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .snapshots()
                .listen((query) {
                  if (watched == key) {
                    emit(query.docs.isEmpty ? null : query.docs.first.data());
                  }
                }, onError: stream.addError);
          }
        }, onError: stream.addError);
      },
      onCancel: () async {
        await parent?.cancel();
        await submission?.cancel();
      },
    );
    return stream.stream;
  }

  @override
  Future<void> clearChoices(DailyReview review) =>
      throw UnsupportedError('Live submissions are immutable');
}
