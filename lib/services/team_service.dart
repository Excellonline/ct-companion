import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/team_member.dart';

const cardTroveWorkspaceId = 'cardtrove-team';

class TeamActor {
  final String uid;
  final String email;
  final String displayName;

  TeamActor({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  String get label {
    final trimmed = displayName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return email.isNotEmpty ? email : 'Team member';
  }

  Map<String, dynamic> createdAuditFields() => {
        'createdByUid': uid,
        'createdByEmail': email,
        'createdByName': label,
      };

  Map<String, dynamic> updatedAuditFields() => {
        'updatedByUid': uid,
        'updatedByEmail': email,
        'updatedByName': label,
      };
}

class TeamService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> get workspaceRef =>
      _db.collection('workspaces').doc(cardTroveWorkspaceId);

  CollectionReference<Map<String, dynamic>> get membersCol =>
      workspaceRef.collection('members');

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    return user;
  }

  TeamActor currentActor() {
    final user = _user;
    final email = user.email ?? '';
    return TeamActor(
      uid: user.uid,
      email: email,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : _nameFromEmail(email),
    );
  }

  Stream<TeamMember?> currentMemberStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream<TeamMember?>.value(null);
    return membersCol.doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TeamMember.fromFirestore(doc);
    });
  }

  Stream<List<TeamMember>> membersStream() => membersCol
      .orderBy('displayName')
      .snapshots()
      .map((s) => s.docs.map(TeamMember.fromFirestore).toList());

  Future<void> ensureMemberProfile() async {
    final user = _user;
    final actor = currentActor();
    final now = FieldValue.serverTimestamp();

    final ref = membersCol.doc(user.uid);
    final profileUpdate = {
      'email': actor.email,
      'displayName': actor.label,
      'lastSeenAt': now,
      'updatedAt': now,
    };

    await _touchWorkspace(now);

    try {
      await ref.update(profileUpdate);
    } on FirebaseException catch (e) {
      if (e.code != 'not-found' && e.code != 'permission-denied') {
        rethrow;
      }
      await _createMemberProfile(ref, now, profileUpdate);
    }

    await _waitForCommittedMemberProfile(ref);
  }

  Future<void> _createMemberProfile(
    DocumentReference<Map<String, dynamic>> ref,
    FieldValue now,
    Map<String, dynamic> profileUpdate,
  ) async {
    await ref.set({
      ...profileUpdate,
      'role': TeamRole.member.id,
      'createdAt': now,
    });
  }

  Future<void> _touchWorkspace(FieldValue now) async {
    try {
      await workspaceRef.set({
        'name': 'CardTrove',
        'updatedAt': now,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
  }

  Future<void> _waitForCommittedMemberProfile(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    FirebaseException? lastError;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        final doc = await ref.get(const GetOptions(source: Source.server));
        if (doc.exists) return;
      } on FirebaseException catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (lastError != null) throw lastError;
    throw StateError('Member profile was not confirmed by Firestore.');
  }

  Future<void> setMemberRole(String uid, TeamRole role) async {
    await membersCol.doc(uid).set({
      'role': role.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> approveMember(String uid) async {
    await setMemberRole(uid, TeamRole.member);
  }

  Future<void> updateMemberDisplayName(String uid, String displayName) async {
    await membersCol.doc(uid).set({
      'displayName': displayName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateCurrentUserDisplayName(String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    final user = _user;
    await user.updateDisplayName(trimmed);
    await user.reload();
    await updateMemberDisplayName(user.uid, trimmed);
  }

  Future<void> removeMember(String uid) async {
    await membersCol.doc(uid).delete();
  }

  String _nameFromEmail(String email) {
    final name = email.split('@').first.trim();
    return name.isEmpty ? 'Team member' : name;
  }
}
