import 'package:flutter/material.dart';

import '../../data/local/fingerprint_entry.dart';
import '../../services/sharing/firestore_share_service.dart';
import '../../services/sharing/origin_manifest.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.lastFingerprint,
    required this.onRegisterTap,
    required this.onVerifyTap,
    required this.onFolderTap,
    required this.onRecordTap,
    super.key,
  });

  final FingerprintEntry? lastFingerprint;
  final VoidCallback onRegisterTap;
  final VoidCallback onVerifyTap;
  final ValueChanged<String?> onFolderTap;
  final ValueChanged<String> onRecordTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _data;
  bool _showReceived = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_HomeData> _load() async {
    final service = FirestoreShareService.instance;
    final results = await Future.wait([
      service.listFolders(),
      service.listOwnedRecords(),
      service.listReceivedRecords(),
    ]);
    return _HomeData(
      folders: results[0],
      shared: results[1],
      received: results[2],
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _data = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 112),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Your space', style: theme.textTheme.headlineMedium),
                    ),
                    IconButton(
                      tooltip: 'Scan or verify a file',
                      onPressed: widget.onVerifyTap,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _QuickActions(onRegister: widget.onRegisterTap, onVerify: widget.onVerifyTap),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Text('Folders', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    TextButton(
                      onPressed: () => widget.onFolderTap(null),
                      child: const Text('See files'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<_HomeData>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _FolderSkeletons();
                    }
                    if (snapshot.hasError) {
                      return _RetryCard(onRetry: _refresh);
                    }
                    final data = snapshot.data!;
                    if (data.folders.isEmpty) {
                      return _EmptyFolders(onOpenLibrary: () => widget.onFolderTap(null));
                    }
                    final width = MediaQuery.sizeOf(context).width;
                    final columns = width >= 900 ? 4 : width >= 600 ? 3 : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.folders.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.15,
                      ),
                      itemBuilder: (context, index) {
                        final folder = data.folders[index];
                        final folderId = folder['id'] as String;
                        final count = data.shared.where((record) => record['folderId'] == folderId).length;
                        return _FolderCard(
                          name: folder['name'] as String? ?? 'Folder',
                          count: count,
                          onTap: () => widget.onFolderTap(folderId),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text('Shared work', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('By you')),
                        ButtonSegment(value: true, label: Text('Received')),
                      ],
                      selected: {_showReceived},
                      onSelectionChanged: (value) => setState(() => _showReceived = value.first),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<_HomeData>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    if (snapshot.hasError) return _RetryCard(onRetry: _refresh);
                    final records = _showReceived ? snapshot.data!.received : snapshot.data!.shared;
                    if (records.isEmpty) {
                      return _EmptyWork(
                        received: _showReceived,
                        onVerify: widget.onVerifyTap,
                        onRegister: widget.onRegisterTap,
                      );
                    }
                    return Column(
                      children: [
                        for (final record in records.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _WorkRow(
                              record: record,
                              received: _showReceived,
                              onTap: () => widget.onRecordTap(record['id'] as String),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (widget.lastFingerprint != null) ...[
                  const SizedBox(height: 22),
                  Text('On this device', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _LocalFingerprint(entry: widget.lastFingerprint!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData({required this.folders, required this.shared, required this.received});
  final List<Map<String, dynamic>> folders;
  final List<Map<String, dynamic>> shared;
  final List<Map<String, dynamic>> received;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onRegister, required this.onVerify});
  final VoidCallback onRegister;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onRegister,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Register'),
            style: FilledButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onVerify,
            icon: Icon(Icons.fact_check_outlined, color: theme.colorScheme.primary),
            label: const Text('Verify'),
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18)),
          ),
        ),
      ],
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.name, required this.count, required this.onTap});
  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Icon(Icons.folder_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall)),
            Text('$count', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _FolderSkeletons extends StatelessWidget {
  const _FolderSkeletons();
  @override
  Widget build(BuildContext context) => const Row(children: [
    Expanded(child: Card(child: SizedBox(height: 62))),
    SizedBox(width: 10),
    Expanded(child: Card(child: SizedBox(height: 62))),
  ]);
}

class _EmptyFolders extends StatelessWidget {
  const _EmptyFolders({required this.onOpenLibrary});
  final VoidCallback onOpenLibrary;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.create_new_folder_outlined),
      title: const Text('Make a folder for your work'),
      trailing: const Icon(Icons.arrow_forward_rounded),
      onTap: onOpenLibrary,
    ),
  );
}

class _WorkRow extends StatelessWidget {
  const _WorkRow({required this.record, required this.received, required this.onTap});
  final Map<String, dynamic> record;
  final bool received;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final manifestData = record['manifest'];
    if (manifestData is! Map) return const SizedBox.shrink();
    final manifest = OriginManifest.fromJson(Map<String, dynamic>.from(manifestData));
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.primary,
          child: Icon(_fileIcon(manifest.fileName)),
        ),
        title: Text(manifest.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${received ? 'Received' : 'Shared'} · ${_short(manifest.sha256)}'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EmptyWork extends StatelessWidget {
  const _EmptyWork({required this.received, required this.onVerify, required this.onRegister});
  final bool received;
  final VoidCallback onVerify;
  final VoidCallback onRegister;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Icon(received ? Icons.inbox_outlined : Icons.share_outlined, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(received ? 'Files you save from a share link appear here.' : 'Share a registered file to see it here.')),
        IconButton(
          tooltip: received ? 'Open verification' : 'Register a file',
          onPressed: received ? onVerify : onRegister,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ]),
    ),
  );
}

class _RetryCard extends StatelessWidget {
  const _RetryCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.cloud_off_rounded),
      title: const Text('Could not sync your workspace'),
      trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded)),
    ),
  );
}

class _LocalFingerprint extends StatelessWidget {
  const _LocalFingerprint({required this.entry});
  final FingerprintEntry entry;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.fingerprint_rounded),
      title: Text(entry.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Local fingerprint · ${_short(entry.sha256)}'),
    ),
  );
}

String _short(String value) => '${value.substring(0, 16)}…';
IconData _fileIcon(String fileName) {
  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'}.contains(ext)) return Icons.image_rounded;
  if ({'mp4', 'mov', 'm4v', 'webm', 'avi'}.contains(ext)) return Icons.movie_rounded;
  if ({'mp3', 'wav', 'aac', 'm4a', 'flac'}.contains(ext)) return Icons.audio_file_rounded;
  return Icons.description_rounded;
}
