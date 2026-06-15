import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_filter.freezed.dart';

enum MediaKindFilter { all, image, video, audio, file }

@freezed
abstract class MediaFilter with _$MediaFilter {
  const factory MediaFilter({
    @Default(MediaKindFilter.all) MediaKindFilter kind,
  }) = _MediaFilter;
}
