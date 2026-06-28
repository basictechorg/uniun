part of 'storage_cubit.dart';

@immutable
class StorageState {
  const StorageState({
    this.isLoading = true,
    this.isDeleting = false,
    this.isDeletingChatHistory = false,
    this.dbSizeBytes = 0,
    this.modelSizeBytes = 0,
    this.chatHistorySizeBytes = 0,
    this.mediaSizeBytes = 0,
    this.otherSizeBytes = 0,
    this.freeDiskBytes = 0,
    this.totalNoteCount = 0,
    this.deletableFeedNoteCount = 0,
    this.conversationCount = 0,
    this.ownPubkey,
    this.error,
    this.deleteError,
    this.deleteSuccess = false,
    this.deletedCount = 0,
    this.deleteChatHistorySuccess = false,
    this.autoDeleteOldNotesDays,
    this.recentSyncWindowDays = 7,
  });

  final bool isLoading;
  final bool isDeleting;
  final bool isDeletingChatHistory;
  final int dbSizeBytes;
  final int modelSizeBytes;
  final int chatHistorySizeBytes;
  final int mediaSizeBytes;
  final int otherSizeBytes;
  final int freeDiskBytes;
  final int totalNoteCount;
  final int deletableFeedNoteCount;
  final int conversationCount;
  final String? ownPubkey;
  final String? error;
  final String? deleteError;
  final bool deleteSuccess;
  final int deletedCount;
  final bool deleteChatHistorySuccess;

  /// `null` = auto-cleanup off (default). Otherwise the configured
  /// retention window applied to short-lived public traffic. Saved /
  /// followed / own / DM / private-group notes are never affected.
  final int? autoDeleteOldNotesDays;

  /// Days of history the capped sync surfaces pull. Default 7. Takes effect on
  /// next app launch (read by the Gateway isolate at boot).
  final int recentSyncWindowDays;

  int get totalBytes =>
      dbSizeBytes +
      modelSizeBytes +
      chatHistorySizeBytes +
      mediaSizeBytes +
      otherSizeBytes;

  StorageState copyWith({
    bool? isLoading,
    bool? isDeleting,
    bool? isDeletingChatHistory,
    int? dbSizeBytes,
    int? modelSizeBytes,
    int? chatHistorySizeBytes,
    int? mediaSizeBytes,
    int? otherSizeBytes,
    int? freeDiskBytes,
    int? totalNoteCount,
    int? deletableFeedNoteCount,
    int? conversationCount,
    String? ownPubkey,
    String? error,
    String? deleteError,
    bool? deleteSuccess,
    int? deletedCount,
    bool? deleteChatHistorySuccess,
    Object? autoDeleteOldNotesDays = _sentinel,
    int? recentSyncWindowDays,
  }) {
    return StorageState(
      isLoading: isLoading ?? this.isLoading,
      isDeleting: isDeleting ?? this.isDeleting,
      isDeletingChatHistory:
          isDeletingChatHistory ?? this.isDeletingChatHistory,
      dbSizeBytes: dbSizeBytes ?? this.dbSizeBytes,
      modelSizeBytes: modelSizeBytes ?? this.modelSizeBytes,
      chatHistorySizeBytes: chatHistorySizeBytes ?? this.chatHistorySizeBytes,
      mediaSizeBytes: mediaSizeBytes ?? this.mediaSizeBytes,
      otherSizeBytes: otherSizeBytes ?? this.otherSizeBytes,
      freeDiskBytes: freeDiskBytes ?? this.freeDiskBytes,
      totalNoteCount: totalNoteCount ?? this.totalNoteCount,
      deletableFeedNoteCount:
          deletableFeedNoteCount ?? this.deletableFeedNoteCount,
      conversationCount: conversationCount ?? this.conversationCount,
      ownPubkey: ownPubkey ?? this.ownPubkey,
      error: error,
      deleteError: deleteError,
      deleteSuccess: deleteSuccess ?? this.deleteSuccess,
      deletedCount: deletedCount ?? this.deletedCount,
      deleteChatHistorySuccess:
          deleteChatHistorySuccess ?? this.deleteChatHistorySuccess,
      autoDeleteOldNotesDays: identical(autoDeleteOldNotesDays, _sentinel)
          ? this.autoDeleteOldNotesDays
          : autoDeleteOldNotesDays as int?,
      recentSyncWindowDays: recentSyncWindowDays ?? this.recentSyncWindowDays,
    );
  }
}

const Object _sentinel = Object();
