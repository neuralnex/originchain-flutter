import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';

import 'origin_manifest.dart';

class FirestoreShareService {
  FirestoreShareService._();

  static final instance = FirestoreShareService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _api = Dio();
  static const _apiUrl = String.fromEnvironment(
    'ORIGINCHAIN_API_URL',
    defaultValue: 'https://originchain-flutter.onrender.com',
  );

  Future<List<Map<String, dynamic>>> listOwnedRecords() async {
    return _listRecords('/v1/records');
  }

  Future<List<Map<String, dynamic>>> listReceivedRecords() async {
    return _listRecords('/v1/received');
  }

  Future<List<Map<String, dynamic>>> _listRecords(String path) async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    if (user == null) {
      throw StateError('Could not restore your publisher session.');
    }
    final token = await user.getIdToken();
    final response = await _api.get<Map<String, dynamic>>(
      '$_apiUrl$path',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final records = response.data?['records'];
    if (records is! List) {
      throw const FormatException('Invalid Library response.');
    }
    return records
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listFolders() async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    if (user == null) throw StateError('Could not restore your publisher session.');
    final token = await user.getIdToken();
    final response = await _api.get<Map<String, dynamic>>(
      '$_apiUrl/v1/folders',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final folders = response.data?['folders'];
    if (folders is! List) throw const FormatException('Invalid folders response.');
    return folders.whereType<Map>().map((folder) => Map<String, dynamic>.from(folder)).toList();
  }

  Future<Map<String, dynamic>> createFolder(String name) async {
    return _authorizedPost('/v1/folders', {'name': name});
  }

  Future<void> assignRecordToFolder(String recordId, String? folderId) async {
    await _authorizedPost('/v1/records/$recordId/folder', {'folderId': folderId});
  }

  Future<void> saveReceivedRecord(String recordId) async {
    await _authorizedPost('/v1/received/$recordId', const {});
  }

  Future<List<Map<String, dynamic>>> readPublicHistory(String recordId) async {
    final response = await _api.get<Map<String, dynamic>>(
      '$_apiUrl/v1/records/$recordId/history',
    );
    final versions = response.data?['versions'];
    if (versions is! List) throw const FormatException('Invalid history response.');
    return versions
        .whereType<Map>()
        .map((version) => Map<String, dynamic>.from(version))
        .toList();
  }

  Future<Map<String, dynamic>> _authorizedPost(String path, Object body) async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    if (user == null) throw StateError('Could not restore your publisher session.');
    final token = await user.getIdToken();
    final response = await _api.post<Map<String, dynamic>>(
      '$_apiUrl$path',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data ?? const {};
  }

  Future<String> publish(
    OriginManifest manifest, {
    required String solanaSignature,
  }) async {
    var user = _auth.currentUser;
    user ??= (await _auth.signInAnonymously()).user;
    if (user == null) throw StateError('Could not create a publisher session.');

    final record = _firestore.collection('sharedRecords').doc();
    await record.set({
      'schema': 'originchain.share.v1',
      'ownerUid': user.uid,
      'createdAt': Timestamp.fromDate(manifest.createdAt),
      'manifest': {
        ...manifest.toJson(),
        // Receipt is envelope metadata; OriginManifest.toJson excludes it so
        // the signed manifest bytes remain identical to the on-chain hash.
        'solana': {
          'cluster': 'devnet',
          'programId': 'EbePt3vR4pp9WRuY6hAfhchTfAPs1nNVsJYyurXajUPB',
          'transactionSignature': solanaSignature,
        },
      },
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

  Future<Map<String, dynamic>?> readSolanaReceipt(String recordId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{10,40}$').hasMatch(recordId)) return null;
    final snapshot = await _firestore
        .collection('sharedRecords')
        .doc(recordId)
        .get();
    final value = (snapshot.data()?['manifest'] as Map?)?['solana'];
    return value is Map<String, dynamic> ? value : null;
  }
}
