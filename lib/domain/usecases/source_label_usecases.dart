import 'package:injectable/injectable.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/repositories/source_label_repository.dart';

/// Input type alias for [ResolveSourceLabelsUseCase].
typedef SourceLabelItem = ({String eventId, String? channelId, String? groupId});

@lazySingleton
class ResolveSourceLabelsUseCase
    extends UseCase<Map<String, String>, List<SourceLabelItem>> {
  final SourceLabelRepository _repository;
  const ResolveSourceLabelsUseCase(this._repository);

  @override
  Future<Map<String, String>> call(
    List<SourceLabelItem> input, {
    bool cached = false,
  }) =>
      _repository.resolveMany(input);
}
