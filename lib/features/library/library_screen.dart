import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/sharing/firestore_share_service.dart';
import '../../services/sharing/origin_manifest.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.onRegisterTap,
    required this.onNewVersion,
    this.initialFolderId,
    super.key,
  });

  final VoidCallback onRegisterTap;
  final ValueChanged<OriginManifest> onNewVersion;
  final String? initialFolderId;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<Map<String, dynamic>>> _records;
  late Future<List<Map<String, dynamic>>> _folders;
  String? _folderId;
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _folderId = widget.initialFolderId;
    _load();
  }

  void _load() {
    _records = FirestoreShareService.instance.listOwnedRecords();
    _folders = FirestoreShareService.instance.listFolders();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_records, _folders]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create folder',
        onPressed: _createFolder,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 100),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Your files', style: theme.textTheme.headlineMedium),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _folders,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const SizedBox(height: 44, child: Center(child: LinearProgressIndicator()));
                      }
                      final folders = snapshot.data ?? const [];
                      if (snapshot.hasError) {
                        return TextButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Folders unavailable · retry'),
                        );
                      }
                      if (folders.isEmpty) {
                        return OutlinedButton.icon(
                          onPressed: _createFolder,
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('Create your first folder'),
                        );
                      }
                      return SizedBox(
                        height: 86,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: folders.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _FolderTile(
                                name: 'All files',
                                count: null,
                                selected: _folderId == null,
                                onTap: () => setState(() => _folderId = null),
                              );
                            }
                            final folder = folders[index - 1];
                            return _FolderTile(
                              name: folder['name'] as String? ?? 'Folder',
                              count: null,
                              selected: _folderId == folder['id'],
                              onTap: () => setState(() => _folderId = folder['id'] as String),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final category in const ['All', 'Photos', 'Videos', 'Documents', 'Audio']) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: _category == category,
                              onSelected: (_) => setState(() => _category = category),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _records,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 64),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return _EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Can’t load your files',
                          detail: 'Check your connection and retry.',
                          action: 'Retry',
                          onPressed: _refresh,
                        );
                      }
                      final grouped = <String, List<Map<String, dynamic>>>{};
                      for (final record in snapshot.data ?? const []) {
                        if (record['folderId'] != _folderId) continue;
                        final manifestData = record['manifest'];
                        if (manifestData is! Map) continue;
                        try {
                          final manifest = OriginManifest.fromJson(
                            Map<String, dynamic>.from(manifestData),
                          );
                          if (!_matchesCategory(manifest.fileName, _category)) continue;
                          grouped.putIfAbsent(manifest.assetId, () => []).add(record);
                        } on FormatException {
                          continue;
                        }
                      }
                      if (grouped.isEmpty) {
                        return _EmptyState(
                          icon: _category == 'All' ? Icons.folder_open_rounded : _categoryIcon(_category),
                          title: 'Nothing here yet',
                          detail: _folderId == null
                              ? 'Register a file or choose another filter.'
                              : 'Move a file here from its asset menu.',
                          action: 'Register file',
                          onPressed: widget.onRegisterTap,
                        );
                      }
                      final assets = grouped.values.toList()
                        ..sort((a, b) => _createdAt(b.first).compareTo(_createdAt(a.first)));
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 700 ? 3 : 2;
                          final gap = 12.0;
                          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final versions in assets)
                                SizedBox(
                                  width: width,
                                  child: _AssetTile(
                                    records: versions,
                                    onOpen: () => _showHistory(context, versions),
                                    onNewVersion: () => widget.onNewVersion(_manifest(versions.first)),
                                    onMove: () => _chooseFolder(context, versions),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Folder name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await FirestoreShareService.instance.createFolder(name);
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().contains('409') ? 'A folder with that name already exists.' : 'Could not create folder. Try again.')),
        );
      }
    }
  }

  Future<void> _chooseFolder(BuildContext context, List<Map<String, dynamic>> records) async {
    final folders = await _folders;
    if (!context.mounted) return;
    final choice = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const ListTile(title: Text('Move to folder')),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Remove from folder'),
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final folder in folders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder['name'] as String? ?? 'Folder'),
                onTap: () => Navigator.pop(context, folder['id'] as String?),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final folderId = choice.isEmpty ? null : choice;
    try {
      for (final record in records) {
        final recordId = record['id'] as String?;
        if (recordId != null) {
          await FirestoreShareService.instance.assignRecordToFolder(recordId, folderId);
        }
      }
      await _refresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not move these files. Try again.')),
        );
      }
    }
  }

  Future<void> _showHistory(BuildContext context, List<Map<String, dynamic>> records) async {
    final sorted = [...records]..sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version history', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final record = sorted[index];
                    final manifest = _manifest(record);
                    final receipt = (manifestData(record)['solana'] as Map?) ?? const {};
                    final signature = receipt['transactionSignature'] as String?;
                    final recordId = record['id'] as String? ?? '';
                    final shareUrl = Uri.https('gen-lang-client-0915748775.web.app', '/', {'record': recordId});
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              CircleAvatar(radius: 16, child: Text('${sorted.length - index}')),
                              const SizedBox(width: 10),
                              Expanded(child: Text(manifest.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall)),
                              IconButton(
                                tooltip: 'Copy share link',
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: shareUrl.toString()));
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share link copied')));
                                },
                                icon: const Icon(Icons.link_rounded),
                              ),
                            ]),
                            Text('${manifest.createdAt.toLocal()} · ${_short(manifest.sha256)}', style: Theme.of(context).textTheme.bodySmall),
                            if (signature != null) ...[
                              const SizedBox(height: 6),
                              SelectableText('Solana devnet · $signature', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onNewVersion(_manifest(sorted.first));
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Register new version'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.name, required this.count, required this.selected, required this.onTap});
  final String name;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 158,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(children: [
          Icon(Icons.folder_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge)),
          if (count != null) Text('$count', style: theme.textTheme.labelSmall),
        ]),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.records, required this.onOpen, required this.onNewVersion, required this.onMove});
  final List<Map<String, dynamic>> records;
  final VoidCallback onOpen;
  final VoidCallback onNewVersion;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manifest = _manifest(records.first);
    final icon = _fileIcon(manifest.fileName);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 112,
              color: theme.colorScheme.primaryContainer.withValues(alpha: .55),
              child: Stack(
                children: [
                  Center(child: Icon(icon, size: 44, color: theme.colorScheme.primary)),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      tooltip: 'File actions',
                      onSelected: (value) => value == 'version' ? onNewVersion() : onMove(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'version', child: Text('New version')),
                        PopupMenuItem(value: 'folder', child: Text('Move to folder')),
                      ],
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ),
                  if (records.length > 1)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Chip(label: Text('${records.length} versions'), visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(manifest.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('${_formatBytes(manifest.fileSize)} · ${_short(manifest.sha256)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.detail, required this.action, required this.onPressed});
  final IconData icon;
  final String title;
  final String detail;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(detail, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: onPressed, child: Text(action)),
      ]),
    ),
  );
}

