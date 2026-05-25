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
  });

  final bool isLoading;
  final bool isDeleting;
  final bool isDeletingChatHistory;
  final int dbSizeBytes;
  final int modelSizeBytes;
  final int chatHistorySizeBytes;
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

  int get totalBytes =>
      dbSizeBytes + modelSizeBytes + chatHistorySizeBytes + otherSizeBytes;

  StorageState copyWith({
    bool? isLoading,
    bool? isDeleting,
    bool? isDeletingChatHistory,
    int? dbSizeBytes,
    int? modelSizeBytes,
    int? chatHistorySizeBytes,
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
  }) {
    return StorageState(
      isLoading: isLoading ?? this.isLoading,
      isDeleting: isDeleting ?? this.isDeleting,
      isDeletingChatHistory:
          isDeletingChatHistory ?? this.isDeletingChatHistory,
      dbSizeBytes: dbSizeBytes ?? this.dbSizeBytes,
      modelSizeBytes: modelSizeBytes ?? this.modelSizeBytes,
      chatHistorySizeBytes: chatHistorySizeBytes ?? this.chatHistorySizeBytes,
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
    );
  }
}
