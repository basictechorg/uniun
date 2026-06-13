class StorageStats {
  const StorageStats({
    required this.dbSizeBytes,
    required this.modelSizeBytes,
    required this.chatHistorySizeBytes,
    required this.mediaSizeBytes,
    required this.otherSizeBytes,
    required this.totalNoteCount,
    required this.deletableFeedNoteCount,
    required this.conversationCount,
    required this.freeDiskBytes,
  });

  final int dbSizeBytes;
  final int modelSizeBytes;
  final int chatHistorySizeBytes;

  /// Bytes under `getApplicationSupportDirectory()/media/` — the
  /// content-addressed blob cache. Tracked separately from
  /// [otherSizeBytes] so the chart attributes media to its own bucket.
  final int mediaSizeBytes;

  final int otherSizeBytes;
  final int totalNoteCount;
  final int deletableFeedNoteCount;
  final int conversationCount;
  final int freeDiskBytes;

  int get totalBytes =>
      dbSizeBytes +
      modelSizeBytes +
      chatHistorySizeBytes +
      mediaSizeBytes +
      otherSizeBytes;
}
