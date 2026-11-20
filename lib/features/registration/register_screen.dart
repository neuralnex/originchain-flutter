import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/local/fingerprint_entry.dart';
import '../../services/sharing/firestore_share_service.dart';
import '../../services/sharing/neon_share_service.dart';
import '../../services/sharing/publisher_identity_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.onFingerprintReady, super.key});

  final Future<void> Function(FingerprintEntry) onFingerprintReady;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isHashing = false;
  String? _error;
  FingerprintEntry? _fingerprint;
  PlatformFile? _selectedFile;
  String? _shareUrl;
  String? _pendingRecordId;
  bool _isPublishing = false;

  Future<void> _chooseFile() async {
    setState(() {
      _isHashing = true;
      _error = null;
      _fingerprint = null;
      _selectedFile = null;
      _pendingRecordId = null;
    });
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) {
        if (mounted) setState(() => _isHashing = false);
        return;
      }

      final file = files.first;
      final digest = await sha256.bind(file.readAsByteStream()).first;
      final value = FingerprintEntry(
        fileName: file.name,
        sizeBytes: await file.length() ?? 0,
        sha256: digest.toString(),
        createdAtUtc: DateTime.now().toUtc(),
      );
      if (!mounted) return;
      setState(() {
        _fingerprint = value;
        _selectedFile = file;
        _isHashing = false;
      });
      await widget.onFingerprintReady(value);
    } on _FingerprintException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _isHashing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'We could not read that file. Choose another file and try again.';
          _isHashing = false;
        });
      }
    }
  }

  Future<void> _publishAndShare(FingerprintEntry fingerprint) async {
    setState(() {
      _isPublishing = true;
      _error = null;
    });
    try {
      var recordId = _pendingRecordId;
      if (recordId == null) {
        final manifest = await PublisherIdentityService.instance.createManifest(
          fingerprint,
        );
        recordId = await FirestoreShareService.instance.publish(manifest);
        _pendingRecordId = recordId;
      }
      final file = _selectedFile;
      if (file == null) {
        throw StateError('Choose the file again before sharing.');
      }
      await NeonShareService.instance.uploadFile(
        recordId: recordId,
        file: file,
        sha256: fingerprint.sha256,
      );
      _pendingRecordId = null;
      final link = Uri.https('gen-lang-client-0915748775.web.app', '/', {
        'record': recordId,
      });
      if (!mounted) return;
      setState(() => _shareUrl = link.toString());
      await SharePlus.instance.share(
        ShareParams(
          uri: link,
          title: 'OriginChain file fingerprint',
          subject: 'Verify ${fingerprint.fileName}',
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is StateError ? error.message : 'Could not publish and upload this file. Check the API connection, Firebase Anonymous Authentication, Firestore, and Neon configuration.';
        });
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 128),
          sliver: SliverList.list(
            children: [
              Text('Register', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Create a SHA-256 fingerprint on this device. Choose when to upload the file for sharing.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _HowItWorks(),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Private by default',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The file is fingerprinted locally first. Upload happens only when you tap Upload file & share.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isHashing ? null : _chooseFile,
                          icon: _isHashing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file_rounded),
                          label: Text(
                            _isHashing
                                ? 'Fingerprinting file…'
                                : 'Choose a file',
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_fingerprint case final fingerprint?) ...[
                const SizedBox(height: 18),
                _FingerprintCard(
                  fingerprint: fingerprint,
                  shareUrl: _shareUrl,
                  isPublishing: _isPublishing,
                  onPublish: () => _publishAndShare(fingerprint),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const steps = [
      ('01', 'Choose a file', 'Pick content from this device.'),
      (
        '02',
        'Fingerprint locally',
        'SHA-256 reads the file without uploading it.',
      ),
      (
        '03',
        'Review before registering',
        'You choose if and when to publish a record.',
      ),
    ];
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.primary,
                child: Text(
                  steps[index].$1,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              title: Text(steps[index].$2),
              subtitle: Text(steps[index].$3),
            ),
          ),
          if (index < steps.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _FingerprintCard extends StatelessWidget {
  const _FingerprintCard({
    required this.fingerprint,
    required this.isPublishing,
    required this.onPublish,
    this.shareUrl,
  });

  final FingerprintEntry fingerprint;
  final String? shareUrl;
  final bool isPublishing;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Text('Fingerprint ready', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            Text(fingerprint.fileName, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 3),
            Text(
              _formatBytes(fingerprint.sizeBytes),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              fingerprint.sha256,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This uploads the original file to private Neon Object Storage. The public Firestore record includes its name, size, fingerprint, and device-key signature. Anyone with the share link can download the file. This record is not on Solana yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isPublishing ? null : onPublish,
                icon: isPublishing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_rounded),
                label: Text(
                  isPublishing
                      ? 'Uploading & publishing…'
                      : 'Upload file & share',
                ),
              ),
            ),
            if (shareUrl != null) ...[
              const SizedBox(height: 10),
              SelectableText(shareUrl!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _FingerprintException implements Exception {
  const _FingerprintException(this.message);

  final String message;
}
