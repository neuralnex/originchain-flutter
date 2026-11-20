class FingerprintEntry {
  const FingerprintEntry({
    required this.sha256,
    required this.fileName,
    required this.sizeBytes,
    required this.createdAtUtc,
  });

  final String sha256;
  final String fileName;
  final int sizeBytes;
  final DateTime createdAtUtc;

  Map<String, Object?> toMap() => {
    'sha256': sha256,
    'file_name': fileName,
    'size_bytes': sizeBytes,
    'created_at_utc': createdAtUtc.toUtc().toIso8601String(),
  };

  factory FingerprintEntry.fromMap(Map<String, Object?> map) {
    return FingerprintEntry(
      sha256: map['sha256']! as String,
      fileName: map['file_name']! as String,
      sizeBytes: map['size_bytes']! as int,
      createdAtUtc: DateTime.parse(map['created_at_utc']! as String).toUtc(),
    );
  }
}
