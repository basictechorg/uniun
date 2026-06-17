part of 'manas_list_bloc.dart';

sealed class ManasListEvent {
  const ManasListEvent();
}

final class ManasListLoadEvent extends ManasListEvent {
  const ManasListLoadEvent();
}

final class ManasListDeleteEvent extends ManasListEvent {
  const ManasListDeleteEvent(this.manasId);
  final String manasId;
}
