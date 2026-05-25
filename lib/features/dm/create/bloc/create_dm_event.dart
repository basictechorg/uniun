part of 'create_dm_bloc.dart';

@immutable
sealed class CreateDmEvent {}

final class LoadRelaysEvent extends CreateDmEvent {}

final class SubmitDmEvent extends CreateDmEvent {
  final String otherPubkey;
  final List<String> selectedRelays;

  SubmitDmEvent({
    required this.otherPubkey,
    required this.selectedRelays,
  });
}
