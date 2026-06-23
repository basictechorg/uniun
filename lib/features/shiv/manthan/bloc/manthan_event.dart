part of 'manthan_bloc.dart';

enum ManthanDirection { up, right, left, down }

@freezed
abstract class ManthanEvent with _$ManthanEvent {
  const factory ManthanEvent.loadDeck(List<String> manasIds) = _LoadDeck;
  const factory ManthanEvent.changeScope(List<String> manasIds) = _ChangeScope;
  const factory ManthanEvent.swipeCard(ManthanDirection direction) = _SwipeCard;
  const factory ManthanEvent.toggleReference(String noteId) = _ToggleReference;
  const factory ManthanEvent.loadMore() = _LoadMore;
}
