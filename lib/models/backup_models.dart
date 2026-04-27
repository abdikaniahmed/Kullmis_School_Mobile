class BackupDownloadResult {
  const BackupDownloadResult({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final List<int> bytes;
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.message,
    required this.summary,
  });

  final String message;
  final Map<String, dynamic> summary;

  factory BackupRestoreResult.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];

    return BackupRestoreResult(
      message: '${json['message'] ?? 'Backup restored successfully.'}'.trim(),
      summary: summary is Map<String, dynamic> ? summary : const {},
    );
  }
}
