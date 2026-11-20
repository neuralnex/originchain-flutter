import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/local/fingerprint_entry.dart';
import '../../services/sharing/firestore_share_service.dart';
import '../../services/sharing/neon_share_service.dart';
import '../../services/sharing/origin_manifest.dart';
import '../../services/sharing/publisher_identity_service.dart';
import '../../services/solana/origin_solana_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.onFingerprintReady,
    required this.onRegistered,
    required this.onOpenExisting,
    this.parentManifest,
    super.key,
  });

  final Future<void> Function(FingerprintEntry) onFingerprintReady;
  final VoidCallback onRegistered;
  final ValueChanged<String> onOpenExisting;
  final OriginManifest? parentManifest;

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
  OriginManifest? _pendingManifest;
  String? _pendingChainSignature;
  bool _isPublishing = false;
  bool _isUploading = false;
  String? _existingRecordId;
  OriginManifest? _suggestedParent;

  Future<void> _chooseFile() async {
    setState(() {
      _isHashing = true;
      _error = null;
      _fingerprint = null;
      _selectedFile = null;
      _pendingRecordId = null;
      _pendingManifest = null;
      _pendingChainSignature = null;
      _existingRecordId = null;
      _suggestedParent = null;
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
      String? existingRecordId;
      OriginManifest? suggestedParent;
      try {
        final records = await FirestoreShareService.instance.listOwnedRecords();
        for (final record in records) {
          final raw = record['manifest'];
          if (raw is! Map) continue;
          final manifest = OriginManifest.fromJson(Map<String, dynamic>.from(raw));
          if (manifest.sha256 == value.sha256) {
            existingRecordId = record['id'] as String?;
            break;
          }
          if (manifest.fileName.toLowerCase() == value.fileName.toLowerCase() &&
              (suggestedParent == null || manifest.createdAt.isAfter(suggestedParent.createdAt))) {
            suggestedParent = manifest;
          }
        }
      } catch (_) {
        // Local fingerprinting remains available while the index is offline.
      }
      if (!mounted) return;
      setState(() {
        _fingerprint = value;
        _selectedFile = file;
        _existingRecordId = existingRecordId;
        _suggestedParent = suggestedParent;
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

  Future<void> _register(FingerprintEntry fingerprint) async {
    if (_pendingRecordId != null) return;
    setState(() {
      _isPublishing = true;
      _error = null;
    });
    try {
      final manifest = _pendingManifest ??= await PublisherIdentityService
          .instance
          .createManifest(
            fingerprint,
            parent: widget.parentManifest ?? _suggestedParent,
            signerPublicKey: OriginSolanaService.instance.connectedPublicKey,
            externalSigner: OriginSolanaService.instance.signPublisherMessage,
          );
      _pendingChainSignature ??= await OriginSolanaService.instance
          .commitManifest(manifest);
      var recordId = _pendingRecordId;
      if (recordId == null) {
        recordId = await FirestoreShareService.instance.publish(
          manifest,
          solanaSignature: _pendingChainSignature!,
        );
        _pendingRecordId = recordId;
      }
      final link = Uri.https('gen-lang-client-0915748775.web.app', '/', {
        'record': recordId,
      });
      if (!mounted) return;
      setState(() => _shareUrl = link.toString());
      widget.onRegistered();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is StateError ? error.message : 'Could not register this file. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _shareProof() async {
    final link = _shareUrl;
    final fingerprint = _fingerprint;
    if (link == null || fingerprint == null) return;
    await SharePlus.instance.share(
      ShareParams(
        uri: Uri.parse(link),
        title: 'OriginChain provenance proof',
        subject: 'Verify ${fingerprint.fileName}',
      ),
    );
  }

  Future<void> _shareFile() async {
    final recordId = _pendingRecordId;
    final file = _selectedFile;
    final fingerprint = _fingerprint;
    if (recordId == null || file == null || fingerprint == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload a shareable copy?'),
        content: const Text('Anyone with the share link can download this copy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upload copy')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      await NeonShareService.instance.uploadFile(
        recordId: recordId,
        file: file,
        sha256: fingerprint.sha256,
      );
      await _shareProof();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not upload this copy. Your on-chain registration is safe; retry the upload.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isHashing ? null : _chooseFile,
                  icon: _isHashing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(
                    _isHashing ? 'Fingerprinting file…' : 'Choose a file',
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
              if (_fingerprint case final fingerprint?) ...[
                const SizedBox(height: 18),
                _FingerprintCard(
                  fingerprint: fingerprint,
                  shareUrl: _shareUrl,
                  isPublishing: _isPublishing,
                  isUploading: _isUploading,
                  isRegistered: _pendingRecordId != null,
                  existingRecordId: _existingRecordId,
                  comparison: _comparisonLabel(fingerprint),
                  onRegister: () => _register(fingerprint),
                  onOpenExisting: _existingRecordId == null
                      ? null
                      : () => widget.onOpenExisting(_existingRecordId!),
                  onShareProof: _shareProof,
                  onShareFile: _shareFile,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _comparisonLabel(FingerprintEntry fingerprint) {
    if (_existingRecordId != null) return 'Exact match · already registered';
    if (_pendingRecordId != null) return 'Fingerprint anchored on Solana';
    final parent = widget.parentManifest ?? _suggestedParent;
    if (parent != null && parent.sha256 != fingerprint.sha256) {
      return 'Changed from ${parent.fileName} · new version';
    }
    return 'New fingerprint';
  }
}

class _FingerprintCard extends StatelessWidget {
  const _FingerprintCard({
    required this.fingerprint,
    required this.isPublishing,
    required this.isUploading,
    required this.isRegistered,
    required this.comparison,
    required this.onRegister,
    required this.onOpenExisting,
    required this.onShareProof,
    required this.onShareFile,
    this.existingRecordId,
    this.shareUrl,
  });

  final FingerprintEntry fingerprint;
  final String? shareUrl;
  final bool isPublishing;
  final bool isUploading;
  final bool isRegistered;
  final String? existingRecordId;
  final String comparison;
  final VoidCallback onRegister;
  final VoidCallback? onOpenExisting;
  final VoidCallback onShareProof;
  final VoidCallback onShareFile;

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
                  existingRecordId != null
                      ? Icons.verified_rounded
                      : isRegistered
                      ? Icons.public_rounded
                      : Icons.fingerprint_rounded,
                  color: existingRecordId != null || isRegistered
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(comparison, style: theme.textTheme.titleMedium)),
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
            if (isRegistered) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onShareProof,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share proof link'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : onShareFile,
                  icon: isUploading
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(isUploading ? 'Uploading a copy…' : 'Upload a shareable copy'),
                ),
              ),
            ] else if (existingRecordId != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenExisting,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open existing proof'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isPublishing ? null : onRegister,
                icon: isPublishing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_rounded),
                label: Text(
                  isPublishing
                      ? 'Signing & anchoring…'
                      : 'Register fingerprint',
                ),
              ),
            ),
            ],
            if (shareUrl != null) ...[
              const SizedBox(height: 10),
              SelectableText('Proof link  $shareUrl', style: theme.textTheme.bodySmall),
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
