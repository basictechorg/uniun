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

  /// Bytes occupied by the content-addressed media cache (everything under
  /// `getApplicationSupportDirectory()/media/`). Tracked separately from
  /// [otherSizeBytes] so the storage chart can show users what their photo /
  /// video / file downloads cost — bundling these into "Other" hid the
  /// biggest growing bucket.
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
