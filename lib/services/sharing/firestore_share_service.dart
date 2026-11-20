import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'origin_manifest.dart';

class FirestoreShareService {
  FirestoreShareService._();

  static final instance = FirestoreShareService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<String> publish(OriginManifest manifest) async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    if (user == null) throw StateError('Could not create a publisher session.');

    final record = _firestore.collection('sharedRecords').doc();
    await record.set({
      'schema': 'originchain.share.v1',
      'ownerUid': user.uid,
      'createdAt': Timestamp.fromDate(manifest.createdAt),
      'manifest': manifest.toJson(),
      'fileStorage': null,
    });
    return record.id;
  }

  Future<OriginManifest> readPublicRecord(String recordId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{10,40}$').hasMatch(recordId)) {
      throw const FormatException('That share link is not valid.');
    }
    final snapshot = await _firestore
        .collection('sharedRecords')
        .doc(recordId)
        .get();
    final data = snapshot.data();
    if (!snapshot.exists ||
        data == null ||
        data['schema'] != 'originchain.share.v1') {
      throw StateError('This share record could not be found.');
    }
    return OriginManifest.fromJson(data['manifest']);
  }

  Future<Map<String, dynamic>?> readFileObject(String recordId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{10,40}$').hasMatch(recordId)) return null;
    final snapshot = await _firestore
        .collection('sharedRecords')
        .doc(recordId)
        .get();
    final value = snapshot.data()?['fileStorage'];
    return value is Map<String, dynamic> && value['provider'] == 'neon'
        ? value
        : null;
  }
}
