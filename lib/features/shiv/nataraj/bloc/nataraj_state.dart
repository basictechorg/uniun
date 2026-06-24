part of 'nataraj_bloc.dart';

enum NatarajStatus { loading, ready, needsMoreNotes, exhausted, error }

@freezed
abstract class NatarajState with _$NatarajState {
  const factory NatarajState({
    @Default(NatarajStatus.loading) NatarajStatus status,
    @Default(<String>[]) List<String> manasIds,
    @Default('') String scopeName,
    @Default(<ManasEntity>[]) List<ManasEntity> manasOptions,
    NatarajCardEntity? currentCard,
    NatarajCardEntity? nextCard,
    @Default(<String>{}) Set<String> excludedRefIds,
    @Default(false) bool resurfacing,
    @Default(true) bool showCoach,
    // One-shot signal: when non-null, the page should open Shiv chat seeded
    // with this paragraph then clear it (via NatarajEvent or a listener).
    String? seedChatParagraph,
  }) = _NatarajState;
}
