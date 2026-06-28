part of 'create_group_bloc.dart';

@immutable
sealed class CreateGroupEvent {}

final class LoadRelaysEvent extends CreateGroupEvent {}

final class SubmitGroupEvent extends CreateGroupEvent {
  final String name;
  final String about;
  final String picture;
  final List<String> selectedRelays;

  SubmitGroupEvent({
    required this.name,
    required this.about,
    required this.picture,
    required this.selectedRelays,
  });
}
