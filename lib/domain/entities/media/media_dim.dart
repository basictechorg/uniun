import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_dim.freezed.dart';

@freezed
abstract class MediaDim with _$MediaDim {
  const factory MediaDim({
    required int width,
    required int height,
  }) = _MediaDim;
}
