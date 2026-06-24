part of 'nataraj_bloc.dart';

enum NatarajDirection { up, right, left, down }

@freezed
abstract class NatarajEvent with _$NatarajEvent {
  const factory NatarajEvent.loadDeck(List<String> manasIds) = _LoadDeck;
  const factory NatarajEvent.changeScope(List<String> manasIds) = _ChangeScope;
  const factory NatarajEvent.swipeCard(NatarajDirection direction) = _SwipeCard;
  const factory NatarajEvent.toggleReference(String noteId) = _ToggleReference;
  const factory NatarajEvent.loadMore() = _LoadMore;
}
