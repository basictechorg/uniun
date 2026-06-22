import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/domain/usecases/app_settings_usecases.dart';
import 'package:uniun/domain/usecases/storage_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';

part 'storage_state.dart';

@injectable
class StorageCubit extends Cubit<StorageState> {
  final GetStorageStatsUseCase _getStats;
  final DeleteFeedNotesUseCase _deleteNotes;
  final DeleteAllChatHistoryUseCase _deleteChatHistory;
  final GetActiveUserUseCase _getUser;
  final GetAutoDeleteOldNotesDaysUseCase _getAutoDelete;
  final SetAutoDeleteOldNotesDaysUseCase _setAutoDelete;
  final GetRecentSyncWindowDaysUseCase _getRecentSync;
  final SetRecentSyncWindowDaysUseCase _setRecentSync;

  StorageCubit(
    this._getStats,
    this._deleteNotes,
    this._deleteChatHistory,
    this._getUser,
    this._getAutoDelete,
    this._setAutoDelete,
    this._getRecentSync,
    this._setRecentSync,
  ) : super(const StorageState()) {
    // Defer until after the current frame so the Settings page open animation
    // is not competing with the filesystem scan on the main thread.
    SchedulerBinding.instance.addPostFrameCallback((_) => loadStats());
  }

  Future<void> loadStats() async {
    emit(state.copyWith(isLoading: true, error: null));
    final userResult = await _getUser.call();
    final pubkey = userResult.fold((_) => null, (u) => u.pubkeyHex);
    if (pubkey == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }
    final result = await _getStats.call(pubkey);
    final autoDelete =
        (await _getAutoDelete.call()).fold((_) => null, (v) => v);
    final recentSync =
        (await _getRecentSync.call()).fold((_) => 7, (v) => v);
    result.fold(
      (f) => emit(state.copyWith(isLoading: false, error: f.toString())),
      (stats) => emit(state.copyWith(
        isLoading: false,
        dbSizeBytes: stats.dbSizeBytes,
        modelSizeBytes: stats.modelSizeBytes,
        chatHistorySizeBytes: stats.chatHistorySizeBytes,
        mediaSizeBytes: stats.mediaSizeBytes,
        otherSizeBytes: stats.otherSizeBytes,
        freeDiskBytes: stats.freeDiskBytes,
        totalNoteCount: stats.totalNoteCount,
        deletableFeedNoteCount: stats.deletableFeedNoteCount,
        conversationCount: stats.conversationCount,
        ownPubkey: pubkey,
        autoDeleteOldNotesDays: autoDelete,
        recentSyncWindowDays: recentSync,
      )),
    );
  }

  /// Persist the user's retention choice. `null` = off. Takes effect on
  /// next app launch (CleanupManager reads it at Gateway boot time and
  /// SharedPreferences is unavailable in the Gateway isolate).
  Future<void> setAutoDeleteOldNotesDays(int? days) async {
    await _setAutoDelete.call(days);
    emit(state.copyWith(autoDeleteOldNotesDays: days));
  }

  /// Persist the user's sync-window choice (days of history the capped sync
  /// surfaces pull). Takes effect on next app launch — the Gateway isolate
  /// reads it at boot and SharedPreferences is unavailable in that isolate.
  Future<void> setRecentSyncWindowDays(int days) async {
    await _setRecentSync.call(days);
    emit(state.copyWith(recentSyncWindowDays: days));
  }

  Future<void> deleteFeedNotes() async {
    if (state.ownPubkey == null) return;
    emit(state.copyWith(isDeleting: true, deleteError: null, deleteSuccess: false));
    final result = await _deleteNotes.call(state.ownPubkey!);
    result.fold(
      (f) => emit(state.copyWith(isDeleting: false, deleteError: f.toString())),
      (count) {
        emit(state.copyWith(
          isDeleting: false,
          deleteSuccess: true,
          deletedCount: count,
        ));
        loadStats();
      },
    );
  }

  Future<void> deleteChatHistory() async {
    emit(state.copyWith(
        isDeletingChatHistory: true,
        deleteError: null,
        deleteChatHistorySuccess: false));
    final result = await _deleteChatHistory.call();
    result.fold(
      (f) => emit(
          state.copyWith(isDeletingChatHistory: false, deleteError: f.toString())),
      (_) {
        emit(state.copyWith(
          isDeletingChatHistory: false,
          deleteChatHistorySuccess: true,
        ));
        loadStats();
      },
    );
  }
}
