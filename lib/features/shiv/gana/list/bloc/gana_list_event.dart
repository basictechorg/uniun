part of 'gana_list_bloc.dart';

sealed class GanaListEvent {
  const GanaListEvent();
}

class GanaListLoadEvent extends GanaListEvent {
  const GanaListLoadEvent();
}

class GanaListToggleEnabledEvent extends GanaListEvent {
  const GanaListToggleEnabledEvent(this.ganaId, this.enabled);
  final String ganaId;
  final bool enabled;
}

class GanaListDeleteEvent extends GanaListEvent {
  const GanaListDeleteEvent(this.ganaId);
  final String ganaId;
}

class _GanaListWatcherTickEvent extends GanaListEvent {
  const _GanaListWatcherTickEvent();
}
