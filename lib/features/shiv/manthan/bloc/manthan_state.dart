part of 'manthan_bloc.dart';

enum ManthanStatus { loading, ready, needsMoreNotes, exhausted, error }

@freezed
abstract class ManthanState with _$ManthanState {
  const factory ManthanState({
    @Default(ManthanStatus.loading) ManthanStatus status,
    @Default(<String>[]) List<String> manasIds,
    @Default('') String scopeName,
    @Default(<ManasEntity>[]) List<ManasEntity> manasOptions,
    ManthanCardEntity? currentCard,
    ManthanCardEntity? nextCard,
    @Default(<String>{}) Set<String> excludedRefIds,
    @Default(false) bool resurfacing,
    @Default(true) bool showCoach,
    // One-shot signal: when non-null, the page should open Shiv chat seeded
    // with this paragraph then clear it (via ManthanEvent or a listener).
    String? seedChatParagraph,
  }) = _ManthanState;
}
