import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';
import 'team_service.dart';

class NotificationsService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> get _workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  CollectionReference<Map<String, dynamic>> get _notificationsCol =>
      _workspaceRef.collection('notifications');

  Stream<List<AppNotification>> notificationsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<List<AppNotification>>.value(const []);
    return _notificationsCol
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(AppNotification.fromFirestore).toList());
  }

  Stream<int> unreadCountStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<int>.value(0);
    return _notificationsCol
        .where('uid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.size);
  }

  Future<void> createNotification({
    required String uid,
    required String title,
    required String body,
    required String entityType,
    required String entityId,
  }) {
    return _notificationsCol.add({
      'uid': uid,
      'title': title,
      'body': body,
      'entityType': entityType,
      'entityId': entityId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markRead(String id) {
    return _notificationsCol.doc(id).set({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAllRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final unread = await _notificationsCol
        .where('uid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .limit(450)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.set(
        doc.reference,
        {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