OriginManifest _manifest(Map<String, dynamic> record) =>
    OriginManifest.fromJson(Map<String, dynamic>.from(manifestData(record)));
Map manifestData(Map<String, dynamic> record) => record['manifest'] as Map;
DateTime _createdAt(Map<String, dynamic> record) => _manifest(record).createdAt;
String _short(String value) => '${value.substring(0, 14)}…';
String _formatBytes(int value) => value < 1024 * 1024
    ? '${(value / 1024).toStringAsFixed(0)} KB'
    : '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';

bool _matchesCategory(String fileName, String category) {
  if (category == 'All') return true;
  final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  final photos = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'avif'};
  final videos = {'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'};
  final audio = {'mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'};
  return switch (category) {
    'Photos' => photos.contains(extension),
    'Videos' => videos.contains(extension),
    'Audio' => audio.contains(extension),
    'Documents' => !photos.contains(extension) && !videos.contains(extension) && !audio.contains(extension),
    _ => true,
  };
}

IconData _categoryIcon(String category) => switch (category) {
  'Photos' => Icons.image_rounded,
  'Videos' => Icons.movie_rounded,
  'Audio' => Icons.audio_file_rounded,
  _ => Icons.description_rounded,
};

IconData _fileIcon(String fileName) {
  final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'avif'}.contains(extension)) return Icons.image_rounded;
  if ({'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'}.contains(extension)) return Icons.movie_rounded;
  if ({'mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'}.contains(extension)) return Icons.audio_file_rounded;
  return Icons.description_rounded;
}
