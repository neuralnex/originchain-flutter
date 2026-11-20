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
  const VerifyScreen({this.recordId, this.onSavedToHome, super.key});

  final String? recordId;
  final VoidCallback? onSavedToHome;

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
  List<Map<String, dynamic>> _history = const [];
  bool _savingToHome = false;
  bool _savedToHome = false;

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
      _history = const [];
      _savedToHome = false;
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
      var history = <Map<String, dynamic>>[];
      try {
        history = await FirestoreShareService.instance.readPublicHistory(recordId);
      } catch (_) {
        history = [
          {'id': recordId, 'manifest': manifest.toJson()},
        ];
      }
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
          _history = history;
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

  Future<void> _saveToHome() async {
    final recordId = _loadedRecordId;
    if (recordId == null) return;
    setState(() => _savingToHome = true);
    try {
      await FirestoreShareService.instance.saveReceivedRecord(recordId);
      widget.onSavedToHome?.call();
      if (mounted) {
        setState(() => _savedToHome = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to your received work')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this record. It may already be in your shared work.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingToHome = false);
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
      final digestValue = digest.toString();
      final matchingIndex = _history.indexWhere((record) {
        final raw = record['manifest'];
        return raw is Map && raw['file'] is Map && raw['file']['hash'] == digestValue;
      });
      setState(() {
        if (matchingIndex < 0) {
          _fileResult = 'No registered version matches. The file may have changed or may never have been registered; this check alone cannot tell which.';
        } else if (_manifestFromRecord(_history[matchingIndex]).versionId == manifest.versionId) {
          _fileResult = 'Exact match · these bytes match the selected registered version.';
        } else {
          final matched = _manifestFromRecord(_history[matchingIndex]);
          _fileResult = 'Matches another registered version: ${matched.fileName} · ${_shortHash(matched.versionId)}. It differs from the version in this link.';
        }
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
                'See what this file matches and what changed.',
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
                          labelText: 'Share link or record ID',
                          hintText: 'Paste a proof link',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _loadRecord(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadingRecord ? null : () => _loadRecord(),
                        child: Text(
                          _loadingRecord ? 'Loading proof…' : 'Check proof',
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
                        Row(children: [
                          Icon(Icons.verified_user_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 7),
                          const Text('Publisher signature valid'),
                        ]),
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
                        ] else ...[
                          Text(
                            'Proof only · original file was not shared',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: _savingToHome || _savedToHome ? null : _saveToHome,
                          icon: _savingToHome
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(_savedToHome ? Icons.check_rounded : Icons.add_to_drive_rounded),
                          label: Text(_savedToHome ? 'Saved to received work' : 'Save to your home'),
                        ),
                        const SizedBox(height: 8),
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
                              color: _fileResult!.startsWith('Exact match') ||
                                      _fileResult!.startsWith('Matches another')
                                  ? theme.colorScheme.primary
                                  : _fileResult!.startsWith('Could not')
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              if (_manifest != null) ...[
                const SizedBox(height: 20),
                _ProvenanceStory(history: _history, selected: _manifest!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

OriginManifest _manifestFromRecord(Map<String, dynamic> record) {
  final raw = record['manifest'];
  if (raw is! Map) throw const FormatException('Invalid provenance version.');
  return OriginManifest.fromJson(Map<String, dynamic>.from(raw));
}

String _shortHash(String value) => value.length < 10
    ? value
    : '${value.substring(0, 8)}…${value.substring(value.length - 4)}';

class _ProvenanceStory extends StatelessWidget {
  const _ProvenanceStory({required this.history, required this.selected});

  final List<Map<String, dynamic>> history;
  final OriginManifest selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versions = <OriginManifest>[];
    for (final record in history) {
      try {
        versions.add(_manifestFromRecord(record));
      } on FormatException {
        continue;
      }
    }
    versions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File story', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            for (var i = 0; i < versions.length; i++) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Icon(
                    versions[i].versionId == selected.versionId
                        ? Icons.radio_button_checked_rounded
                        : Icons.check_circle_rounded,
                    size: 19,
                    color: theme.colorScheme.primary,
                  ),
                  if (i != versions.length - 1)
                    Container(width: 2, height: 34, color: theme.colorScheme.outlineVariant),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i == 0 ? 'First registered version' : 'Changed version', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text('${versions[i].fileName} · ${_shortHash(versions[i].versionId)}', style: theme.textTheme.bodySmall),
                    Text(_formatDate(versions[i].createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ]),
                )),
              ]),
            ],
            Text(
              'This history shows registered versions. Unregistered edits may not appear here.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} · ${two(local.hour)}:${two(local.minute)}';
}
