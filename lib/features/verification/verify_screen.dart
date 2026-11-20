import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/sharing/firestore_share_service.dart';
import '../../services/sharing/origin_manifest.dart';
import '../../services/sharing/publisher_identity_service.dart';
import '../../services/sharing/neon_share_service.dart';
import '../../services/solana/origin_solana_service.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({this.recordId, super.key});

  final String? recordId;

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _recordController = TextEditingController();
  OriginManifest? _manifest;
  String? _recordError;
  String? _fileResult;
  bool _loadingRecord = false;
  bool _checkingFile = false;
  bool _openingDownload = false;
  bool _hasSharedFile = false;
  String? _loadedRecordId;
  String? _solanaStatus;

  @override
  void initState() {
    super.initState();
    final recordId = widget.recordId;
    if (recordId != null) {
      _recordController.text = recordId;
      _loadRecord(recordId);
    }
  }

  @override
  void dispose() {
    _recordController.dispose();
    super.dispose();
  }

  Future<void> _loadRecord([String? value]) async {
    final supplied = (value ?? _recordController.text).trim();
    final parsedUri = Uri.tryParse(supplied);
    final recordId = parsedUri?.queryParameters['record'] ?? supplied;
    if (recordId.isEmpty) return;
    setState(() {
      _loadingRecord = true;
      _recordError = null;
      _fileResult = null;
      _manifest = null;
      _solanaStatus = null;
    });
    try {
      final manifest = await FirestoreShareService.instance.readPublicRecord(
        recordId,
      );
      final signatureValid = await PublisherIdentityService.instance.verify(
        manifest,
      );
      if (!signatureValid) throw StateError('The record signature is invalid.');
      final fileObject = await FirestoreShareService.instance.readFileObject(
        recordId,
      );
      final receipt = await FirestoreShareService.instance.readSolanaReceipt(
        recordId,
      );
      var solanaStatus = 'No Solana transaction is attached to this record.';
      if (receipt != null &&
          receipt['cluster'] == 'devnet' &&
          receipt['programId'] == OriginSolanaService.programId &&
          receipt['transactionSignature'] is String) {
        try {
          final result = await OriginSolanaService.instance
              .verifyManifestReceipt(
                manifest,
                receipt['transactionSignature'] as String,
              );
          solanaStatus = result['verified'] == true
              ? 'Verified on Solana devnet · slot ${result['slot']}'
              : 'Solana transaction does not match this manifest.';
        } catch (_) {
          solanaStatus = 'Could not check the Solana transaction right now.';
        }
      }
      if (mounted) {
        setState(() {
          _manifest = manifest;
          _hasSharedFile = fileObject != null;
          _loadedRecordId = recordId;
          _solanaStatus = solanaStatus;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _recordError = error is StateError
              ? error.message
              : error is FormatException
              ? error.message
              : 'Could not load that share record. Check the link and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingRecord = false);
    }
  }

  Future<void> _downloadSharedFile() async {
    final recordId = _loadedRecordId;
    if (recordId == null) return;
    setState(() => _openingDownload = true);
    try {
      final link = await NeonShareService.instance.createDownloadLink(recordId);
      final opened = await launchUrl(
        link,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Could not open the file download.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _fileResult = error is StateError
              ? error.message
              : 'Could not create the file download. Try again later.';
        });
      }
    } finally {
      if (mounted) setState(() => _openingDownload = false);
    }
  }

  Future<void> _compareFile() async {
    final manifest = _manifest;
    if (manifest == null) return;
    setState(() {
      _checkingFile = true;
      _fileResult = null;
    });
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      final selected = files.first;
      final digest = await sha256.bind(selected.readAsByteStream()).first;
      if (!mounted) return;
      setState(() {
        _fileResult = digest.toString() == manifest.sha256
            ? 'Match: this file has the fingerprint in the signed record.'
            : 'No match: this file differs from the fingerprint in the record.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _fileResult = 'Could not read that file. Try another.');
      }
    } finally {
      if (mounted) setState(() => _checkingFile = false);
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
              Text('Verify', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Check a shared fingerprint record, then compare it with a file.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _recordController,
                        decoration: const InputDecoration(
                          labelText: 'Share record ID',
                          hintText: 'Paste an OriginChain share link or ID',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _loadRecord(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadingRecord ? null : () => _loadRecord(),
                        child: Text(
                          _loadingRecord ? 'Loading record…' : 'Load record',
                        ),
                      ),
                      if (_recordError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _recordError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      if (_manifest case final manifest?) ...[
                        const Divider(height: 24),
                        Text(
                          manifest.fileName,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text('Signed device identity · signature valid'),
                        const SizedBox(height: 5),
                        Text(_solanaStatus ?? 'Checking Solana registration…'),
                        const SizedBox(height: 8),
                        SelectableText(
                          'SHA-256  ${manifest.sha256}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_hasSharedFile) ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _openingDownload
                                  ? null
                                  : _downloadSharedFile,
                              icon: _openingDownload
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded),
                              label: Text(
                                _openingDownload
                                    ? 'Preparing download…'
                                    : 'Download shared file',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: _checkingFile ? null : _compareFile,
                          icon: _checkingFile
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_open_outlined),
                          label: Text(
                            _checkingFile ? 'Checking file…' : 'Compare a file',
                          ),
                        ),
                        if (_fileResult != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _fileResult!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _fileResult!.startsWith('Match:')
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'The Solana result above checks whether this manifest is committed on devnet. The publisher key is self-issued and is not linked to a verified person or wallet.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 212,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -24,
                      top: -32,
                      child: Icon(
                        Icons.blur_on_rounded,
                        size: 190,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.76,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 42,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'What verification checks',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const _VerifyDetail(
                icon: Icons.fingerprint_rounded,
                title: 'File fingerprint',
                body: 'Whether the selected content matches the fingerprint in a record.',
              ),
              const SizedBox(height: 10),
              const _VerifyDetail(
                icon: Icons.draw_outlined,
                title: 'Publisher signature',
                body: 'Whether the record was signed by the identity it names.',
              ),
              const SizedBox(height: 10),
              const _VerifyDetail(
                icon: Icons.link_rounded,
                title: 'Solana commitment',
                body: 'Whether the provenance commitment can be found and checked on-chain.',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'The share record is publicly readable. Matching the fingerprint proves the bytes match that record; it does not prove legal ownership or authorship.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerifyDetail extends StatelessWidget {
  const _VerifyDetail({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(body),
        isThreeLine: true,
      ),
    );
  }
}
