part of 'drawer_bloc.dart';

@immutable
sealed class DrawerEvent {}

/// Load user profile + groups + DMs on drawer open.
final class DrawerLoadEvent extends DrawerEvent {}
