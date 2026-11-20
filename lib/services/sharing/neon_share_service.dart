import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

class NeonShareService {
  NeonShareService._();

  static final instance = NeonShareService._();
  static const _baseUrl = String.fromEnvironment(
    'ORIGINCHAIN_API_URL',
    defaultValue: 'https://originchain-flutter.onrender.com',
  );
  final Dio _dio = Dio();

  Future<void> uploadFile({
    required String recordId,
    required PlatformFile file,
    required String sha256,
  }) async {
    if (_baseUrl.isEmpty) {
      throw StateError(
        'Set ORIGINCHAIN_API_URL to your deployed OriginChain API before uploading files.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before uploading a file.');
    final token = await user.getIdToken();
    if (token == null) throw StateError('Could not authenticate the upload.');

    final contentType = _contentType(file.name);
    final sizeBytes = await file.length() ?? 0;
    final request = {
      'sha256': sha256,
      'sizeBytes': sizeBytes,
      'contentType': contentType,
    };
    final headers = {'Authorization': 'Bearer $token'};
    final upload = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/v1/shares/$recordId/upload-url',
      data: request,
      options: Options(headers: headers),
    );
    final data = upload.data!;
    final objectKey = data['objectKey'] as String;
    final uploadUrl = data['uploadUrl'] as String;
    final requiredHeaders = Map<String, dynamic>.from(data['headers'] as Map);
    await _dio.put<void>(
      uploadUrl,
      data: file.readAsByteStream(),
      options: Options(
        headers: {...requiredHeaders, Headers.contentLengthHeader: sizeBytes},
        contentType: contentType,
        responseType: ResponseType.plain,
      ),
    );
    await _dio.post<void>(
      '$_baseUrl/v1/shares/$recordId/finalize',
      queryParameters: {'objectKey': objectKey},
      data: request,
      options: Options(headers: headers),
    );
  }

  Future<Uri> createDownloadLink(String recordId) async {
    if (_baseUrl.isEmpty) {
      throw StateError(
        'The OriginChain API is not configured for file downloads.',
      );
    }
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/v1/shares/$recordId/download-url',
    );
    final value = response.data?['downloadUrl'];
    if (value is! String) {
      throw StateError('No file is attached to this record.');
    }
    return Uri.parse(value);
  }

  static String _contentType(String name) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    const types = {
      'pdf': 'application/pdf',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mp3': 'audio/mpeg',
      'txt': 'text/plain',
      'json': 'application/json',
    };
    return types[extension] ?? 'application/octet-stream';
  }
}
