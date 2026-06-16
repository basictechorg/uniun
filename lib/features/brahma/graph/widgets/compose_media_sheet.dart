import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/widgets/composer/media_pick_helper.dart';
import 'package:uniun/features/brahma/bloc/brahma_create_bloc.dart';

/// Brahma-specific wrapper around [showMediaPickSheet]. Picks the file via
/// the shared sheet, then dispatches [UploadAndAttachMediaEvent] on the
/// parent [BrahmaCreateBloc]. Kept separate because Brahma has draft + graph
/// state that ties media to a specific draft id; other surfaces upload via
/// [ComposerHost] directly.
Future<void> showComposeMediaSheet(BuildContext context) async {
  final bloc = context.read<BrahmaCreateBloc>();
  final picked = await showMediaPickSheet(context);
  if (picked == null) return;
  bloc.add(UploadAndAttachMediaEvent(
    bytes: picked.bytes,
    mime: picked.mime,
    filename: picked.filename,
    width: picked.width,
    height: picked.height,
  ));
}
