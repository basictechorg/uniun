import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/usecases/usecase.dart';
import 'package:uniun/domain/entities/onboarding/onboarding_interest_entity.dart';
import 'package:uniun/domain/repositories/uniun_repository.dart';

/// The onboarding interest-picker roster, straight from the gateway — see
/// `docs/frontend/ONBOARDING-INTERESTS.md`. Public endpoint, no local
/// identity required.
@lazySingleton
class GetOnboardingInterestsUseCase
    extends NoParamsUseCase<Either<Failure, List<OnboardingInterestEntity>>> {
  final UniunRepository _repo;
  const GetOnboardingInterestsUseCase(this._repo);

  @override
  Future<Either<Failure, List<OnboardingInterestEntity>>> call() =>
      _repo.getOnboardingInterests();
}
