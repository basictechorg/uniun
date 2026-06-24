import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';

/// Brahma-specific wrapper around [showMediaPickSheet]. Picks the file via
/// the shared sheet, then dispatches [AttachMediaEvent] on the parent
/// [BrahmaCreateBloc]. The pick is held locally and uploaded to Blossom only
/// when the note is submitted. Kept separate because Brahma has draft + graph
/// state; other surfaces attach via [ComposerHost] directly.
Future<void> showComposeMediaSheet(BuildContext context) async {
  final bloc = context.read<BrahmaCreateBloc>();
  final picked = await showMediaPickSheet(context);
  if (picked == null) return;
  bloc.add(AttachMediaEvent(picked));
}
